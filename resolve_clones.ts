import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import process from "node:process";

import { Command, InvalidArgumentError } from "commander";
import OpenAI from "openai";

import {
  applyConflictResolution,
  getConflictFileInputs,
  listCloneEntries,
  listUnmergedFiles,
  type CloneEntry,
  type ConflictFileInput,
  type ConflictResolution,
} from "./clone_tools.js";

const DEFAULT_RESOLUTION_MODEL = "gpt-5.4";
const DEFAULT_RESOLUTION_MAX_OUTPUT_TOKENS = 12_000;
const DEFAULT_FILE_RESOLUTION_CONCURRENCY = 2;
const DEFAULT_RECOVER_RESOLUTION_CONCURRENCY = 1;
const DEFAULT_CONFLICT_GROUP_MAX_FILES = 2;
const DEFAULT_CONFLICT_GROUP_MAX_INPUT_CHARS = 48_000;
const MAX_CONFLICT_RESOLUTION_ATTEMPTS = 2;
const MAX_COMMAND_OUTPUT_BYTES = 64 * 1024 * 1024;
const RESOLVE_STATE_VERSION = 1;
const CONFLICT_MARKER_PATTERN = /^(<{7}|={7}|>{7})(?: |$)/m;

type ResolveMode = "conflicts" | "recover" | "auto";
type ResolveStatus = "completed" | "skipped" | "failed";
type PersistedResolveStatus = ResolveStatus | "in_progress";
type OpenAIClientGetter = () => OpenAI;
type ActionRecorder = (action: string) => void;

interface CliOptions {
  prefix: string;
  clone: string[];
  mode: ResolveMode;
  openaiApiKey?: string;
  openaiModel: string;
  resolutionConcurrency?: number;
  fileResolutionConcurrency?: number;
  resolutionMaxOutputTokens: number;
  dryRun: boolean;
  continueOnError: boolean;
  resetState: boolean;
  snapshotDirtyWork: boolean;
  stateFile?: string;
}

interface CommandResult {
  stdout: string;
  stderr: string;
  status: number;
}

interface ResolveResult {
  cloneName: string;
  status: ResolveStatus;
  actions: string[];
  error?: string;
}

interface ResolveRunSummary {
  results: ResolveResult[];
  failed: boolean;
}

interface ResolvedConflictFile {
  conflict: ConflictFileInput;
  resolution: ConflictResolution;
}

interface DirtyWorkRefreshResult {
  actions: string[];
  stashMarker?: string;
}

interface CloneStateSnapshot {
  headSha: string;
  statusOutput: string;
}

interface PersistedCloneState extends CloneStateSnapshot {
  status: PersistedResolveStatus;
  actions: string[];
  startedAt?: string;
  finishedAt?: string;
  error?: string;
}

interface PersistedResolveState {
  version: number;
  prefix: string;
  mode: ResolveMode;
  createdAt: string;
  updatedAt: string;
  options: {
    openaiModel: string;
    resolutionMaxOutputTokens: number;
    resolutionConcurrency: number;
    fileResolutionConcurrency: number;
    continueOnError: boolean;
    snapshotDirtyWork: boolean;
    dryRun: boolean;
    selectedClones: string[];
  };
  clones: Record<string, PersistedCloneState>;
}

interface CheckoutRestoreTarget {
  label: string;
  switchArgs: string[];
}

class ResolutionResponseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ResolutionResponseError";
  }
}

class ResolveStateTracker {
  readonly filePath: string;
  private state: PersistedResolveState;

  private constructor(filePath: string, state: PersistedResolveState) {
    this.filePath = filePath;
    this.state = state;
  }

  static load(
    filePath: string,
    options: CliOptions,
    resolutionConcurrency: number,
    fileResolutionConcurrency: number,
  ): ResolveStateTracker {
    const normalizedPath = path.resolve(filePath);
    const metadata = {
      openaiModel: options.openaiModel,
      resolutionMaxOutputTokens: options.resolutionMaxOutputTokens,
      resolutionConcurrency,
      fileResolutionConcurrency,
      continueOnError: options.continueOnError,
      snapshotDirtyWork: options.snapshotDirtyWork,
      dryRun: options.dryRun,
      selectedClones: [...(options.clone ?? [])],
    };

    let state: PersistedResolveState;
    if (!options.resetState && fs.existsSync(normalizedPath)) {
      const raw = fs.readFileSync(normalizedPath, "utf8");
      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        throw new Error(`Failed to parse state file ${normalizedPath}: ${message}`);
      }

      if (
        typeof parsed !== "object" ||
        parsed == null ||
        (parsed as PersistedResolveState).prefix !== options.prefix ||
        (parsed as PersistedResolveState).mode !== options.mode
      ) {
        throw new Error(
          `State file ${normalizedPath} does not match prefix=${options.prefix} mode=${options.mode}; use --reset-state to start fresh.`,
        );
      }

      state = parsed as PersistedResolveState;
      state.version = RESOLVE_STATE_VERSION;
      state.options = metadata;
      let updated = false;
      for (const cloneState of Object.values(state.clones)) {
        if (cloneState.status !== "in_progress") {
          continue;
        }
        cloneState.status = "failed";
        cloneState.error = cloneState.error ?? "previous run interrupted before completion";
        cloneState.finishedAt = nowIso();
        updated = true;
      }
      state.updatedAt = nowIso();

      const tracker = new ResolveStateTracker(normalizedPath, state);
      if (updated) {
        tracker.save();
      } else {
        tracker.save();
      }
      return tracker;
    }

    const timestamp = nowIso();
    state = {
      version: RESOLVE_STATE_VERSION,
      prefix: options.prefix,
      mode: options.mode,
      createdAt: timestamp,
      updatedAt: timestamp,
      options: metadata,
      clones: {},
    };

    const tracker = new ResolveStateTracker(normalizedPath, state);
    tracker.save();
    return tracker;
  }

  resumeResultForClone(clone: CloneEntry): ResolveResult | undefined {
    const cloneState = this.state.clones[clone.name];
    if (cloneState?.status !== "completed") {
      return undefined;
    }

    const currentSnapshot = captureCloneStateSnapshot(clone);
    if (
      cloneState.headSha !== currentSnapshot.headSha ||
      cloneState.statusOutput !== currentSnapshot.statusOutput
    ) {
      return undefined;
    }

    return {
      cloneName: clone.name,
      status: "skipped",
      actions: [`skipped: already completed in ${this.filePath}`],
    };
  }

  markInProgress(clone: CloneEntry): void {
    this.state.clones[clone.name] = {
      status: "in_progress",
      actions: [],
      startedAt: nowIso(),
      headSha: getHeadSha(clone.clonePath),
      statusOutput: clone.statusOutput,
    };
    this.state.updatedAt = nowIso();
    this.save();
  }

  appendAction(cloneName: string, action: string): void {
    const cloneState = this.state.clones[cloneName];
    if (!cloneState) {
      return;
    }

    cloneState.actions.push(action);
    this.state.updatedAt = nowIso();
    this.save();
  }

  finalize(clone: CloneEntry, result: ResolveResult): void {
    const existing = this.state.clones[clone.name];
    this.state.clones[clone.name] = {
      status: result.status,
      actions: [...result.actions],
      startedAt: existing?.startedAt ?? nowIso(),
      finishedAt: nowIso(),
      error: result.error,
      ...captureCloneStateSnapshot(clone),
    };
    this.state.updatedAt = nowIso();
    this.save();
  }

  hasFailures(): boolean {
    return Object.values(this.state.clones).some(
      (cloneState) => cloneState.status === "failed" || cloneState.status === "in_progress",
    );
  }

  removeFile(): void {
    if (!fs.existsSync(this.filePath)) {
      return;
    }
    fs.rmSync(this.filePath, { force: true });
  }

  private save(): void {
    fs.mkdirSync(path.dirname(this.filePath), { recursive: true });
    fs.writeFileSync(this.filePath, `${JSON.stringify(this.state, null, 2)}\n`, "utf8");
  }
}

function parsePositiveInt(value: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new InvalidArgumentError(`Expected a positive integer, got ${value}`);
  }
  return parsed;
}

function collectString(value: string, previous: string[]): string[] {
  return [...previous, value];
}

function formatUsageError(command: string, status: number, stderr: string): Error {
  const trimmedStderr = stderr.trim();
  if (trimmedStderr) {
    return new Error(`${command} exited with status ${status}: ${trimmedStderr}`);
  }
  return new Error(`${command} exited with status ${status}`);
}

function nowIso(): string {
  return new Date().toISOString();
}

function currentDateStamp(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, "");
}

function isCommandNotFound(error: unknown): error is NodeJS.ErrnoException {
  return (
    typeof error === "object" &&
    error != null &&
    "code" in error &&
    (error as NodeJS.ErrnoException).code === "ENOENT"
  );
}

function runCommand(
  command: string,
  clonePath: string,
  args: string[],
  allowedStatuses: number[] = [0],
  timeoutMs?: number,
): CommandResult {
  const result = spawnSync(command, args, {
    cwd: clonePath,
    encoding: "utf8",
    maxBuffer: MAX_COMMAND_OUTPUT_BYTES,
    timeout: timeoutMs,
  });

  if (result.error) {
    throw result.error;
  }

  const status = result.status ?? 1;
  const stdout = result.stdout ?? "";
  const stderr = result.stderr ?? "";
  if (!allowedStatuses.includes(status)) {
    throw formatUsageError(`${command} ${args.join(" ")}`, status, stderr);
  }

  return { stdout, stderr, status };
}

function runGit(
  clonePath: string,
  args: string[],
  allowedStatuses: number[] = [0],
  timeoutMs?: number,
): CommandResult {
  return runCommand("git", clonePath, args, allowedStatuses, timeoutMs);
}

function runPnpm(
  clonePath: string,
  args: string[],
  allowedStatuses: number[] = [0],
): CommandResult {
  return runCommand("pnpm", clonePath, args, allowedStatuses);
}

function runMise(
  clonePath: string,
  args: string[],
  allowedStatuses: number[] = [0],
): CommandResult {
  return runCommand("mise", clonePath, args, allowedStatuses);
}

function extractResponseText(response: unknown): string {
  const direct = (response as { output_text?: string }).output_text;
  if (typeof direct === "string" && direct.trim()) {
    return direct.trim();
  }

  const chunks: string[] = [];
  const output = (response as { output?: Array<{ content?: Array<{ text?: string }> }> }).output;
  if (!Array.isArray(output)) {
    return "";
  }

  for (const item of output) {
    if (!Array.isArray(item.content)) {
      continue;
    }
    for (const block of item.content) {
      if (typeof block.text === "string" && block.text.trim()) {
        chunks.push(block.text.trim());
      }
    }
  }

  return chunks.join("\n").trim();
}

function formatConflictSection(label: string, text: string | undefined): string {
  if (text == null) {
    return `<${label}>\n[missing]\n</${label}>`;
  }
  return `<${label}>\n${text}\n</${label}>`;
}

function parseResolution(rawText: string): ConflictResolution {
  const actionMatch = /<action>\s*(write|delete)\s*<\/action>/is.exec(rawText);
  const contentMatch = /<content>\n?([\s\S]*?)\n?<\/content>/is.exec(rawText);

  const action =
    (actionMatch?.[1]?.trim().toLowerCase() as "write" | "delete" | undefined) ?? "write";
  if (action === "delete") {
    return { action: "delete" };
  }

  if (contentMatch) {
    return { action: "write", content: contentMatch[1] ?? "" };
  }

  const fencedMatch = /^```[a-zA-Z0-9_-]*\n([\s\S]*?)\n```$/m.exec(rawText);
  if (fencedMatch) {
    return { action: "write", content: fencedMatch[1] ?? "" };
  }

  return { action: "write", content: rawText.trimEnd() };
}

function parseExpectedResolution(rawText: string, contextLabel: string): ConflictResolution {
  const action = /<action>\s*(write|delete)\s*<\/action>/is
    .exec(rawText)?.[1]
    ?.trim()
    .toLowerCase();
  const hasContentTag = /<content>\n?[\s\S]*?\n?<\/content>/is.test(rawText);
  const hasFencedContent = /^```[a-zA-Z0-9_-]*\n[\s\S]*\n```$/m.test(rawText);

  if (action === "delete") {
    return parseResolution(rawText);
  }

  if (hasContentTag || hasFencedContent) {
    return parseResolution(rawText);
  }

  throw new ResolutionResponseError(
    `OpenAI returned an unstructured write response for ${contextLabel}`,
  );
}

function getGitDir(clonePath: string): string {
  return path.join(clonePath, runGit(clonePath, ["rev-parse", "--git-dir"]).stdout.trim());
}

function hasInProgressOperation(clonePath: string): boolean {
  const gitDir = getGitDir(clonePath);
  return [
    "rebase-merge",
    "rebase-apply",
    "MERGE_HEAD",
    "CHERRY_PICK_HEAD",
    "REVERT_HEAD",
    "BISECT_LOG",
  ].some((entry) => fs.existsSync(path.join(gitDir, entry)));
}

function getCurrentBranch(clonePath: string): string {
  return runGit(clonePath, ["branch", "--show-current"]).stdout.trim();
}

function getHeadSha(clonePath: string): string {
  return runGit(clonePath, ["rev-parse", "HEAD"]).stdout.trim();
}

function getRepoStatus(clonePath: string): string {
  return runGit(clonePath, ["status", "--porcelain", "--untracked-files=normal"]).stdout.trimEnd();
}

function chooseRemote(clonePath: string): string {
  const originCheck = runGit(clonePath, ["ls-remote", "--exit-code", "origin"], [0, 2, 128], 5000);
  if (originCheck.status === 0) {
    return "origin";
  }

  const upstreamCheck = runGit(clonePath, ["remote", "get-url", "upstream"], [0, 2]);
  if (upstreamCheck.status === 0) {
    return "upstream";
  }

  throw new Error(`Unable to reach origin and no upstream remote is configured for ${clonePath}`);
}

function getDefaultBranch(clonePath: string, remote: string): string {
  const symbolic = runGit(
    clonePath,
    ["symbolic-ref", "--quiet", "--short", `refs/remotes/${remote}/HEAD`],
    [0, 1],
  ).stdout.trim();
  if (symbolic) {
    return symbolic.replace(new RegExp(`^${remote}/`), "");
  }

  const fallback = runGit(clonePath, ["remote", "show", remote]).stdout;
  const match = /HEAD branch:\s+([^\s]+)/.exec(fallback);
  if (match?.[1]) {
    return match[1];
  }

  throw new Error(`Unable to determine default branch for ${clonePath}`);
}

function createUniqueBranchName(clonePath: string, baseName: string): string {
  let candidate = baseName;
  let suffix = 2;
  while (runGit(clonePath, ["rev-parse", "--verify", candidate], [0, 128]).status === 0) {
    candidate = `${baseName}-${suffix}`;
    suffix += 1;
  }
  return candidate;
}

function maybeDropTopStash(clonePath: string, marker: string): boolean {
  const top = runGit(clonePath, ["stash", "list", "--format=%gs", "-n", "1"], [0]).stdout.trim();
  if (!top.includes(marker)) {
    return false;
  }
  runGit(clonePath, ["stash", "drop", "stash@{0}"]);
  return true;
}

function getCheckoutRestoreTarget(clonePath: string): CheckoutRestoreTarget {
  const branch = getCurrentBranch(clonePath);
  if (branch) {
    return {
      label: branch,
      switchArgs: ["switch", branch],
    };
  }

  const headSha = getHeadSha(clonePath);
  return {
    label: `detached@${headSha.slice(0, 12)}`,
    switchArgs: ["checkout", "--detach", headSha],
  };
}

function captureCloneStateSnapshot(clone: CloneEntry): CloneStateSnapshot {
  return {
    headSha: getHeadSha(clone.clonePath),
    statusOutput: clone.statusOutput,
  };
}

async function mapWithConcurrency<T, U>(
  items: T[],
  concurrency: number,
  worker: (item: T, index: number) => Promise<U>,
): Promise<U[]> {
  const results: U[] = [];
  let nextIndex = 0;

  const runner = async (): Promise<void> => {
    while (nextIndex < items.length) {
      const currentIndex = nextIndex;
      nextIndex += 1;
      results[currentIndex] = await worker(items[currentIndex]!, currentIndex);
    }
  };

  const workerCount = Math.max(1, Math.min(concurrency, items.length));
  await Promise.all(Array.from({ length: workerCount }, async () => runner()));
  return results;
}

function effectiveConcurrency(
  requested: number | undefined,
  itemCount: number,
  fallback: number,
): number {
  if (itemCount <= 0) {
    return 1;
  }

  const desired = requested ?? fallback;
  return Math.max(1, Math.min(desired, itemCount));
}

function createOpenAIClientGetter(options: CliOptions): OpenAIClientGetter {
  let client: OpenAI | undefined;

  return () => {
    if (client) {
      return client;
    }

    const apiKey = options.openaiApiKey || process.env.OPENAI_API_KEY || "";
    if (!apiKey) {
      throw new Error("OpenAI API key missing. Set OPENAI_API_KEY or pass --openai-api-key.");
    }

    client = new OpenAI({ apiKey });
    return client;
  };
}

function estimateConflictInputChars(conflict: ConflictFileInput): number {
  return (
    256 +
    conflict.relativePath.length +
    (conflict.baseText?.length ?? 0) +
    (conflict.oursText?.length ?? 0) +
    (conflict.theirsText?.length ?? 0) +
    (conflict.currentText?.length ?? 0)
  );
}

function normalizeConflictGroupStem(relativePath: string): string {
  const posixPath = relativePath.replaceAll("\\", "/");
  const dir = path.posix.dirname(posixPath);
  const basename = path.posix.basename(posixPath);
  const extension = path.posix.extname(basename);
  const stemWithSuffixes = extension ? basename.slice(0, -extension.length) : basename;
  const stem = stemWithSuffixes.replace(
    /\.(test|spec|stories|story|snap|bench|e2e|slow-test|stateful-e2e|ui-test)$/g,
    "",
  );
  return `${dir}/${stem}`;
}

function buildConflictResolutionGroups(conflicts: ConflictFileInput[]): ConflictFileInput[][] {
  const buckets = new Map<string, ConflictFileInput[]>();
  const sortedConflicts = [...conflicts].sort((left, right) =>
    left.relativePath.localeCompare(right.relativePath),
  );

  for (const conflict of sortedConflicts) {
    const key = normalizeConflictGroupStem(conflict.relativePath);
    const bucket = buckets.get(key);
    if (bucket) {
      bucket.push(conflict);
    } else {
      buckets.set(key, [conflict]);
    }
  }

  const groups: ConflictFileInput[][] = [];
  for (const key of [...buckets.keys()].sort((left, right) => left.localeCompare(right))) {
    const bucket = buckets.get(key)!;
    let currentGroup: ConflictFileInput[] = [];
    let currentGroupChars = 0;

    for (const conflict of bucket) {
      const conflictChars = estimateConflictInputChars(conflict);
      const wouldExceedMaxFiles = currentGroup.length >= DEFAULT_CONFLICT_GROUP_MAX_FILES;
      const wouldExceedMaxChars =
        currentGroup.length > 0 &&
        currentGroupChars + conflictChars > DEFAULT_CONFLICT_GROUP_MAX_INPUT_CHARS;
      if (wouldExceedMaxFiles || wouldExceedMaxChars) {
        groups.push(currentGroup);
        currentGroup = [];
        currentGroupChars = 0;
      }

      currentGroup.push(conflict);
      currentGroupChars += conflictChars;
    }

    if (currentGroup.length > 0) {
      groups.push(currentGroup);
    }
  }

  return groups;
}

function formatConflictPaths(paths: string[]): string {
  return paths.length > 0 ? paths.join("\n") : "(none)";
}

function formatConflictFileInput(conflict: ConflictFileInput): string {
  return [
    "<conflict_file>",
    `<path>${conflict.relativePath}</path>`,
    formatConflictSection("base", conflict.baseText),
    "",
    formatConflictSection("ours", conflict.oursText),
    "",
    formatConflictSection("theirs", conflict.theirsText),
    "",
    formatConflictSection("current_worktree", conflict.currentText),
    "</conflict_file>",
  ].join("\n");
}

function validateResolution(
  relativePath: string,
  resolution: ConflictResolution,
): ConflictResolution {
  if (resolution.action === "write" && CONFLICT_MARKER_PATTERN.test(resolution.content ?? "")) {
    throw new ResolutionResponseError(
      `OpenAI returned leftover conflict markers for ${relativePath}`,
    );
  }

  return resolution;
}

function parseGroupedResolutions(
  rawText: string,
  expectedPaths: string[],
): Map<string, ConflictResolution> {
  const fileBlocks = [...rawText.matchAll(/<file>\s*([\s\S]*?)\s*<\/file>/gi)];
  if (fileBlocks.length === 0) {
    throw new ResolutionResponseError("OpenAI returned no <file> blocks for grouped resolution.");
  }

  const expected = new Set(expectedPaths);
  const parsed = new Map<string, ConflictResolution>();

  for (const match of fileBlocks) {
    const block = match[1] ?? "";
    const pathMatch = /<path>\s*([\s\S]*?)\s*<\/path>/i.exec(block);
    const relativePath = pathMatch?.[1]?.trim();
    if (!relativePath) {
      throw new ResolutionResponseError("Grouped resolution omitted a <path>...</path> tag.");
    }
    if (!expected.has(relativePath)) {
      throw new ResolutionResponseError(
        `Grouped resolution returned an unexpected path: ${relativePath}`,
      );
    }
    if (parsed.has(relativePath)) {
      throw new ResolutionResponseError(
        `Grouped resolution returned the same path more than once: ${relativePath}`,
      );
    }

    parsed.set(
      relativePath,
      validateResolution(relativePath, parseExpectedResolution(block, relativePath)),
    );
  }

  const missingPaths = expectedPaths.filter((relativePath) => !parsed.has(relativePath));
  if (missingPaths.length > 0) {
    throw new ResolutionResponseError(
      `Grouped resolution omitted path(s): ${missingPaths.join(", ")}`,
    );
  }

  return parsed;
}

async function resolveConflictFile(
  getClient: OpenAIClientGetter,
  clone: CloneEntry,
  conflict: ConflictFileInput,
  allConflictPaths: string[],
  options: CliOptions,
): Promise<ResolvedConflictFile> {
  const statusBlock = getRepoStatus(clone.clonePath) || "(empty)";
  const prompt = [
    `Clone: ${clone.name}`,
    `Path: ${clone.clonePath}`,
    `File: ${conflict.relativePath}`,
    "",
    "Resolve this git conflict into a single final file.",
    "Use the base, ours, theirs, and current worktree contents when helpful.",
    "Preserve intent from both sides when compatible. Keep the file valid and production-ready.",
    "If the correct resolution is to delete the file, return <action>delete</action> and omit content.",
    "Otherwise return <action>write</action> and wrap the full resolved file contents in <content>...</content>.",
    "Return only XML-like tags, no explanation.",
    "",
    "<git_status>",
    statusBlock,
    "</git_status>",
    "",
    "<all_conflicted_files>",
    formatConflictPaths(allConflictPaths),
    "</all_conflicted_files>",
    "",
    formatConflictFileInput(conflict),
  ].join("\n");

  for (let attempt = 1; attempt <= MAX_CONFLICT_RESOLUTION_ATTEMPTS; attempt += 1) {
    const response = await getClient().responses.create({
      model: options.openaiModel,
      input: [
        {
          role: "system" as const,
          content: [
            {
              type: "input_text" as const,
              text: "You are a senior engineer resolving git merge conflicts. Return only the requested resolution tags and the final resolved file contents.",
            },
          ],
        },
        {
          role: "user" as const,
          content: [{ type: "input_text" as const, text: prompt }],
        },
      ],
      max_output_tokens: options.resolutionMaxOutputTokens,
    });

    const text = extractResponseText(response);
    if (!text) {
      throw new Error(`OpenAI returned no text for ${clone.name}:${conflict.relativePath}`);
    }

    try {
      return {
        conflict,
        resolution: validateResolution(
          conflict.relativePath,
          parseExpectedResolution(text, conflict.relativePath),
        ),
      };
    } catch (error) {
      if (error instanceof ResolutionResponseError && attempt < MAX_CONFLICT_RESOLUTION_ATTEMPTS) {
        continue;
      }
      throw error;
    }
  }

  throw new Error(`Unreachable resolution retry state for ${clone.name}:${conflict.relativePath}`);
}

async function resolveConflictGroup(
  getClient: OpenAIClientGetter,
  clone: CloneEntry,
  conflicts: ConflictFileInput[],
  allConflictPaths: string[],
  options: CliOptions,
): Promise<ResolvedConflictFile[]> {
  if (conflicts.length === 1) {
    return [await resolveConflictFile(getClient, clone, conflicts[0]!, allConflictPaths, options)];
  }

  const statusBlock = getRepoStatus(clone.clonePath) || "(empty)";
  const expectedPaths = conflicts.map((conflict) => conflict.relativePath);
  const prompt = [
    `Clone: ${clone.name}`,
    `Path: ${clone.clonePath}`,
    `Files: ${expectedPaths.join(", ")}`,
    "",
    "Resolve these related git conflicts into final files.",
    "Keep the files mutually consistent while preserving intent from both sides when compatible.",
    "If a file should be deleted, return <action>delete</action> for that file and omit <content>.",
    "Otherwise return <action>write</action> and wrap the full file contents in <content>...</content>.",
    "Return only XML-like tags in this exact shape, no explanation:",
    "<files>",
    "  <file>",
    "    <path>relative/path/from/request</path>",
    "    <action>write</action>",
    "    <content>full resolved file contents</content>",
    "  </file>",
    "</files>",
    "",
    "<git_status>",
    statusBlock,
    "</git_status>",
    "",
    "<all_conflicted_files>",
    formatConflictPaths(allConflictPaths),
    "</all_conflicted_files>",
    "",
    ...conflicts.flatMap((conflict) => [formatConflictFileInput(conflict), ""]),
  ].join("\n");

  for (let attempt = 1; attempt <= MAX_CONFLICT_RESOLUTION_ATTEMPTS; attempt += 1) {
    const response = await getClient().responses.create({
      model: options.openaiModel,
      input: [
        {
          role: "system" as const,
          content: [
            {
              type: "input_text" as const,
              text: "You are a senior engineer resolving related git merge conflicts. Return only the requested XML-like tags and the final resolved file contents.",
            },
          ],
        },
        {
          role: "user" as const,
          content: [{ type: "input_text" as const, text: prompt }],
        },
      ],
      max_output_tokens: options.resolutionMaxOutputTokens,
    });

    const text = extractResponseText(response);
    if (!text) {
      throw new Error(
        `OpenAI returned no text for grouped resolution in ${clone.name}:${expectedPaths.join(",")}`,
      );
    }

    try {
      const resolutions = parseGroupedResolutions(text, expectedPaths);
      return conflicts.map((conflict) => ({
        conflict,
        resolution: resolutions.get(conflict.relativePath)!,
      }));
    } catch (error) {
      if (error instanceof ResolutionResponseError && attempt < MAX_CONFLICT_RESOLUTION_ATTEMPTS) {
        continue;
      }
      throw error;
    }
  }

  throw new Error(
    `Unreachable grouped resolution retry state for ${clone.name}:${expectedPaths.join(",")}`,
  );
}

async function resolveConflictGroupWithFallback(
  getClient: OpenAIClientGetter,
  clone: CloneEntry,
  conflicts: ConflictFileInput[],
  allConflictPaths: string[],
  options: CliOptions,
): Promise<ResolvedConflictFile[]> {
  try {
    return await resolveConflictGroup(getClient, clone, conflicts, allConflictPaths, options);
  } catch (error) {
    if (conflicts.length === 1) {
      throw error;
    }

    const fallbackConcurrency = effectiveConcurrency(
      options.fileResolutionConcurrency,
      conflicts.length,
      DEFAULT_FILE_RESOLUTION_CONCURRENCY,
    );
    return mapWithConcurrency(conflicts, fallbackConcurrency, (conflict) =>
      resolveConflictFile(getClient, clone, conflict, allConflictPaths, options),
    );
  }
}

function markPathResolvedWithoutStaging(clonePath: string, relativePath: string): void {
  runGit(clonePath, ["add", "--", relativePath]);
  runGit(clonePath, ["reset", "HEAD", "--", relativePath]);
}

function resolvePnpmLockConflict(
  clone: CloneEntry,
  options: CliOptions,
  recordAction: ActionRecorder,
): string {
  if (options.dryRun) {
    return "pnpm-lock.yaml (planned: mise exec -- pnpm install --lockfile-only)";
  }

  const clonePath = clone.clonePath;
  let commandDescription = "mise exec -- pnpm install --lockfile-only";
  try {
    recordAction("resolving pnpm-lock.yaml via mise exec -- pnpm install --lockfile-only");
    runMise(clonePath, ["exec", "--", "pnpm", "install", "--lockfile-only"]);
  } catch (error) {
    if (!isCommandNotFound(error)) {
      throw error;
    }

    commandDescription = "pnpm install --lockfile-only";
    recordAction("resolving pnpm-lock.yaml via pnpm install --lockfile-only");
    runPnpm(clonePath, ["install", "--lockfile-only"]);
  }

  markPathResolvedWithoutStaging(clonePath, "pnpm-lock.yaml");
  if (listUnmergedFiles(clonePath).includes("pnpm-lock.yaml")) {
    throw new Error(
      `pnpm install --lockfile-only did not resolve pnpm-lock.yaml conflict in ${clone.name}`,
    );
  }

  return `pnpm-lock.yaml (resolved via ${commandDescription})`;
}

async function resolveConflictsInClone(
  getClient: OpenAIClientGetter,
  clone: CloneEntry,
  options: CliOptions,
  recordAction: ActionRecorder,
): Promise<string[]> {
  const resolvedFiles: string[] = [];
  const initialConflictPaths = listUnmergedFiles(clone.clonePath);
  if (initialConflictPaths.includes("pnpm-lock.yaml")) {
    resolvedFiles.push(resolvePnpmLockConflict(clone, options, recordAction));
  }

  const conflicts = getConflictFileInputs(clone.clonePath).filter(
    (conflict) => !(options.dryRun && conflict.relativePath === "pnpm-lock.yaml"),
  );
  const allConflictPaths = conflicts.map((conflict) => conflict.relativePath);
  const conflictOrder = new Map(
    allConflictPaths.map((relativePath, index) => [relativePath, index] as const),
  );
  const conflictGroups = buildConflictResolutionGroups(conflicts);
  const fileResolutionConcurrency = effectiveConcurrency(
    options.fileResolutionConcurrency,
    conflictGroups.length,
    DEFAULT_FILE_RESOLUTION_CONCURRENCY,
  );

  for (const conflict of conflicts) {
    if (conflict.relativePath === "pnpm-lock.yaml") {
      throw new Error(
        `pnpm lockfile helper did not resolve ${clone.name}:${conflict.relativePath}`,
      );
    }
  }

  if (conflictGroups.length > 0) {
    recordAction(
      `resolving ${conflicts.length} conflicted file(s) with OpenAI across ${conflictGroups.length} group(s)`,
    );
  }

  const groupedResolutions = await mapWithConcurrency(
    conflictGroups,
    fileResolutionConcurrency,
    (conflictGroup) =>
      resolveConflictGroupWithFallback(getClient, clone, conflictGroup, allConflictPaths, options),
  );
  const resolvedConflicts = groupedResolutions
    .flat()
    .sort(
      (left, right) =>
        conflictOrder.get(left.conflict.relativePath)! -
        conflictOrder.get(right.conflict.relativePath)!,
    );

  if (!options.dryRun) {
    for (const resolvedConflict of resolvedConflicts) {
      applyConflictResolution(
        clone.clonePath,
        resolvedConflict.conflict.relativePath,
        resolvedConflict.resolution,
      );
    }
  }

  for (const resolvedConflict of resolvedConflicts) {
    resolvedFiles.push(
      `${resolvedConflict.conflict.relativePath} (${
        options.dryRun ? "planned" : resolvedConflict.resolution.action
      })`,
    );
  }

  return resolvedFiles;
}

function shouldTargetClone(clone: CloneEntry, options: CliOptions): boolean {
  if (options.mode === "conflicts") {
    return getConflictFileInputs(clone.clonePath).length > 0;
  }

  if (options.mode === "recover" || options.mode === "auto") {
    return clone.dirty || getConflictFileInputs(clone.clonePath).length > 0;
  }

  return false;
}

function selectTargetClones(clones: CloneEntry[], cloneNames: string[]): CloneEntry[] {
  if (cloneNames.length === 0) {
    return clones;
  }

  const wanted = new Set(cloneNames);
  const selected = clones.filter((clone) => wanted.has(clone.name));
  const missing = cloneNames.filter(
    (cloneName) => !selected.some((clone) => clone.name === cloneName),
  );
  if (missing.length > 0) {
    throw new Error(`Unknown clone name(s): ${missing.join(", ")}`);
  }
  return selected;
}

function updateCloneSnapshot(clone: CloneEntry): void {
  clone.statusOutput = getRepoStatus(clone.clonePath);
  clone.dirty = clone.statusOutput.length > 0;
}

function createSafetySnapshotBranch(
  clone: CloneEntry,
  stashMarker: string,
): string {
  const clonePath = clone.clonePath;
  const restoreTarget = getCheckoutRestoreTarget(clonePath);
  const snapshotBranch = createUniqueBranchName(
    clonePath,
    `snapshot/${currentDateStamp()}-${clone.name}-pre-recover`,
  );

  runGit(clonePath, ["switch", "-c", snapshotBranch]);
  try {
    const applyResult = runGit(clonePath, ["stash", "apply", "--index", "stash@{0}"], [0, 1]);
    if (applyResult.status !== 0 || listUnmergedFiles(clonePath).length > 0) {
      throw new Error(
        `Failed to apply ${stashMarker} while creating safety snapshot branch ${snapshotBranch}`,
      );
    }

    runGit(clonePath, ["add", "-A"]);
    runGit(clonePath, [
      "commit",
      "--no-verify",
      "-m",
      `wip: snapshot before resolve-clones recover (${clone.name})`,
    ]);
  } finally {
    runGit(clonePath, restoreTarget.switchArgs);
  }

  return `created safety snapshot branch ${snapshotBranch} from ${restoreTarget.label}`;
}

function refreshDefaultBranchAndRestoreDirtyWork(
  clone: CloneEntry,
  options: CliOptions,
  recordAction: ActionRecorder,
): DirtyWorkRefreshResult {
  const actions: string[] = [];
  const record = (action: string): void => {
    actions.push(action);
    recordAction(action);
  };

  const clonePath = clone.clonePath;
  const remote = chooseRemote(clonePath);
  const defaultBranch = getDefaultBranch(clonePath, remote);
  const currentBranch = getCurrentBranch(clonePath);
  const reapplyBranch =
    currentBranch && currentBranch !== defaultBranch ? currentBranch : defaultBranch;
  const marker = `resolve-clones-${process.pid}-${Date.now()}-${clone.name}`;

  record(`stash dirty work (${marker})`);
  if (options.dryRun) {
    if (options.snapshotDirtyWork) {
      record(`create safety snapshot branch snapshot/${currentDateStamp()}-${clone.name}-pre-recover`);
    }
    record(`fetch ${remote}`);
    record(`switch to ${defaultBranch}`);
    record(`fast-forward ${defaultBranch} from ${remote}/${defaultBranch}`);
    if (reapplyBranch !== defaultBranch) {
      record(`switch back to ${reapplyBranch}`);
    }
    record(`reapply dirty work onto ${reapplyBranch}`);
    return { actions, stashMarker: marker };
  }

  runGit(clonePath, ["stash", "push", "-u", "-m", marker]);
  if (options.snapshotDirtyWork) {
    record(createSafetySnapshotBranch(clone, marker));
  }

  record(`fetch ${remote}`);
  runGit(clonePath, ["fetch", "--prune", remote]);

  record(`switch to ${defaultBranch}`);
  runGit(clonePath, ["checkout", defaultBranch]);
  runGit(clonePath, ["branch", "--set-upstream-to", `${remote}/${defaultBranch}`, defaultBranch]);

  record(`fast-forward ${defaultBranch} from ${remote}/${defaultBranch}`);
  const ffResult = runGit(clonePath, ["merge", "--ff-only", `${remote}/${defaultBranch}`], [0, 1]);
  if (ffResult.status !== 0) {
    const backupBranch = createUniqueBranchName(
      clonePath,
      `recover/${currentDateStamp()}-${clone.name}-${defaultBranch}-pre-reset`,
    );
    runGit(clonePath, ["branch", backupBranch, defaultBranch]);
    runGit(clonePath, ["reset", "--hard", `${remote}/${defaultBranch}`]);
    record(`backup ${defaultBranch} to ${backupBranch} before reset`);
  }

  if (reapplyBranch !== defaultBranch) {
    runGit(clonePath, ["checkout", reapplyBranch]);
    record(`restored branch ${reapplyBranch}`);
  }

  record(`reapply dirty work onto ${reapplyBranch}`);
  const applyResult = runGit(clonePath, ["stash", "apply", "stash@{0}"], [0, 1]);
  if (applyResult.status === 0) {
    maybeDropTopStash(clonePath, marker);
    record(`applied dirty work onto ${reapplyBranch}`);
    return { actions };
  }

  record(`stash apply produced conflicts on ${reapplyBranch}`);
  return { actions, stashMarker: marker };
}

async function resolveClone(
  getClient: OpenAIClientGetter,
  clone: CloneEntry,
  options: CliOptions,
  recordAction: ActionRecorder,
): Promise<ResolveResult> {
  const actions: string[] = [];
  const record = (action: string): void => {
    actions.push(action);
    recordAction(action);
  };

  if (hasInProgressOperation(clone.clonePath)) {
    record("skipped: repo has an in-progress git operation");
    return {
      cloneName: clone.name,
      status: "skipped",
      actions,
    };
  }

  const initialConflicts = listUnmergedFiles(clone.clonePath);
  if (initialConflicts.length > 0) {
    const resolvedFiles = await resolveConflictsInClone(getClient, clone, options, record);
    for (const resolvedFile of resolvedFiles) {
      record(resolvedFile);
    }
    updateCloneSnapshot(clone);
    return { cloneName: clone.name, status: "completed", actions };
  }

  if (options.mode === "conflicts") {
    record("no unmerged files");
    return { cloneName: clone.name, status: "skipped", actions };
  }

  if (!clone.dirty) {
    record("clean: nothing to do");
    return { cloneName: clone.name, status: "skipped", actions };
  }

  const refreshResult = refreshDefaultBranchAndRestoreDirtyWork(clone, options, record);
  updateCloneSnapshot(clone);

  const postApplyConflicts = listUnmergedFiles(clone.clonePath);
  if (postApplyConflicts.length > 0) {
    const resolvedFiles = await resolveConflictsInClone(getClient, clone, options, record);
    for (const resolvedFile of resolvedFiles) {
      record(resolvedFile);
    }
    if (!options.dryRun && refreshResult.stashMarker) {
      maybeDropTopStash(clone.clonePath, refreshResult.stashMarker);
    }
    updateCloneSnapshot(clone);
  }

  return { cloneName: clone.name, status: "completed", actions };
}

function createActionRecorder(clone: CloneEntry, stateTracker?: ResolveStateTracker): ActionRecorder {
  return (action: string) => {
    console.log(`[${clone.name}] ${action}`);
    stateTracker?.appendAction(clone.name, action);
  };
}

async function runTargetClones(
  targetClones: CloneEntry[],
  resolutionConcurrency: number,
  getClient: OpenAIClientGetter,
  options: CliOptions,
  stateTracker?: ResolveStateTracker,
): Promise<ResolveRunSummary> {
  const results: ResolveResult[] = [];
  let failed = false;

  const runOne = async (clone: CloneEntry): Promise<ResolveResult> => {
    const resumed = stateTracker?.resumeResultForClone(clone);
    if (resumed) {
      console.log(`[${clone.name}] ${resumed.actions[0]}`);
      return resumed;
    }

    console.log(`[${clone.name}] starting`);
    stateTracker?.markInProgress(clone);
    const recordAction = createActionRecorder(clone, stateTracker);

    try {
      const result = await resolveClone(getClient, clone, options, recordAction);
      stateTracker?.finalize(clone, result);
      console.log(`[${clone.name}] ${result.status}`);
      return result;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[${clone.name}] error: ${message}`);
      updateCloneSnapshot(clone);
      const result: ResolveResult = {
        cloneName: clone.name,
        status: "failed",
        actions: [`error: ${message}`],
        error: message,
      };
      stateTracker?.finalize(clone, result);
      return result;
    }
  };

  if (resolutionConcurrency === 1 || !options.continueOnError) {
    for (const clone of targetClones) {
      const result = await runOne(clone);
      results.push(result);
      if (result.status === "failed") {
        failed = true;
        if (!options.continueOnError) {
          break;
        }
      }
    }

    return { results, failed };
  }

  const parallelResults = await mapWithConcurrency(targetClones, resolutionConcurrency, async (clone) =>
    runOne(clone),
  );
  for (const result of parallelResults) {
    results.push(result);
    if (result.status === "failed") {
      failed = true;
    }
  }
  return { results, failed };
}

function defaultStateFilePath(outerDir: string, prefix: string, mode: ResolveMode): string {
  return path.join(outerDir, `.${prefix}-resolve-clones-${mode}.json`);
}

function shouldUseStateTracking(options: CliOptions): boolean {
  return !options.dryRun && (options.mode === "recover" || options.mode === "auto");
}

async function main(): Promise<void> {
  const program = new Command();
  program
    .name("resolve-clones")
    .description(
      "Resolve conflicted clone files, or refresh each clone's default branch and restore dirty work on the branch where it started with OpenAI assistance.",
    )
    .requiredOption("-p, --prefix <prefix>", "Clone prefix under ~/<prefix>_src")
    .option(
      "--clone <name>",
      "Specific clone name to resolve; repeat to target multiple clones",
      collectString,
      [],
    )
    .option("--mode <mode>", "Resolution mode: conflicts, recover, or auto", "auto")
    .option("--openai-api-key <key>", "OpenAI API key")
    .option("--openai-model <model>", "OpenAI model", DEFAULT_RESOLUTION_MODEL)
    .option("--resolution-concurrency <count>", "Max parallel clone resolutions", parsePositiveInt)
    .option(
      "--file-resolution-concurrency <count>",
      "Max parallel OpenAI resolution requests within one clone; defaults to 2",
      parsePositiveInt,
    )
    .option(
      "--resolution-max-output-tokens <count>",
      "Max OpenAI output tokens per conflict file resolution",
      parsePositiveInt,
      DEFAULT_RESOLUTION_MAX_OUTPUT_TOKENS,
    )
    .option(
      "--continue-on-error",
      "Keep processing remaining clones after a clone fails; recover mode defaults to stop-on-error",
      false,
    )
    .option(
      "--reset-state",
      "Ignore any prior recover state file and start a fresh run",
      false,
    )
    .option(
      "--snapshot-dirty-work",
      "Before recover, create a local safety branch with a WIP snapshot commit of the dirty state",
      false,
    )
    .option(
      "--state-file <path>",
      "Override the recover state file path; defaults to ~/<prefix>_src/.<prefix>-resolve-clones-<mode>.json",
    )
    .option("--dry-run", "Print planned resolutions without writing files", false)
    .showHelpAfterError();

  program.parse();
  const rawOptions = program.opts<CliOptions & { mode: string }>();
  if (!["conflicts", "recover", "auto"].includes(rawOptions.mode)) {
    throw new Error(`Invalid mode: ${rawOptions.mode}`);
  }
  const options: CliOptions = {
    ...rawOptions,
    mode: rawOptions.mode as ResolveMode,
  };

  const { outerDir, clones } = listCloneEntries(options.prefix);
  const selectedClones = selectTargetClones(clones, options.clone ?? []);
  const targetClones = selectedClones.filter((clone) => shouldTargetClone(clone, options));
  const defaultResolutionConcurrency =
    options.mode === "recover" || options.mode === "auto"
      ? DEFAULT_RECOVER_RESOLUTION_CONCURRENCY
      : targetClones.length;
  const resolutionConcurrency = effectiveConcurrency(
    options.resolutionConcurrency,
    targetClones.length,
    defaultResolutionConcurrency,
  );
  const fileResolutionConcurrency =
    options.fileResolutionConcurrency ?? DEFAULT_FILE_RESOLUTION_CONCURRENCY;

  if (targetClones.length === 0) {
    console.log(`No matching clones found under ~/${options.prefix}_src for mode=${options.mode}.`);
    return;
  }

  console.log(
    `${options.dryRun ? "Planning" : "Resolving"} ${targetClones.length} clone(s) in mode=${options.mode} (clone-concurrency=${resolutionConcurrency}, file-concurrency=${fileResolutionConcurrency}); OpenAI ${options.openaiModel} will only be used for conflicted files...`,
  );

  let stateTracker: ResolveStateTracker | undefined;
  if (shouldUseStateTracking(options)) {
    const stateFile =
      options.stateFile ?? defaultStateFilePath(outerDir, options.prefix, options.mode);
    stateTracker = ResolveStateTracker.load(
      stateFile,
      options,
      resolutionConcurrency,
      fileResolutionConcurrency,
    );
    console.log(`Using recover state file ${stateTracker.filePath}`);
  }

  const getClient = createOpenAIClientGetter(options);
  const summary = await runTargetClones(
    targetClones,
    resolutionConcurrency,
    getClient,
    options,
    stateTracker,
  );

  for (const result of summary.results) {
    console.log(`\n${result.cloneName} [${result.status}]`);
    console.log("-".repeat(result.cloneName.length + result.status.length + 3));
    if (result.actions.length === 0) {
      console.log("No changes.");
      continue;
    }
    for (const action of result.actions) {
      console.log(action);
    }
  }

  if (stateTracker && !summary.failed && !stateTracker.hasFailures()) {
    stateTracker.removeFile();
    console.log(`\nRemoved recover state file ${stateTracker.filePath}`);
  }

  if (summary.failed) {
    const statePath = stateTracker ? `; state saved in ${stateTracker.filePath}` : "";
    throw new Error(`One or more clones failed to resolve${statePath}`);
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});

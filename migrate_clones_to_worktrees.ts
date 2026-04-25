import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import process from "node:process";

import { Command, InvalidArgumentError } from "commander";
import OpenAI from "openai";

import {
  DEFAULT_SUMMARY_MAX_DIFF_CHARS,
  DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS,
  DEFAULT_SUMMARY_MODEL,
  normalizeBranchName,
  suggestBranchNameForClone,
} from "./clone_branch_names.js";
import { listCloneEntries, listUnmergedFiles, type CloneEntry } from "./clone_tools.js";

const PLAN_VERSION = 1;
const DEFAULT_WIP_COMMIT_MESSAGE = "wip: snapshot before worktree migration";
const AUTOWT_BRANCH_PLACEHOLDER = "__AUTOWT_BRANCH__";

type MigrationStatus = "planned" | "committed" | "fetched" | "worktree_created" | "quarantined";

interface CliOptions {
  prefix: string;
  clone: string[];
  branch: BranchOverride[];
  apply: boolean;
  quarantine: boolean;
  planFile?: string;
  anchorPath?: string;
  worktreeRoot?: string;
  quarantineRoot?: string;
  openaiApiKey?: string;
  openaiModel: string;
  summaryConcurrency?: number;
  summaryMaxOutputTokens: number;
  summaryMaxDiffChars: number;
}

interface CommandResult {
  stdout: string;
  stderr: string;
  status: number;
}

interface BranchOverride {
  cloneName: string;
  branchName: string;
}

interface MigrationPlan {
  version: number;
  prefix: string;
  createdAt: string;
  updatedAt: string;
  planFile: string;
  anchorPath: string;
  anchorDefaultBranch: string;
  anchorHeadSha: string;
  worktreeRoot: string;
  quarantineRoot: string;
  entries: MigrationPlanEntry[];
}

interface MigrationPlanEntry {
  cloneName: string;
  clonePath: string;
  originalBranch: string;
  originalHeadSha: string;
  originalStatusOutput: string;
  desiredBranch: string;
  branchNameSource: "override" | "openai";
  truncatedDiff: boolean;
  worktreePath: string;
  quarantinePath: string;
  wipCommitMessage: string;
  migrationStatus: MigrationStatus;
  sourceCommitSha?: string;
  worktreeHeadSha?: string;
  plannedAt: string;
  updatedAt: string;
  lastError?: string;
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

function parseBranchOverride(raw: string): BranchOverride {
  const separatorIndex = raw.indexOf("=");
  if (separatorIndex <= 0 || separatorIndex === raw.length - 1) {
    throw new InvalidArgumentError(
      `Expected branch override in clone=branch format, got ${raw}`,
    );
  }

  const cloneName = raw.slice(0, separatorIndex).trim();
  const branchName = normalizeBranchName(raw.slice(separatorIndex + 1).trim());
  if (!cloneName) {
    throw new InvalidArgumentError(`Missing clone name in branch override: ${raw}`);
  }

  return { cloneName, branchName };
}

function nowIso(): string {
  return new Date().toISOString();
}

function formatUsageError(command: string, status: number, stderr: string): Error {
  const trimmedStderr = stderr.trim();
  if (trimmedStderr) {
    return new Error(`${command} exited with status ${status}: ${trimmedStderr}`);
  }
  return new Error(`${command} exited with status ${status}`);
}

function expandHomePath(inputPath: string): string {
  if (inputPath === "~") {
    return os.homedir();
  }
  if (inputPath.startsWith("~/")) {
    return path.join(os.homedir(), inputPath.slice(2));
  }
  return path.resolve(inputPath);
}

function defaultPlanFilePath(outerDir: string, prefix: string): string {
  return path.join(outerDir, `.${prefix}-worktree-migration-plan.json`);
}

function repoNameForPath(repoPath: string): string {
  const baseName = path.basename(repoPath);
  return baseName.endsWith(".git") ? baseName.slice(0, -4) : baseName;
}

function expandEnvironmentVariables(value: string): string {
  return value.replace(/\$([A-Z_][A-Z0-9_]*)|\$\{([A-Z_][A-Z0-9_]*)\}/g, (_match, simple, braced) => {
    const variableName = (simple || braced || "") as string;
    return process.env[variableName] ?? "";
  });
}

function readAutowtDirectoryPattern(anchorPath: string): string | undefined {
  const autowtConfigPath = path.join(anchorPath, ".autowt.toml");
  if (!fs.existsSync(autowtConfigPath)) {
    return undefined;
  }

  const rawConfig = fs.readFileSync(autowtConfigPath, "utf8");
  const worktreeSection = /(?:^|\n)\[worktree\]\s*([\s\S]*?)(?=\n\[|$)/.exec(rawConfig)?.[1];
  if (!worktreeSection) {
    return undefined;
  }

  const patternMatch = /^\s*directory_pattern\s*=\s*"([^"\n]*)"\s*$/m.exec(worktreeSection);
  return patternMatch?.[1];
}

function sanitizeAutowtWorktreeLeaf(branchName: string): string {
  let sanitized = branchName.replaceAll("/", "-").replaceAll(" ", "-").replaceAll("\\", "-");
  sanitized = sanitized.replace(/[^A-Za-z0-9._-]+/g, "");
  sanitized = sanitized.replace(/^[.-]+|[.-]+$/g, "");
  return sanitized || "branch";
}

function resolveAutowtWorktreePath(
  anchorPath: string,
  directoryPattern: string,
  branchName: string,
): string {
  const rendered = directoryPattern
    .replaceAll("{repo_dir}", anchorPath)
    .replaceAll("{repo_name}", repoNameForPath(anchorPath))
    .replaceAll("{repo_parent_dir}", path.dirname(anchorPath))
    .replaceAll("{branch}", sanitizeAutowtWorktreeLeaf(branchName));
  const expanded = expandEnvironmentVariables(rendered);
  if (path.isAbsolute(expanded)) {
    return path.normalize(expanded);
  }
  return path.normalize(path.join(anchorPath, expanded));
}

function defaultWorktreeRoot(prefix: string, anchorPath: string): string {
  const autowtDirectoryPattern = readAutowtDirectoryPattern(anchorPath);
  if (autowtDirectoryPattern) {
    return path.dirname(
      resolveAutowtWorktreePath(anchorPath, autowtDirectoryPattern, AUTOWT_BRANCH_PLACEHOLDER),
    );
  }
  return path.join(os.homedir(), `${prefix}_worktrees`);
}

function defaultQuarantineRoot(prefix: string): string {
  return path.join(os.homedir(), `${prefix}_src`, "_old-clones");
}

function worktreeLeafForBranch(branchName: string): string {
  return sanitizeAutowtWorktreeLeaf(branchName);
}

function effectiveConcurrency(requested: number | undefined, itemCount: number): number {
  if (itemCount <= 0) {
    return 1;
  }
  if (requested == null) {
    return itemCount;
  }
  return Math.max(1, Math.min(requested, itemCount));
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

function runCommand(
  command: string,
  cwd: string,
  args: string[],
  allowedStatuses: number[] = [0],
): CommandResult {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
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
  cwd: string,
  args: string[],
  allowedStatuses: number[] = [0],
): CommandResult {
  return runCommand("git", cwd, args, allowedStatuses);
}

function getRepoStatus(repoPath: string): string {
  return runGit(repoPath, ["status", "--porcelain", "--untracked-files=normal"]).stdout.trimEnd();
}

function getHeadSha(repoPath: string, ref = "HEAD"): string {
  return runGit(repoPath, ["rev-parse", ref]).stdout.trim();
}

function getCurrentBranch(repoPath: string): string {
  return runGit(repoPath, ["branch", "--show-current"]).stdout.trim();
}

interface GitWorktreeEntry {
  path: string;
  branch?: string;
}

function getGitDir(repoPath: string): string {
  return path.join(repoPath, runGit(repoPath, ["rev-parse", "--git-dir"]).stdout.trim());
}

function listGitWorktrees(repoPath: string): GitWorktreeEntry[] {
  const rawOutput = runGit(repoPath, ["worktree", "list", "--porcelain"]).stdout;
  const entries: GitWorktreeEntry[] = [];
  let currentEntry: GitWorktreeEntry | undefined;

  for (const line of rawOutput.split(/\r?\n/)) {
    if (!line) {
      continue;
    }
    if (line.startsWith("worktree ")) {
      currentEntry = { path: line.slice("worktree ".length).trim() };
      entries.push(currentEntry);
      continue;
    }
    if (!currentEntry) {
      continue;
    }
    if (line.startsWith("branch ")) {
      const ref = line.slice("branch ".length).trim();
      currentEntry.branch = ref.replace(/^refs\/heads\//, "");
    }
  }

  return entries;
}

let cachedAutowtCommand: string | undefined;
let autowtCommandResolved = false;
let cachedMiseCommand: string | undefined;
let miseCommandResolved = false;

function findAutowtCommand(): string | undefined {
  if (autowtCommandResolved) {
    return cachedAutowtCommand;
  }

  autowtCommandResolved = true;
  for (const candidate of ["autowt", "awt"]) {
    const result = spawnSync(candidate, ["--version"], {
      cwd: process.cwd(),
      encoding: "utf8",
      maxBuffer: 1024 * 1024,
    });
    if (!result.error && (result.status ?? 1) === 0) {
      cachedAutowtCommand = candidate;
      return cachedAutowtCommand;
    }
  }

  cachedAutowtCommand = undefined;
  return undefined;
}

function findMiseCommand(): string | undefined {
  if (miseCommandResolved) {
    return cachedMiseCommand;
  }

  miseCommandResolved = true;
  const result = spawnSync("mise", ["--version"], {
    cwd: process.cwd(),
    encoding: "utf8",
    maxBuffer: 1024 * 1024,
  });
  if (!result.error && (result.status ?? 1) === 0) {
    cachedMiseCommand = "mise";
    return cachedMiseCommand;
  }

  cachedMiseCommand = undefined;
  return undefined;
}

function hasInProgressOperation(repoPath: string): boolean {
  const gitDir = getGitDir(repoPath);
  return [
    "rebase-merge",
    "rebase-apply",
    "MERGE_HEAD",
    "CHERRY_PICK_HEAD",
    "REVERT_HEAD",
    "BISECT_LOG",
  ].some((entry) => fs.existsSync(path.join(gitDir, entry)));
}

function chooseRemote(repoPath: string): string {
  const originCheck = runGit(repoPath, ["ls-remote", "--exit-code", "origin"], [0, 2, 128]);
  if (originCheck.status === 0) {
    return "origin";
  }

  const upstreamCheck = runGit(repoPath, ["remote", "get-url", "upstream"], [0, 2]);
  if (upstreamCheck.status === 0) {
    return "upstream";
  }

  throw new Error(`Unable to reach origin and no upstream remote is configured for ${repoPath}`);
}

function getDefaultBranch(repoPath: string, remote: string): string {
  const symbolic = runGit(
    repoPath,
    ["symbolic-ref", "--quiet", "--short", `refs/remotes/${remote}/HEAD`],
    [0, 1],
  ).stdout.trim();
  if (symbolic) {
    return symbolic.replace(new RegExp(`^${remote}/`), "");
  }

  const fallback = runGit(repoPath, ["remote", "show", remote]).stdout;
  const match = /HEAD branch:\s+([^\s]+)/.exec(fallback);
  if (match?.[1]) {
    return match[1];
  }

  throw new Error(`Unable to determine default branch for ${repoPath}`);
}

function gitRefExists(repoPath: string, ref: string): boolean {
  return runGit(repoPath, ["show-ref", "--verify", "--quiet", ref], [0, 1]).status === 0;
}

function ensureRepoReady(repoPath: string, label: string): void {
  if (hasInProgressOperation(repoPath)) {
    throw new Error(`${label} has an in-progress git operation`);
  }
  if (listUnmergedFiles(repoPath).length > 0) {
    throw new Error(`${label} has unmerged paths`);
  }
}

function ensureAnchorReadyForPlan(anchorPath: string): { defaultBranch: string; headSha: string } {
  ensureRepoReady(anchorPath, `anchor repo ${anchorPath}`);
  const remote = chooseRemote(anchorPath);
  const defaultBranch = getDefaultBranch(anchorPath, remote);
  const currentBranch = getCurrentBranch(anchorPath);
  const statusOutput = getRepoStatus(anchorPath);
  if (currentBranch !== defaultBranch) {
    throw new Error(
      `Anchor repo ${anchorPath} must be on ${defaultBranch}; currently on ${currentBranch || "detached HEAD"}`,
    );
  }
  if (statusOutput) {
    throw new Error(`Anchor repo ${anchorPath} must be clean before planning/applying`);
  }

  return { defaultBranch, headSha: getHeadSha(anchorPath) };
}

function ensureAnchorReadyForApply(plan: MigrationPlan): void {
  const { defaultBranch, headSha } = ensureAnchorReadyForPlan(plan.anchorPath);
  if (defaultBranch !== plan.anchorDefaultBranch) {
    throw new Error(
      `Anchor default branch changed from ${plan.anchorDefaultBranch} to ${defaultBranch}; regenerate the plan.`,
    );
  }
  if (headSha !== plan.anchorHeadSha) {
    throw new Error(
      `Anchor HEAD changed from ${plan.anchorHeadSha.slice(0, 12)} to ${headSha.slice(0, 12)}; regenerate the plan.`,
    );
  }
}

function savePlan(planPath: string, plan: MigrationPlan): void {
  plan.updatedAt = nowIso();
  fs.mkdirSync(path.dirname(planPath), { recursive: true });
  fs.writeFileSync(planPath, `${JSON.stringify(plan, null, 2)}\n`, "utf8");
}

function loadPlan(planPath: string, prefix: string): MigrationPlan {
  if (!fs.existsSync(planPath)) {
    throw new Error(`Plan file does not exist: ${planPath}`);
  }

  const raw = fs.readFileSync(planPath, "utf8");
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse plan file ${planPath}: ${message}`);
  }

  const plan = parsed as MigrationPlan;
  if (plan.version !== PLAN_VERSION) {
    throw new Error(
      `Unsupported plan file version ${String(plan.version)} in ${planPath}; regenerate the plan.`,
    );
  }
  if (plan.prefix !== prefix) {
    throw new Error(`Plan file ${planPath} is for prefix ${plan.prefix}, not ${prefix}`);
  }
  return plan;
}

function selectTargetDirtyClones(
  allClones: CloneEntry[],
  prefix: string,
  requestedNames: string[],
): CloneEntry[] {
  const dirtyClones = allClones.filter((clone) => clone.dirty && clone.name !== prefix);
  if (requestedNames.length === 0) {
    return dirtyClones;
  }

  const wanted = new Set(requestedNames);
  const selected = dirtyClones.filter((clone) => wanted.has(clone.name));
  const missing = requestedNames.filter(
    (cloneName) => !selected.some((clone) => clone.name === cloneName),
  );
  if (missing.length > 0) {
    throw new Error(`Dirty clone(s) not found: ${missing.join(", ")}`);
  }
  return selected;
}

function buildBranchOverrideMap(overrides: BranchOverride[]): Map<string, string> {
  const map = new Map<string, string>();
  for (const override of overrides) {
    if (map.has(override.cloneName)) {
      throw new Error(`Branch override specified more than once for ${override.cloneName}`);
    }
    map.set(override.cloneName, override.branchName);
  }
  return map;
}

function findAnchorClone(clones: CloneEntry[], prefix: string): CloneEntry {
  const anchorClone = clones.find((clone) => clone.name === prefix);
  if (!anchorClone) {
    throw new Error(`Anchor clone ${prefix} not found under ~/${prefix}_src`);
  }
  return anchorClone;
}

async function createMigrationPlan(options: CliOptions): Promise<MigrationPlan> {
  const { outerDir, clones } = listCloneEntries(options.prefix);
  const anchorClone = findAnchorClone(clones, options.prefix);
  const anchorPath = options.anchorPath
    ? expandHomePath(options.anchorPath)
    : anchorClone.clonePath;
  const autowtDirectoryPattern =
    options.worktreeRoot == null ? readAutowtDirectoryPattern(anchorPath) : undefined;
  const worktreeRoot = options.worktreeRoot
    ? expandHomePath(options.worktreeRoot)
    : defaultWorktreeRoot(options.prefix, anchorPath);
  const quarantineRoot = options.quarantineRoot
    ? expandHomePath(options.quarantineRoot)
    : defaultQuarantineRoot(options.prefix);
  const planFile = options.planFile
    ? expandHomePath(options.planFile)
    : defaultPlanFilePath(outerDir, options.prefix);
  const { defaultBranch, headSha } = ensureAnchorReadyForPlan(anchorPath);

  const dirtyClones = clones.filter((clone) => clone.dirty && clone.name !== options.prefix);
  if (dirtyClones.length === 0) {
    throw new Error(`No dirty clones found under ~/${options.prefix}_src`);
  }

  const targetClones =
    options.clone.length > 0
      ? selectTargetDirtyClones(clones, options.prefix, options.clone)
      : dirtyClones;

  const branchOverrideMap = buildBranchOverrideMap(options.branch);
  const clonesNeedingOpenAI = targetClones.filter((clone) => !branchOverrideMap.has(clone.name));

  const branchSuggestions = new Map<
    string,
    {
      branchName: string;
      truncated: boolean;
      source: "override" | "openai";
    }
  >();

  for (const clone of targetClones) {
    const override = branchOverrideMap.get(clone.name);
    if (!override) {
      continue;
    }
    branchSuggestions.set(clone.name, {
      branchName: override,
      truncated: false,
      source: "override",
    });
  }

  if (clonesNeedingOpenAI.length > 0) {
    const apiKey = options.openaiApiKey || process.env.OPENAI_API_KEY || "";
    if (!apiKey) {
      throw new Error(
        "OpenAI API key missing. Set OPENAI_API_KEY, pass --openai-api-key, or provide --branch overrides for every dirty clone.",
      );
    }

    const client = new OpenAI({ apiKey });
    const concurrency = effectiveConcurrency(options.summaryConcurrency, clonesNeedingOpenAI.length);
    console.log(
      `Suggesting branch names for ${clonesNeedingOpenAI.length} clone(s) with ${options.openaiModel} (${concurrency} request(s) in flight)...`,
    );
    const suggestions = await mapWithConcurrency(clonesNeedingOpenAI, concurrency, (clone) =>
      suggestBranchNameForClone(client, clone, {
        openaiModel: options.openaiModel,
        summaryMaxOutputTokens: options.summaryMaxOutputTokens,
        summaryMaxDiffChars: options.summaryMaxDiffChars,
      }),
    );
    for (const [index, clone] of clonesNeedingOpenAI.entries()) {
      const suggestion = suggestions[index]!;
      branchSuggestions.set(clone.name, {
        branchName: suggestion.branchName,
        truncated: suggestion.truncated,
        source: "openai",
      });
    }
  }

  const usedBranches = new Set<string>();
  const usedWorktreePaths = new Set<string>();
  const entries: MigrationPlanEntry[] = [];
  for (const clone of targetClones) {
    ensureRepoReady(clone.clonePath, clone.name);
    const currentBranch = getCurrentBranch(clone.clonePath);
    if (currentBranch !== defaultBranch) {
      throw new Error(
        `${clone.name} must be on ${defaultBranch} before migration; currently on ${currentBranch || "detached HEAD"}`,
      );
    }
    if (getHeadSha(clone.clonePath) !== headSha) {
      throw new Error(
        `${clone.name} is not on anchor HEAD ${headSha.slice(0, 12)}; run recover/update first.`,
      );
    }

    const suggestion = branchSuggestions.get(clone.name);
    if (!suggestion) {
      throw new Error(`Missing branch suggestion for ${clone.name}`);
    }
    if (usedBranches.has(suggestion.branchName)) {
      throw new Error(`Branch name collision: ${suggestion.branchName}`);
    }
    usedBranches.add(suggestion.branchName);

    if (gitRefExists(clone.clonePath, `refs/heads/${suggestion.branchName}`)) {
      throw new Error(`${clone.name} already has a local branch named ${suggestion.branchName}`);
    }
    if (gitRefExists(anchorPath, `refs/heads/${suggestion.branchName}`)) {
      throw new Error(`Anchor repo already has a local branch named ${suggestion.branchName}`);
    }

    const worktreePath = autowtDirectoryPattern
      ? resolveAutowtWorktreePath(anchorPath, autowtDirectoryPattern, suggestion.branchName)
      : path.join(worktreeRoot, worktreeLeafForBranch(suggestion.branchName));
    if (usedWorktreePaths.has(worktreePath)) {
      throw new Error(`Worktree path collision: ${worktreePath}`);
    }
    usedWorktreePaths.add(worktreePath);
    if (fs.existsSync(worktreePath)) {
      throw new Error(`Worktree path already exists: ${worktreePath}`);
    }

    const quarantinePath = path.join(quarantineRoot, clone.name);
    if (fs.existsSync(quarantinePath)) {
      throw new Error(`Quarantine path already exists: ${quarantinePath}`);
    }

    entries.push({
      cloneName: clone.name,
      clonePath: clone.clonePath,
      originalBranch: currentBranch,
      originalHeadSha: getHeadSha(clone.clonePath),
      originalStatusOutput: clone.statusOutput,
      desiredBranch: suggestion.branchName,
      branchNameSource: suggestion.source,
      truncatedDiff: suggestion.truncated,
      worktreePath,
      quarantinePath,
      wipCommitMessage: `${DEFAULT_WIP_COMMIT_MESSAGE} (${clone.name})`,
      migrationStatus: "planned",
      plannedAt: nowIso(),
      updatedAt: nowIso(),
    });
  }

  const plan: MigrationPlan = {
    version: PLAN_VERSION,
    prefix: options.prefix,
    createdAt: nowIso(),
    updatedAt: nowIso(),
    planFile,
    anchorPath,
    anchorDefaultBranch: defaultBranch,
    anchorHeadSha: headSha,
    worktreeRoot,
    quarantineRoot,
    entries,
  };
  savePlan(planFile, plan);
  return plan;
}

function printPlan(plan: MigrationPlan): void {
  console.log(`Plan file: ${plan.planFile}`);
  console.log(`Anchor repo: ${plan.anchorPath}`);
  console.log(`Anchor branch: ${plan.anchorDefaultBranch} @ ${plan.anchorHeadSha.slice(0, 12)}`);
  console.log(`Worktree root: ${plan.worktreeRoot}`);
  console.log(`Quarantine root: ${plan.quarantineRoot}`);
  const autowtCommand = findAutowtCommand();
  if (autowtCommand && fs.existsSync(path.join(plan.anchorPath, ".autowt.toml"))) {
    console.log(`Worktree creation: ${autowtCommand} switch --terminal echo (repo hooks enabled)`);
  }
  console.log(`Dirty clones to migrate: ${plan.entries.length}`);

  for (const entry of plan.entries) {
    const truncationNote = entry.truncatedDiff ? " [diff truncated]" : "";
    console.log(`\n${entry.cloneName}${truncationNote}`);
    console.log("-".repeat(entry.cloneName.length + truncationNote.length));
    console.log(`branch: ${entry.desiredBranch} (${entry.branchNameSource})`);
    console.log(`worktree: ${entry.worktreePath}`);
    console.log(`quarantine: ${entry.quarantinePath}`);
  }

  console.log("\nNext step:");
  console.log(`mise run migrate-clones-to-worktrees -- -p ${plan.prefix} --apply`);
  console.log(`mise run migrate-clones-to-worktrees -- -p ${plan.prefix} --apply --quarantine`);
}

function selectPlanEntries(plan: MigrationPlan, requestedNames: string[]): MigrationPlanEntry[] {
  if (requestedNames.length === 0) {
    return plan.entries;
  }

  const wanted = new Set(requestedNames);
  const selected = plan.entries.filter((entry) => wanted.has(entry.cloneName));
  const missing = requestedNames.filter(
    (cloneName) => !selected.some((entry) => entry.cloneName === cloneName),
  );
  if (missing.length > 0) {
    throw new Error(`Clone(s) not found in plan file: ${missing.join(", ")}`);
  }
  return selected;
}

function verifyOriginalSnapshot(entry: MigrationPlanEntry): void {
  if (!fs.existsSync(entry.clonePath)) {
    throw new Error(`Original clone path no longer exists: ${entry.clonePath}`);
  }

  ensureRepoReady(entry.clonePath, entry.cloneName);
  const currentBranch = getCurrentBranch(entry.clonePath);
  const currentHeadSha = getHeadSha(entry.clonePath);
  const currentStatus = getRepoStatus(entry.clonePath);
  if (currentBranch !== entry.originalBranch) {
    throw new Error(
      `${entry.cloneName} moved from ${entry.originalBranch} to ${currentBranch || "detached HEAD"} since planning`,
    );
  }
  if (currentHeadSha !== entry.originalHeadSha) {
    throw new Error(
      `${entry.cloneName} HEAD changed from ${entry.originalHeadSha.slice(0, 12)} to ${currentHeadSha.slice(0, 12)} since planning`,
    );
  }
  if (currentStatus !== entry.originalStatusOutput) {
    throw new Error(`${entry.cloneName} working tree changed since planning`);
  }
}

function ensureCommittedState(entry: MigrationPlanEntry): void {
  if (!entry.sourceCommitSha) {
    throw new Error(`Missing source commit SHA for ${entry.cloneName}`);
  }
  if (!fs.existsSync(entry.clonePath)) {
    throw new Error(`Original clone path no longer exists: ${entry.clonePath}`);
  }
  ensureRepoReady(entry.clonePath, entry.cloneName);
  const currentBranch = getCurrentBranch(entry.clonePath);
  const currentHeadSha = getHeadSha(entry.clonePath);
  const currentStatus = getRepoStatus(entry.clonePath);
  if (currentBranch !== entry.desiredBranch) {
    throw new Error(
      `${entry.cloneName} expected branch ${entry.desiredBranch}, found ${currentBranch || "detached HEAD"}`,
    );
  }
  if (currentHeadSha !== entry.sourceCommitSha) {
    throw new Error(
      `${entry.cloneName} expected committed HEAD ${entry.sourceCommitSha.slice(0, 12)}, found ${currentHeadSha.slice(0, 12)}`,
    );
  }
  if (currentStatus) {
    throw new Error(`${entry.cloneName} should be clean after WIP commit, but is dirty`);
  }
}

function ensureFetchedState(entry: MigrationPlanEntry, anchorPath: string): void {
  if (!entry.sourceCommitSha) {
    throw new Error(`Missing source commit SHA for ${entry.cloneName}`);
  }
  if (!gitRefExists(anchorPath, `refs/heads/${entry.desiredBranch}`)) {
    throw new Error(`Anchor repo is missing branch ${entry.desiredBranch}`);
  }
  const anchorBranchSha = getHeadSha(anchorPath, entry.desiredBranch);
  if (anchorBranchSha !== entry.sourceCommitSha) {
    throw new Error(
      `Anchor branch ${entry.desiredBranch} expected ${entry.sourceCommitSha.slice(0, 12)}, found ${anchorBranchSha.slice(0, 12)}`,
    );
  }
}

function ensureWorktreeState(entry: MigrationPlanEntry): void {
  if (!entry.worktreeHeadSha) {
    throw new Error(`Missing worktree SHA for ${entry.cloneName}`);
  }
  if (!fs.existsSync(entry.worktreePath)) {
    throw new Error(`Worktree path does not exist: ${entry.worktreePath}`);
  }
  const worktreeHeadSha = getHeadSha(entry.worktreePath);
  if (worktreeHeadSha !== entry.worktreeHeadSha) {
    throw new Error(
      `Worktree ${entry.worktreePath} expected ${entry.worktreeHeadSha.slice(0, 12)}, found ${worktreeHeadSha.slice(0, 12)}`,
    );
  }
}

function markEntryUpdated(entry: MigrationPlanEntry): void {
  entry.updatedAt = nowIso();
}

function maybeQuarantineOriginalClone(entry: MigrationPlanEntry): boolean {
  if (!fs.existsSync(entry.clonePath)) {
    return false;
  }
  fs.mkdirSync(path.dirname(entry.quarantinePath), { recursive: true });
  if (fs.existsSync(entry.quarantinePath)) {
    throw new Error(`Quarantine path already exists: ${entry.quarantinePath}`);
  }
  fs.renameSync(entry.clonePath, entry.quarantinePath);
  entry.migrationStatus = "quarantined";
  entry.lastError = undefined;
  markEntryUpdated(entry);
  return true;
}

function maybeTrustMiseWorktree(worktreePath: string): boolean {
  const miseCommand = findMiseCommand();
  if (!miseCommand) {
    return false;
  }

  const hasMiseConfig = ["mise.toml", ".mise.toml", ".miserc.toml"].some((filename) =>
    fs.existsSync(path.join(worktreePath, filename)),
  );
  if (!hasMiseConfig) {
    return false;
  }

  runCommand(miseCommand, worktreePath, ["trust"]);
  return true;
}

function createLinkedWorktree(plan: MigrationPlan, entry: MigrationPlanEntry): "autowt" | "git" {
  const existingWorktree = listGitWorktrees(plan.anchorPath).find(
    (worktree) => worktree.branch === entry.desiredBranch,
  );
  if (existingWorktree && path.resolve(existingWorktree.path) !== path.resolve(entry.worktreePath)) {
    throw new Error(
      `Branch ${entry.desiredBranch} is already checked out at ${existingWorktree.path}; remove or reuse that worktree before migrating ${entry.cloneName}.`,
    );
  }

  const autowtCommand = findAutowtCommand();
  if (autowtCommand && fs.existsSync(path.join(plan.anchorPath, ".autowt.toml"))) {
    runCommand(autowtCommand, plan.anchorPath, [
      "switch",
      "--terminal",
      "echo",
      "--yes",
      "--dir",
      entry.worktreePath,
      entry.desiredBranch,
    ]);
    return "autowt";
  }

  runGit(plan.anchorPath, ["worktree", "add", entry.worktreePath, entry.desiredBranch]);
  return "git";
}

function applyEntry(
  planPath: string,
  plan: MigrationPlan,
  entry: MigrationPlanEntry,
  quarantine: boolean,
): string[] {
  const actions: string[] = [];

  const record = (action: string): void => {
    actions.push(action);
    console.log(`[${entry.cloneName}] ${action}`);
  };

  while (true) {
    if (entry.migrationStatus === "planned") {
      verifyOriginalSnapshot(entry);
      if (gitRefExists(plan.anchorPath, `refs/heads/${entry.desiredBranch}`)) {
        throw new Error(`Anchor repo already has local branch ${entry.desiredBranch}`);
      }
      if (fs.existsSync(entry.worktreePath)) {
        throw new Error(`Worktree path already exists: ${entry.worktreePath}`);
      }

      record(`create branch ${entry.desiredBranch} in ${entry.cloneName}`);
      runGit(entry.clonePath, ["switch", "-c", entry.desiredBranch]);
      record(`commit WIP snapshot (${entry.wipCommitMessage})`);
      runGit(entry.clonePath, ["add", "-A"]);
      runGit(entry.clonePath, ["commit", "--no-verify", "-m", entry.wipCommitMessage]);
      entry.sourceCommitSha = getHeadSha(entry.clonePath);
      entry.migrationStatus = "committed";
      entry.lastError = undefined;
      markEntryUpdated(entry);
      savePlan(planPath, plan);
      continue;
    }

    if (entry.migrationStatus === "committed") {
      ensureCommittedState(entry);
      const anchorHasBranch = gitRefExists(plan.anchorPath, `refs/heads/${entry.desiredBranch}`);
      if (!anchorHasBranch) {
        record(`fetch ${entry.desiredBranch} into anchor repo from ${entry.cloneName}`);
        runGit(plan.anchorPath, [
          "fetch",
          "--no-tags",
          entry.clonePath,
          `refs/heads/${entry.desiredBranch}:refs/heads/${entry.desiredBranch}`,
        ]);
      }
      ensureFetchedState(entry, plan.anchorPath);
      entry.migrationStatus = "fetched";
      entry.lastError = undefined;
      markEntryUpdated(entry);
      savePlan(planPath, plan);
      continue;
    }

    if (entry.migrationStatus === "fetched") {
      ensureFetchedState(entry, plan.anchorPath);
      if (!fs.existsSync(entry.worktreePath)) {
        record(`create worktree at ${entry.worktreePath}`);
        fs.mkdirSync(path.dirname(entry.worktreePath), { recursive: true });
        const creationTool = createLinkedWorktree(plan, entry);
        record(`initialized worktree via ${creationTool}`);
        if (maybeTrustMiseWorktree(entry.worktreePath)) {
          record("trusted mise config in new worktree");
        }
      }
      entry.worktreeHeadSha = getHeadSha(entry.worktreePath);
      if (entry.worktreeHeadSha !== entry.sourceCommitSha) {
        throw new Error(
          `Worktree HEAD ${entry.worktreeHeadSha.slice(0, 12)} does not match source commit ${String(entry.sourceCommitSha).slice(0, 12)}`,
        );
      }
      record(`verified worktree HEAD ${entry.worktreeHeadSha.slice(0, 12)}`);
      entry.migrationStatus = "worktree_created";
      entry.lastError = undefined;
      markEntryUpdated(entry);
      savePlan(planPath, plan);
      continue;
    }

    if (entry.migrationStatus === "worktree_created") {
      ensureWorktreeState(entry);
      if (quarantine) {
        if (maybeQuarantineOriginalClone(entry)) {
          record(`quarantined original clone to ${entry.quarantinePath}`);
          savePlan(planPath, plan);
        } else {
          record("original clone already absent; nothing to quarantine");
        }
      }
      return actions;
    }

    if (entry.migrationStatus === "quarantined") {
      ensureWorktreeState(entry);
      record("already quarantined; nothing to do");
      return actions;
    }
  }
}

function applyPlan(planPath: string, plan: MigrationPlan, selectedEntries: MigrationPlanEntry[], quarantine: boolean): void {
  ensureAnchorReadyForApply(plan);

  for (const entry of selectedEntries) {
    console.log(`\n${entry.cloneName} (${entry.migrationStatus})`);
    console.log("-".repeat(entry.cloneName.length + entry.migrationStatus.length + 3));

    try {
      applyEntry(planPath, plan, entry, quarantine);
      savePlan(planPath, plan);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      entry.lastError = message;
      markEntryUpdated(entry);
      savePlan(planPath, plan);
      throw new Error(`${entry.cloneName}: ${message}`);
    }
  }
}

async function main(): Promise<void> {
  const program = new Command();
  program
    .name("migrate-clones-to-worktrees")
    .description(
      "Plan and apply a local migration from multiple dirty clone directories to linked worktrees without pushing WIP branches.",
    )
    .requiredOption("-p, --prefix <prefix>", "Clone prefix under ~/<prefix>_src")
    .option(
      "--clone <name>",
      "Specific dirty clone to include; repeat to target multiple clones",
      collectString,
      [],
    )
    .option(
      "--branch <clone=branch>",
      "Override the suggested branch name for a clone; repeat as needed",
      (value: string, previous: BranchOverride[]) => [...previous, parseBranchOverride(value)],
      [],
    )
    .option("--apply", "Apply the saved migration plan instead of creating one", false)
    .option("--quarantine", "Move successfully migrated original clones into quarantine", false)
    .option(
      "--plan-file <path>",
      "Migration plan JSON path; defaults to ~/<prefix>_src/.<prefix>-worktree-migration-plan.json",
    )
    .option("--anchor-path <path>", "Override the anchor repo path; defaults to ~/<prefix>_src/<prefix>")
    .option(
      "--worktree-root <path>",
      "Root directory where linked worktrees should be created; defaults to the repo's .autowt.toml directory_pattern when present, otherwise ~/<prefix>_worktrees",
    )
    .option(
      "--quarantine-root <path>",
      "Directory where original clones should be moved after verification; defaults to ~/<prefix>_src/_old-clones",
    )
    .option("--openai-api-key <key>", "OpenAI API key")
    .option("--openai-model <model>", "OpenAI model", DEFAULT_SUMMARY_MODEL)
    .option(
      "--summary-concurrency <count>",
      "Max parallel OpenAI branch name requests during planning; defaults to all target clones",
      parsePositiveInt,
    )
    .option(
      "--summary-max-output-tokens <count>",
      "Max OpenAI output tokens per branch name suggestion",
      parsePositiveInt,
      DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS,
    )
    .option(
      "--summary-max-diff-chars <count>",
      "Max diff characters sent to OpenAI per dirty clone while planning",
      parsePositiveInt,
      DEFAULT_SUMMARY_MAX_DIFF_CHARS,
    )
    .showHelpAfterError();

  program.parse();
  const options = program.opts<CliOptions>();

  if (!options.apply) {
    const plan = await createMigrationPlan(options);
    printPlan(plan);
    return;
  }

  const { outerDir } = listCloneEntries(options.prefix);
  const planPath = options.planFile
    ? expandHomePath(options.planFile)
    : defaultPlanFilePath(outerDir, options.prefix);
  const plan = loadPlan(planPath, options.prefix);
  const selectedEntries = selectPlanEntries(plan, options.clone);
  applyPlan(planPath, plan, selectedEntries, options.quarantine);
  console.log(`\nUpdated plan file: ${planPath}`);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});

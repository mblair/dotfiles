import { spawn, spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import process from "node:process";

const MAX_COMMAND_OUTPUT_BYTES = 64 * 1024 * 1024;
const MAX_COMMAND_STDERR_BYTES = 256 * 1024;
const MAX_CAPTURE_BYTES_PER_CHAR = 4;
const COMMAND_OUTPUT_CAPTURE_SLACK_BYTES = 1024;

export interface CloneEntry {
  slot: number;
  name: string;
  clonePath: string;
  dirty: boolean;
  statusOutput: string;
}

interface CommandResult {
  stdout: string;
  stderr: string;
  status: number;
}

interface LimitedCommandResult extends CommandResult {
  truncated: boolean;
}

export interface DiffBundle {
  text: string;
  truncated: boolean;
}

export interface ConflictFileInput {
  relativePath: string;
  baseText?: string;
  oursText?: string;
  theirsText?: string;
  currentText?: string;
}

export interface ConflictResolution {
  action: "write" | "delete";
  content?: string;
}

function formatUsageError(command: string, status: number, stderr: string): Error {
  const trimmedStderr = stderr.trim();
  if (trimmedStderr) {
    return new Error(`${command} exited with status ${status}: ${trimmedStderr}`);
  }
  return new Error(`${command} exited with status ${status}`);
}

function runCommand(
  command: string,
  args: string[],
  cwd: string,
  allowedStatuses: number[] = [0],
): CommandResult {
  const result = spawnSync(command, args, {
    cwd,
    encoding: "utf8",
    maxBuffer: MAX_COMMAND_OUTPUT_BYTES,
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

function runGit(cwd: string, args: string[], allowedStatuses: number[] = [0]): CommandResult {
  return runCommand("git", args, cwd, allowedStatuses);
}

async function runCommandLimited(
  command: string,
  args: string[],
  cwd: string,
  maxChars: number,
  allowedStatuses: number[] = [0],
): Promise<LimitedCommandResult> {
  if (maxChars <= 0) {
    return { stdout: "", stderr: "", status: 0, truncated: true };
  }

  const maxStdoutBytes = Math.max(
    1024,
    Math.min(
      MAX_COMMAND_OUTPUT_BYTES,
      maxChars * MAX_CAPTURE_BYTES_PER_CHAR + COMMAND_OUTPUT_CAPTURE_SLACK_BYTES,
    ),
  );

  return new Promise<LimitedCommandResult>((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      stdio: ["ignore", "pipe", "pipe"],
    });

    const stdoutChunks: Buffer[] = [];
    let stdoutBytes = 0;
    let stdoutTruncated = false;

    const stderrChunks: Buffer[] = [];
    let stderrBytes = 0;

    const stdout = child.stdout;
    const stderr = child.stderr;
    if (!stdout || !stderr) {
      reject(new Error(`Failed to capture ${command} output`));
      return;
    }

    stdout.on("data", (chunk: Buffer) => {
      if (stdoutTruncated) {
        return;
      }

      const remainingBytes = maxStdoutBytes - stdoutBytes;
      if (chunk.length <= remainingBytes) {
        stdoutChunks.push(chunk);
        stdoutBytes += chunk.length;
        return;
      }

      if (remainingBytes > 0) {
        stdoutChunks.push(chunk.subarray(0, remainingBytes));
        stdoutBytes += remainingBytes;
      }
      stdoutTruncated = true;
      child.kill("SIGTERM");
    });

    stderr.on("data", (chunk: Buffer) => {
      if (stderrBytes >= MAX_COMMAND_STDERR_BYTES) {
        return;
      }

      const remainingBytes = MAX_COMMAND_STDERR_BYTES - stderrBytes;
      if (chunk.length <= remainingBytes) {
        stderrChunks.push(chunk);
        stderrBytes += chunk.length;
        return;
      }

      stderrChunks.push(chunk.subarray(0, remainingBytes));
      stderrBytes += remainingBytes;
    });

    child.once("error", (error) => {
      reject(error);
    });

    child.once("close", (code) => {
      const status = code ?? 1;
      const stdoutText = Buffer.concat(stdoutChunks).toString("utf8");
      const stderrText = Buffer.concat(stderrChunks).toString("utf8");
      if (!stdoutTruncated && !allowedStatuses.includes(status)) {
        reject(formatUsageError(`${command} ${args.join(" ")}`, status, stderrText));
        return;
      }

      resolve({
        stdout: stdoutText,
        stderr: stderrText,
        status,
        truncated: stdoutTruncated,
      });
    });
  });
}

function runGitLimited(
  cwd: string,
  args: string[],
  maxChars: number,
  allowedStatuses: number[] = [0],
): Promise<LimitedCommandResult> {
  return runCommandLimited("git", args, cwd, maxChars, allowedStatuses);
}

function readOptionalTextFile(filePath: string): string | undefined {
  if (!fs.existsSync(filePath)) {
    return undefined;
  }

  const buffer = fs.readFileSync(filePath);
  if (buffer.includes(0)) {
    throw new Error(`Refusing to read binary file as text: ${filePath}`);
  }

  return buffer.toString("utf8");
}

function readOptionalGitStageText(
  clonePath: string,
  stage: 1 | 2 | 3,
  relativePath: string,
): string | undefined {
  const result = runGit(clonePath, ["show", `:${stage}:${relativePath}`], [0, 128]);
  if (result.status !== 0) {
    return undefined;
  }
  if (result.stdout.includes("\0")) {
    throw new Error(
      `Refusing to resolve binary conflict as text: ${path.join(clonePath, relativePath)}`,
    );
  }
  return result.stdout;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Unnumbered primary clone, then prefix-2, prefix-3, … (first suffix is always 2). */
function targetNameForSlot(prefix: string, slot: number): string {
  return slot === 0 ? prefix : `${prefix}-${slot + 1}`;
}

/** Map directory name to slot; legacy layout uses prefix-1 for the first extra clone. */
function slotFromDirectoryName(prefix: string, name: string, legacyNumbering: boolean): number | null {
  if (name === prefix) {
    return 0;
  }
  const match = new RegExp(`^${escapeRegExp(prefix)}-(\\d+)$`).exec(name);
  if (!match) {
    return null;
  }
  const n = Number(match[1]);
  if (legacyNumbering) {
    return n;
  }
  if (n === 1) {
    return 1;
  }
  return n - 1;
}

function directoryIsGitWorkTree(clonePath: string): boolean {
  return runGit(clonePath, ["rev-parse", "--is-inside-work-tree"], [0, 128]).status === 0;
}

export function listCloneEntries(prefix: string): { outerDir: string; clones: CloneEntry[] } {
  const outerDir = path.join(os.homedir(), `${prefix}_src`);
  if (!fs.existsSync(outerDir) || !fs.statSync(outerDir).isDirectory()) {
    throw new Error(`Directory does not exist: ${outerDir}`);
  }

  const legacyPath = path.join(outerDir, `${prefix}-1`);
  const legacyNumbering =
    fs.existsSync(legacyPath) &&
    fs.statSync(legacyPath).isDirectory() &&
    directoryIsGitWorkTree(legacyPath);

  const candidates: Array<{ slot: number; name: string; clonePath: string }> = [];
  for (const name of fs.readdirSync(outerDir)) {
    const clonePath = path.join(outerDir, name);
    let stat: fs.Stats;
    try {
      stat = fs.statSync(clonePath);
    } catch {
      continue;
    }
    if (!stat.isDirectory()) {
      continue;
    }

    const slot = slotFromDirectoryName(prefix, name, legacyNumbering);
    if (slot === null) {
      continue;
    }

    candidates.push({ slot, name, clonePath });
  }

  candidates.sort((left, right) => left.slot - right.slot);
  if (candidates.length === 0) {
    throw new Error(`No clone directories matched ${outerDir}/${prefix}{,-*}`);
  }

  const clones: CloneEntry[] = [];
  for (const candidate of candidates) {
    if (!directoryIsGitWorkTree(candidate.clonePath)) {
      console.error(`Skipping non-git directory: ${candidate.clonePath}`);
      continue;
    }

    const statusOutput = runGit(candidate.clonePath, [
      "status",
      "--porcelain",
      "--untracked-files=normal",
    ]).stdout.trimEnd();

    clones.push({
      slot: candidate.slot,
      name: candidate.name,
      clonePath: candidate.clonePath,
      dirty: statusOutput.length > 0,
      statusOutput,
    });
  }

  if (clones.length === 0) {
    throw new Error(`No git clone directories found for ${outerDir}/${prefix}{,-*}`);
  }

  return { outerDir, clones };
}

export function buildDesiredOrder(clones: CloneEntry[]): CloneEntry[] {
  const clean = clones.filter((clone) => !clone.dirty);
  const dirty = clones.filter((clone) => clone.dirty);
  return [...clean, ...dirty];
}

export function needsReorder(current: CloneEntry[], desired: CloneEntry[]): boolean {
  return current.some((clone, index) => clone.name !== desired[index]?.name);
}

/** True when clone directory names are not already consecutive (prefix, prefix-2, …) for the desired order. */
export function needsRenumber(prefix: string, orderedClones: CloneEntry[]): boolean {
  return orderedClones.some((clone, index) => clone.name !== targetNameForSlot(prefix, index));
}

export function preflightRename(prefix: string, outerDir: string, clones: CloneEntry[]): void {
  const sourceNames = new Set(clones.map((clone) => clone.name));
  for (let slot = 0; slot < clones.length; slot += 1) {
    const targetName = targetNameForSlot(prefix, slot);
    const targetPath = path.join(outerDir, targetName);
    if (fs.existsSync(targetPath) && !sourceNames.has(targetName)) {
      throw new Error(`Refusing to overwrite existing path: ${targetPath}`);
    }
  }
}

export function reorderClones(prefix: string, outerDir: string, orderedClones: CloneEntry[]): void {
  const tempNames: string[] = [];

  for (let slot = 0; slot < orderedClones.length; slot += 1) {
    const clone = orderedClones[slot]!;
    const tempName = `.${prefix}.reorder.${process.pid}.${slot}`;
    const tempPath = path.join(outerDir, tempName);
    if (fs.existsSync(tempPath)) {
      throw new Error(`Temporary path already exists: ${tempPath}`);
    }
    fs.renameSync(clone.clonePath, tempPath);
    tempNames.push(tempName);
  }

  for (let slot = 0; slot < orderedClones.length; slot += 1) {
    const tempPath = path.join(outerDir, tempNames[slot]!);
    const targetPath = path.join(outerDir, targetNameForSlot(prefix, slot));
    if (fs.existsSync(targetPath)) {
      // All real clones were moved to temp names above, so anything at
      // the target path was recreated by a background process (IDE, file
      // watcher, Spotlight, etc.).  Remove it so the rename succeeds.
      fs.rmSync(targetPath, { recursive: true });
    }
    fs.renameSync(tempPath, targetPath);
  }
}

function listUntrackedFiles(clonePath: string): string[] {
  const output = runGit(clonePath, ["ls-files", "--others", "--exclude-standard", "-z"]).stdout;
  return output.split("\0").filter((entry) => entry.length > 0);
}

export function listUnmergedFiles(clonePath: string): string[] {
  const output = runGit(clonePath, ["diff", "--name-only", "--diff-filter=U"]).stdout.trim();
  if (!output) {
    return [];
  }
  return output.split("\n").filter((entry) => entry.length > 0);
}

export function getConflictFileInputs(clonePath: string): ConflictFileInput[] {
  return listUnmergedFiles(clonePath).map((relativePath) => ({
    relativePath,
    baseText: readOptionalGitStageText(clonePath, 1, relativePath),
    oursText: readOptionalGitStageText(clonePath, 2, relativePath),
    theirsText: readOptionalGitStageText(clonePath, 3, relativePath),
    currentText: readOptionalTextFile(path.join(clonePath, relativePath)),
  }));
}

export function applyConflictResolution(
  clonePath: string,
  relativePath: string,
  resolution: ConflictResolution,
): void {
  const absolutePath = path.join(clonePath, relativePath);
  if (resolution.action === "delete") {
    fs.rmSync(absolutePath, { force: true });
  } else {
    fs.mkdirSync(path.dirname(absolutePath), { recursive: true });
    fs.writeFileSync(absolutePath, resolution.content ?? "", "utf8");
  }

  runGit(clonePath, ["add", "--", relativePath]);
  runGit(clonePath, ["reset", "HEAD", "--", relativePath]);
}

function truncateSections(sections: string[], maxChars: number): DiffBundle {
  if (maxChars <= 0) {
    return { text: "[diff omitted by configuration]", truncated: true };
  }

  const parts: string[] = [];
  let used = 0;
  let truncated = false;
  let omittedSections = 0;

  for (let index = 0; index < sections.length; index += 1) {
    const prefix = parts.length === 0 ? "" : "\n\n";
    const section = sections[index]!;
    const candidateLength = prefix.length + section.length;
    if (used + candidateLength <= maxChars) {
      parts.push(`${prefix}${section}`);
      used += candidateLength;
      continue;
    }

    truncated = true;
    omittedSections = sections.length - index - 1;
    const remaining = maxChars - used - prefix.length;
    if (remaining > 80) {
      const visibleLength = Math.max(0, remaining - 32);
      parts.push(`${prefix}${section.slice(0, visibleLength)}\n...[truncated]`);
    }
    break;
  }

  if (truncated) {
    parts.push(`\n\n[diff truncated to ${maxChars} chars; omitted_sections=${omittedSections}]`);
  }

  return { text: parts.join(""), truncated };
}

function withSectionTruncationNote(text: string, truncated: boolean): string {
  if (!truncated) {
    return text;
  }
  const prefix = text.length === 0 ? "" : "\n";
  return `${text}${prefix}...[section output truncated]`;
}

export async function buildDiffBundle(clone: CloneEntry, maxChars: number): Promise<DiffBundle> {
  const sections: string[] = [];
  let anySectionTruncated = false;
  const statusBlock = clone.statusOutput || "(empty)";
  sections.push(`[git status --short]\n${statusBlock}`);

  const stagedDiff = await runGitLimited(
    clone.clonePath,
    [
      "diff",
      "--cached",
      "--no-ext-diff",
      "--binary",
      "--submodule=diff",
    ],
    maxChars,
  );
  const stagedText = withSectionTruncationNote(stagedDiff.stdout.trimEnd(), stagedDiff.truncated);
  anySectionTruncated ||= stagedDiff.truncated;
  if (stagedText) {
    sections.push(`[git diff --cached]\n${stagedText}`);
  }

  let bundle = truncateSections(sections, maxChars);
  if (bundle.truncated) {
    return { text: bundle.text, truncated: true };
  }

  const unstagedDiff = await runGitLimited(
    clone.clonePath,
    [
      "diff",
      "--no-ext-diff",
      "--binary",
      "--submodule=diff",
    ],
    maxChars,
  );
  const unstagedText = withSectionTruncationNote(unstagedDiff.stdout.trimEnd(), unstagedDiff.truncated);
  anySectionTruncated ||= unstagedDiff.truncated;
  if (unstagedText) {
    sections.push(`[git diff]\n${unstagedText}`);
  }

  bundle = truncateSections(sections, maxChars);
  if (bundle.truncated) {
    return { text: bundle.text, truncated: true };
  }

  for (const relativePath of listUntrackedFiles(clone.clonePath)) {
    const patch = await runGitLimited(
      clone.clonePath,
      ["diff", "--no-index", "--binary", "--", "/dev/null", relativePath],
      maxChars,
      [0, 1],
    );
    const patchText = withSectionTruncationNote(patch.stdout.trimEnd(), patch.truncated);
    anySectionTruncated ||= patch.truncated;
    if (patchText) {
      sections.push(`[untracked ${relativePath}]\n${patchText}`);
    } else {
      sections.push(`[untracked ${relativePath}]\n(binary or empty file)`);
    }

    bundle = truncateSections(sections, maxChars);
    if (bundle.truncated) {
      return { text: bundle.text, truncated: true };
    }
  }

  bundle = truncateSections(sections, maxChars);
  return { text: bundle.text, truncated: bundle.truncated || anySectionTruncated };
}

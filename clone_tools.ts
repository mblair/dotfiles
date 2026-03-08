import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import process from "node:process";

const MAX_COMMAND_OUTPUT_BYTES = 64 * 1024 * 1024;

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

export interface DiffBundle {
  text: string;
  truncated: boolean;
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

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function targetNameForSlot(prefix: string, slot: number): string {
  return slot === 0 ? prefix : `${prefix}-${slot}`;
}

export function listCloneEntries(prefix: string): { outerDir: string; clones: CloneEntry[] } {
  const outerDir = path.join(os.homedir(), `${prefix}_src`);
  if (!fs.existsSync(outerDir) || !fs.statSync(outerDir).isDirectory()) {
    throw new Error(`Directory does not exist: ${outerDir}`);
  }

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

    if (name === prefix) {
      candidates.push({ slot: 0, name, clonePath });
      continue;
    }

    const match = new RegExp(`^${escapeRegExp(prefix)}-(\\d+)$`).exec(name);
    if (!match) {
      continue;
    }

    candidates.push({ slot: Number(match[1]), name, clonePath });
  }

  candidates.sort((left, right) => left.slot - right.slot);
  if (candidates.length === 0) {
    throw new Error(`No clone directories matched ${outerDir}/${prefix}{,-*}`);
  }

  const clones: CloneEntry[] = [];
  for (const candidate of candidates) {
    const gitCheck = runGit(candidate.clonePath, ["rev-parse", "--is-inside-work-tree"], [0, 128]);
    if (gitCheck.status !== 0) {
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
    fs.renameSync(tempPath, targetPath);
  }
}

function listUntrackedFiles(clonePath: string): string[] {
  const output = runGit(clonePath, ["ls-files", "--others", "--exclude-standard", "-z"]).stdout;
  return output.split("\0").filter((entry) => entry.length > 0);
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

export function buildDiffBundle(clone: CloneEntry, maxChars: number): DiffBundle {
  const sections: string[] = [];
  const statusBlock = clone.statusOutput || "(empty)";
  sections.push(`[git status --short]\n${statusBlock}`);

  const stagedDiff = runGit(clone.clonePath, [
    "diff",
    "--cached",
    "--no-ext-diff",
    "--binary",
    "--submodule=diff",
  ]).stdout.trimEnd();
  if (stagedDiff) {
    sections.push(`[git diff --cached]\n${stagedDiff}`);
  }

  const unstagedDiff = runGit(clone.clonePath, [
    "diff",
    "--no-ext-diff",
    "--binary",
    "--submodule=diff",
  ]).stdout.trimEnd();
  if (unstagedDiff) {
    sections.push(`[git diff]\n${unstagedDiff}`);
  }

  for (const relativePath of listUntrackedFiles(clone.clonePath)) {
    const patch = runGit(
      clone.clonePath,
      ["diff", "--no-index", "--binary", "--", "/dev/null", relativePath],
      [0, 1],
    ).stdout.trimEnd();
    if (patch) {
      sections.push(`[untracked ${relativePath}]\n${patch}`);
    } else {
      sections.push(`[untracked ${relativePath}]\n(binary or empty file)`);
    }
  }

  return truncateSections(sections, maxChars);
}

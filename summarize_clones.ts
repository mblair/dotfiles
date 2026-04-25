import process from "node:process";

import { Command, InvalidArgumentError } from "commander";
import OpenAI from "openai";

import {
  DEFAULT_SUMMARY_MAX_DIFF_CHARS,
  DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS,
  DEFAULT_SUMMARY_MODEL,
  suggestBranchNameForClone,
} from "./clone_branch_names.js";
import { listCloneEntries, type CloneEntry } from "./clone_tools.js";

interface CliOptions {
  prefix: string;
  openaiApiKey?: string;
  openaiModel: string;
  summaryConcurrency?: number;
  summaryMaxOutputTokens: number;
  summaryMaxDiffChars: number;
}

function parsePositiveInt(value: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new InvalidArgumentError(`Expected a positive integer, got ${value}`);
  }
  return parsed;
}

async function summarizeClone(
  client: OpenAI,
  clone: CloneEntry,
  options: CliOptions,
): Promise<{ name: string; branchName: string; truncated: boolean }> {
  const suggestion = await suggestBranchNameForClone(client, clone, {
    openaiModel: options.openaiModel,
    summaryMaxOutputTokens: options.summaryMaxOutputTokens,
    summaryMaxDiffChars: options.summaryMaxDiffChars,
  });

  return {
    name: clone.name,
    branchName: suggestion.branchName,
    truncated: suggestion.truncated,
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

function effectiveConcurrency(requested: number | undefined, itemCount: number): number {
  if (itemCount <= 0) {
    return 1;
  }
  if (requested == null) {
    return itemCount;
  }
  return Math.max(1, Math.min(requested, itemCount));
}

async function main(): Promise<void> {
  const program = new Command();
  program
    .name("summarize-clones")
    .description(
      "Suggest branch names for dirty monorepo clone directories by shipping tracked and untracked diffs to OpenAI.",
    )
    .requiredOption("-p, --prefix <prefix>", "Clone prefix under ~/<prefix>_src")
    .option("--openai-api-key <key>", "OpenAI API key")
    .option("--openai-model <model>", "OpenAI model", DEFAULT_SUMMARY_MODEL)
    .option(
      "--summary-concurrency <count>",
      "Max parallel OpenAI branch name requests; defaults to all dirty clones",
      parsePositiveInt,
    )
    .option(
      "--summary-max-output-tokens <count>",
      "Max OpenAI output tokens per dirty clone branch name",
      parsePositiveInt,
      DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS,
    )
    .option(
      "--summary-max-diff-chars <count>",
      "Max diff characters sent to OpenAI per dirty clone",
      parsePositiveInt,
      DEFAULT_SUMMARY_MAX_DIFF_CHARS,
    )
    .showHelpAfterError();

  program.parse();
  const options = program.opts<CliOptions>();

  const apiKey = options.openaiApiKey || process.env.OPENAI_API_KEY || "";
  if (!apiKey) {
    throw new Error("OpenAI API key missing. Set OPENAI_API_KEY or pass --openai-api-key.");
  }

  const { clones } = listCloneEntries(options.prefix);
  const dirtyClones = clones.filter((clone) => clone.dirty);
  if (dirtyClones.length === 0) {
    console.log(`All ${clones.length} clones are clean. No dirty clones to name.`);
    return;
  }

  const concurrency = effectiveConcurrency(options.summaryConcurrency, dirtyClones.length);

  console.log(
    `Suggesting branch names for ${dirtyClones.length} dirty clone(s) with ${options.openaiModel} (${concurrency} request(s) in flight)...`,
  );

  const client = new OpenAI({ apiKey });
  const suggestions = await mapWithConcurrency(dirtyClones, concurrency, (clone) =>
    summarizeClone(client, clone, options),
  );

  console.log("Suggested branch names:");
  for (const suggestion of suggestions) {
    const truncationNote = suggestion.truncated ? " [diff truncated]" : "";
    const heading = `${suggestion.name}${truncationNote}`;
    console.log(`\n${heading}`);
    console.log("-".repeat(heading.length));
    console.log(suggestion.branchName);
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});

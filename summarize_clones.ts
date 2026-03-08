import process from "node:process";

import { Command, InvalidArgumentError } from "commander";
import OpenAI from "openai";

import { buildDiffBundle, listCloneEntries, type CloneEntry } from "./clone_tools.js";

const DEFAULT_SUMMARY_MODEL = "gpt-5.4";
const DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS = 200;
const DEFAULT_SUMMARY_MAX_DIFF_CHARS = 100_000;

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

async function summarizeClone(
  client: OpenAI,
  clone: CloneEntry,
  options: CliOptions,
): Promise<{ name: string; summary: string; truncated: boolean }> {
  const diffBundle = buildDiffBundle(clone, options.summaryMaxDiffChars);
  const input = [
    {
      role: "system" as const,
      content: [
        {
          type: "input_text" as const,
          text: "You are a senior engineer summarizing dirty git worktrees. Use only the provided git status and diff. Return 1-2 sentences in plain text, focus on likely intent and touched areas, and say when the evidence looks exploratory or uncertain.",
        },
      ],
    },
    {
      role: "user" as const,
      content: [
        {
          type: "input_text" as const,
          text:
            `Clone: ${clone.name}\nPath: ${clone.clonePath}\n` +
            "Summarize what these changes represent for someone triaging dirty clones. Mention the main subsystem or file themes when useful, but stay concise.\n\n" +
            diffBundle.text,
        },
      ],
    },
  ];

  const first = await client.responses.create({
    model: options.openaiModel,
    input,
    max_output_tokens: options.summaryMaxOutputTokens,
  });

  let summary = extractResponseText(first);
  if (!summary) {
    const second = await client.responses.create({
      model: options.openaiModel,
      input,
      max_output_tokens: Math.max(512, options.summaryMaxOutputTokens * 2),
    });
    summary = extractResponseText(second);
  }

  if (!summary) {
    throw new Error(`OpenAI returned no text for ${clone.name}`);
  }

  return {
    name: clone.name,
    summary: summary.replace(/\s+/g, " ").trim(),
    truncated: diffBundle.truncated,
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
      "Summarize dirty monorepo clone directories by shipping tracked and untracked diffs to OpenAI.",
    )
    .requiredOption("-p, --prefix <prefix>", "Clone prefix under ~/<prefix>_src")
    .option("--openai-api-key <key>", "OpenAI API key")
    .option("--openai-model <model>", "OpenAI model", DEFAULT_SUMMARY_MODEL)
    .option(
      "--summary-concurrency <count>",
      "Max parallel OpenAI summary requests; defaults to all dirty clones",
      parsePositiveInt,
    )
    .option(
      "--summary-max-output-tokens <count>",
      "Max OpenAI output tokens per dirty clone summary",
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
    console.log(`All ${clones.length} clones are clean. No dirty clones to summarize.`);
    return;
  }

  const concurrency = effectiveConcurrency(options.summaryConcurrency, dirtyClones.length);

  console.log(
    `Summarizing ${dirtyClones.length} dirty clone(s) with ${options.openaiModel} (${concurrency} request(s) in flight)...`,
  );

  const client = new OpenAI({ apiKey });
  const summaries = await mapWithConcurrency(dirtyClones, concurrency, (clone) =>
    summarizeClone(client, clone, options),
  );

  console.log("Dirty clone summaries:");
  for (const summary of summaries) {
    const truncationNote = summary.truncated ? " [diff truncated]" : "";
    const heading = `${summary.name}${truncationNote}`;
    console.log(`\n${heading}`);
    console.log("-".repeat(heading.length));
    console.log(summary.summary);
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});

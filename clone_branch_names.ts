import OpenAI from "openai";

import { buildDiffBundle, type CloneEntry } from "./clone_tools.js";

export const DEFAULT_SUMMARY_MODEL = "gpt-5.4";
export const DEFAULT_SUMMARY_MAX_OUTPUT_TOKENS = 64;
export const DEFAULT_SUMMARY_MAX_DIFF_CHARS = 100_000;
export const BRANCH_PREFIX = "mattyblair/";
export const DEFAULT_BRANCH_SLUG = "misc-change";
const MAX_BRANCH_SLUG_LENGTH = 72;

export interface BranchNamingOptions {
  openaiModel: string;
  summaryMaxOutputTokens: number;
  summaryMaxDiffChars: number;
}

export interface BranchSuggestion {
  branchName: string;
  truncated: boolean;
}

export async function suggestBranchNameForClone(
  client: OpenAI,
  clone: CloneEntry,
  options: BranchNamingOptions,
): Promise<BranchSuggestion> {
  const diffBundle = await buildDiffBundle(clone, options.summaryMaxDiffChars);
  const input = [
    {
      role: "system" as const,
      content: [
        {
          type: "input_text" as const,
          text:
            "You are a senior engineer naming git branches for dirty worktrees. Use only the provided git status and diff. Return exactly one plain-text git branch name that starts with mattyblair/. Use lowercase kebab-case, keep it concise and specific, and do not include any explanation or punctuation outside the branch name.",
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
            "Suggest a git branch name for these changes. Prefer 3-7 words after mattyblair/. If the intent is uncertain, choose a cautious generic slug based on the touched area. Return only the branch name.\n\n" +
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

  let branchName = extractResponseText(first);
  if (!branchName) {
    const second = await client.responses.create({
      model: options.openaiModel,
      input,
      max_output_tokens: Math.max(128, options.summaryMaxOutputTokens * 2),
    });
    branchName = extractResponseText(second);
  }

  if (!branchName) {
    throw new Error(`OpenAI returned no text for ${clone.name}`);
  }

  return {
    branchName: normalizeBranchName(branchName),
    truncated: diffBundle.truncated,
  };
}

export function normalizeBranchName(raw: string): string {
  const prefixedMatch = raw.match(/mattyblair\/[A-Za-z0-9._/-]+/i);
  const firstLine = raw.split(/\r?\n/, 1)[0]?.trim() ?? "";
  const candidate = (
    prefixedMatch?.[0] ||
    firstLine
      .replace(/^suggested\s+branch(?:\s+name)?\s*:\s*/i, "")
      .replace(/^branch(?:\s+name)?\s*:\s*/i, "")
      .replace(/[`"'“”‘’]/g, "")
      .trim()
  )
    .replace(/^mattyblair\//i, "")
    .toLowerCase();

  const sanitized = candidate
    .replace(/[^a-z0-9/._-]+/g, "-")
    .replace(/\/{2,}/g, "/")
    .replace(/\.{2,}/g, ".")
    .replace(/@{/g, "-")
    .replace(/(^|\/)[._-]+/g, "$1")
    .replace(/[._-]+(?=\/|$)/g, "")
    .replace(/^\/+|\/+$/g, "");

  const truncated = sanitized
    .slice(0, MAX_BRANCH_SLUG_LENGTH)
    .replace(/[._/-]+$/g, "")
    .trim();

  return `${BRANCH_PREFIX}${truncated || DEFAULT_BRANCH_SLUG}`;
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

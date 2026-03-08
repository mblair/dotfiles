import process from "node:process";

import { Command } from "commander";

import {
  buildDesiredOrder,
  listCloneEntries,
  needsReorder,
  preflightRename,
  reorderClones,
} from "./clone_tools.js";

interface CliOptions {
  prefix: string;
}

async function main(): Promise<void> {
  const program = new Command();
  program
    .name("reorder")
    .description(
      "Reorder monorepo clone directories so clean clones come first and dirty clones move to the end.",
    )
    .requiredOption("-p, --prefix <prefix>", "Clone prefix under ~/<prefix>_src")
    .showHelpAfterError();

  program.parse();
  const options = program.opts<CliOptions>();

  const { outerDir, clones } = listCloneEntries(options.prefix);
  const dirtyCount = clones.filter((clone) => clone.dirty).length;
  const cleanCount = clones.length - dirtyCount;

  if (dirtyCount === 0) {
    console.log(`All ${clones.length} clones are clean. No reordering needed.`);
    return;
  }

  const desiredOrder = buildDesiredOrder(clones);
  if (!needsReorder(clones, desiredOrder)) {
    console.log(`Dirty clones are already at the end (${dirtyCount} dirty). No reordering needed.`);
    return;
  }

  preflightRename(options.prefix, outerDir, clones);
  console.log(`Found ${clones.length} clone(s): ${cleanCount} clean, ${dirtyCount} dirty`);
  reorderClones(options.prefix, outerDir, desiredOrder);
  console.log(`Reordered clones under ${outerDir}`);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});

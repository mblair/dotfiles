import process from "node:process";

import { Command } from "commander";

import {
  buildDesiredOrder,
  listCloneEntries,
  needsRenumber,
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

  const desiredOrder = buildDesiredOrder(clones);
  const reorderNeeded = needsReorder(clones, desiredOrder);
  const renumberNeeded = needsRenumber(options.prefix, desiredOrder);

  if (!reorderNeeded && !renumberNeeded) {
    if (dirtyCount === 0) {
      console.log(`All ${clones.length} clones are clean. No reordering needed.`);
    } else {
      console.log(
        `Dirty clones are already at the end (${cleanCount} clean, ${dirtyCount} dirty). No reordering needed.`,
      );
    }
    return;
  }

  preflightRename(options.prefix, outerDir, clones);
  console.log(`Found ${clones.length} clone(s): ${cleanCount} clean, ${dirtyCount} dirty`);
  if (renumberNeeded && !reorderNeeded) {
    console.log(`Renumbering to ${options.prefix}, ${options.prefix}-2, ${options.prefix}-3, …`);
  }
  reorderClones(options.prefix, outerDir, desiredOrder);
  console.log(`Updated clone directories under ${outerDir}`);
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});

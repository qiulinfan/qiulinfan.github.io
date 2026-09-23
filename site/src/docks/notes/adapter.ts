import { execFileSync } from "node:child_process";
import { resolve } from "node:path";
import type { DockAdapter } from "../integration.ts";
import { installNoteArtifacts } from "./scripts/install-artifacts.ts";
import { syncNoteAssets } from "./scripts/sync-assets.ts";

export const notesAdapter: DockAdapter = {
	routes: [
		{ pattern: "/notes", entrypoint: new URL("./pages/index.astro", import.meta.url) },
		{ pattern: "/notes/[...slug]", entrypoint: new URL("./pages/[...slug].astro", import.meta.url) },
	],
	prepare({ root, siteRoot, command, logger }) {
		const synced = syncNoteAssets(root, resolve(siteRoot, "public/_notes-assets"));
		logger.info(`Synced ${synced} note asset(s).`);
		// Standalone Typst pages are built by the notes repository itself.
		if (command === "build") execFileSync("make", ["-C", root, "web"], { stdio: "inherit" });
	},
	finish({ root, outDir, logger }) {
		logger.info(`Installed ${installNoteArtifacts(root, outDir)} published note artifact(s).`);
	},
};

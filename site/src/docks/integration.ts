import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { AstroIntegration, AstroIntegrationLogger, InjectedRoute } from "astro";
import { notesAdapter } from "./notes/adapter.ts";
import { dockRoot, loadDocks } from "./registry.ts";

// An adapter is the display logic for one dock: its pages plus the steps that
// turn the dock checkout at `root` into site content.
export interface DockAdapter {
	routes: InjectedRoute[];
	// Runs before `astro dev` and `astro build`.
	prepare?(context: { root: string; siteRoot: string; command: "dev" | "build"; logger: AstroIntegrationLogger }): void;
	// Runs after `astro build` has written the static site to `outDir`.
	finish?(context: { root: string; outDir: string; logger: AstroIntegrationLogger }): void;
}

const adapters: Record<string, DockAdapter> = {
	notes: notesAdapter,
};

export function docks(): AstroIntegration {
	let homepageRoot = "";
	return {
		name: "ql-docks",
		hooks: {
			"astro:config:setup": ({ config, command, injectRoute, logger }) => {
				const siteRoot = fileURLToPath(config.root);
				homepageRoot = resolve(siteRoot, "..");
				for (const dock of loadDocks(homepageRoot)) {
					const adapter = adapters[dock.id];
					if (!adapter) throw new Error(`The ${dock.id} dock has no adapter in site/src/docks/.`);
					const root = dockRoot(homepageRoot, dock.id);
					for (const route of adapter.routes) injectRoute(route);
					if (command === "dev" || command === "build") {
						adapter.prepare?.({ root, siteRoot, command, logger });
					}
				}
			},
			"astro:build:done": ({ dir, logger }) => {
				const outDir = fileURLToPath(dir);
				const built = loadDocks(homepageRoot).map((dock) => {
					const root = dockRoot(homepageRoot, dock.id);
					adapters[dock.id].finish?.({ root, outDir, logger });
					const commit = execFileSync("git", ["-C", root, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
					return { id: dock.id, repository: dock.repository, commit };
				});
				// Record which commit of each dock this deployment was built from.
				writeFileSync(resolve(outDir, "docks.json"), `${JSON.stringify(built, null, "\t")}\n`);
			},
		},
	};
}

// Clone every dock in docks.json that is not checked out yet. Existing checkouts,
// such as the working copies used for local preview, are left untouched.
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { resolve } from "node:path";
import { loadDocks } from "../src/docks/registry.ts";

const homepageRoot = resolve(import.meta.dirname, "../..");
const docks = loadDocks(homepageRoot);

for (const dock of docks) {
	const checkout = resolve(homepageRoot, dock.checkout);
	if (existsSync(checkout)) {
		console.log(`ready: ${dock.id} -> ${checkout}`);
		continue;
	}
	execFileSync(
		"git",
		[
			"clone",
			"--depth",
			"1",
			"--branch",
			dock.ref,
			"--recurse-submodules",
			"--shallow-submodules",
			`${dock.repository}.git`,
			checkout,
		],
		{ stdio: "inherit" },
	);
}

console.log(`DOCKS_OK (${docks.length})`);

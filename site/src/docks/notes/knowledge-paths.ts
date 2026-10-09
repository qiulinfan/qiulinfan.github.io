import { existsSync } from "node:fs";
import { resolve } from "node:path";

/** The dock may adopt a visible or hidden knowledge tree, never both. */
export function notesKnowledgeRoot(notesRoot: string): string {
	const roots = ["knowledge", ".knowledge"].map((name) => resolve(notesRoot, name));
	const present = roots.filter((root) => existsSync(resolve(root, "sources.json")));
	if (present.length !== 1) {
		throw new Error("Notes must contain exactly one knowledge source registry");
	}
	return present[0];
}

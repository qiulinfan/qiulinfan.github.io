import { lstatSync, mkdirSync, realpathSync, symlinkSync, unlinkSync } from "node:fs";
import { dirname, resolve } from "node:path";
import type { DockAdapter } from "../integration.ts";

// Mount the content checkout without copying articles into the website repository.
// Astro and Vite keep their existing Markdown, asset and live-preview pipeline.
export function mountBlogPosts(root: string, siteRoot: string): void {
	const source = resolve(root, "posts");
	const target = resolve(siteRoot, "src/content/posts");
	const sourcePath = realpathSync(source);
	let existing;
	try {
		existing = lstatSync(target);
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
	}
	if (existing) {
		if (!existing.isSymbolicLink()) {
			throw new Error(`Refusing to replace local blog content at ${target}. Move it to the blogs checkout first.`);
		}
		try {
			if (realpathSync(target) === sourcePath) return;
		} catch (error) {
			if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
		}
		unlinkSync(target);
	}
	mkdirSync(dirname(target), { recursive: true });
	symlinkSync(sourcePath, target, process.platform === "win32" ? "junction" : "dir");
}

export const blogsAdapter: DockAdapter = {
	routes: [],
	setup({ root, siteRoot, logger }) {
		mountBlogPosts(root, siteRoot);
		logger.info("Mounted Markdown from the blogs dock.");
	},
};

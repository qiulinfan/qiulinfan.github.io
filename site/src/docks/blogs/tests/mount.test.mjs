import assert from "node:assert/strict";
import { lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { mountBlogPosts } from "../adapter.ts";

test("the blog mount reads and edits the external source, including through a checkout alias", (t) => {
	const temp = mkdtempSync(join(tmpdir(), "blogs-dock-"));
	t.after(() => rmSync(temp, { recursive: true, force: true }));
	const root = join(temp, "blogs");
	const site = join(temp, "website/site");
	mkdirSync(join(root, "posts"), { recursive: true });
	writeFileSync(join(root, "posts/article.md"), "Original article");
	mountBlogPosts(root, site);
	const mounted = join(site, "src/content/posts");
	assert.equal(realpathSync(mounted), realpathSync(join(root, "posts")));
	assert.equal(readFileSync(join(mounted, "article.md"), "utf8"), "Original article");
	writeFileSync(join(root, "posts/article.md"), "Edited in Obsidian");
	assert.equal(readFileSync(join(mounted, "article.md"), "utf8"), "Edited in Obsidian");
	const alias = join(temp, "blogs-alias");
	symlinkSync(root, alias, process.platform === "win32" ? "junction" : "dir");
	mountBlogPosts(alias, site);
	assert.equal(lstatSync(mounted).isSymbolicLink(), true);
	assert.equal(realpathSync(mounted), realpathSync(join(alias, "posts")));
});

test("mounting refuses to overwrite articles still owned by the website", (t) => {
	const temp = mkdtempSync(join(tmpdir(), "blogs-dock-"));
	t.after(() => rmSync(temp, { recursive: true, force: true }));
	const root = join(temp, "blogs");
	const site = join(temp, "website/site");
	mkdirSync(join(root, "posts"), { recursive: true });
	const local = join(site, "src/content/posts");
	mkdirSync(local, { recursive: true });
	writeFileSync(join(local, "article.md"), "Keep me");
	assert.throws(() => mountBlogPosts(root, site), /Refusing to replace local blog content/);
	assert.equal(readFileSync(join(local, "article.md"), "utf8"), "Keep me");
});

test("changing the checkout replaces only the mount, preserving both content directories", (t) => {
	const temp = mkdtempSync(join(tmpdir(), "blogs-dock-"));
	t.after(() => rmSync(temp, { recursive: true, force: true }));
	const site = join(temp, "website/site");
	for (const name of ["first", "second"]) {
		mkdirSync(join(temp, name, "posts"), { recursive: true });
		writeFileSync(join(temp, name, "posts/article.md"), name);
		mountBlogPosts(join(temp, name), site);
	}
	assert.equal(readFileSync(join(site, "src/content/posts/article.md"), "utf8"), "second");
	assert.equal(readFileSync(join(temp, "first/posts/article.md"), "utf8"), "first");
});

import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import test from "node:test";

const siteRoot = new URL("..", import.meta.url).pathname;
const sourceRoot = join(siteRoot, "src");
const authority = "styles/variables.styl";
const checkedExtensions = new Set([".astro", ".css", ".styl", ".svelte", ".ts"]);

function sourceFiles(directory) {
	return readdirSync(directory).flatMap((name) => {
		const path = join(directory, name);
		return statSync(path).isDirectory() ? sourceFiles(path) : [path];
	});
}

test("the shared theme file is the only palette authority", () => {
	const violations = [];
	for (const path of sourceFiles(sourceRoot)) {
		const extension = path.slice(path.lastIndexOf("."));
		if (!checkedExtensions.has(extension)) continue;
		const name = relative(sourceRoot, path);
		if (name === authority) continue;
		const text = readFileSync(path, "utf8");
		if (/\bthemeColor\b|--hue\b|var\(--hue\)|oklch\(/.test(text)) {
			violations.push(`${name}: legacy hue or local OKLCH palette`);
		}
		if (/#[0-9a-f]{6,8}\b/i.test(text)) {
			violations.push(`${name}: local hexadecimal color`);
		}
	}
	assert.deepEqual(violations, []);
});

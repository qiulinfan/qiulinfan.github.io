import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const siteRoot = fileURLToPath(new URL("..", import.meta.url));
const sourceRoot = join(siteRoot, "src");
const authority = "styles/variables.styl";
const notesThemePath = join(
	siteRoot,
	"..",
	"notes",
	"math",
	"toolchain",
	"web.css",
);
const checkedExtensions = new Set([
	".astro",
	".css",
	".styl",
	".svelte",
	".ts",
]);

function normalizeColor(value) {
	const rgba = /^rgba\(([^)]+)\)$/i.exec(value.trim());
	if (rgba) {
		return `rgba(${rgba[1]
			.split(",")
			.map((part) => Number(part.trim()))
			.join(",")})`;
	}
	return value.trim().toLowerCase();
}

function siteColorPair(source, name) {
	const line = source
		.split("\n")
		.find((candidate) => candidate.trim().startsWith(`${name}:`));
	assert.ok(line, `missing site palette variable ${name}`);
	const colors = line.match(/#[0-9a-f]{6,8}\b|rgba\([^)]+\)/gi) ?? [];
	assert.equal(colors.length, 2, `${name} must define light and dark colors`);
	return colors.map(normalizeColor);
}

function cssBlock(source, selector) {
	const escaped = selector.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const match = new RegExp(`${escaped}\\s*\\{([\\s\\S]*?)\\}`).exec(source);
	assert.ok(match, `missing CSS block ${selector}`);
	return match[1];
}

function cssColor(block, name) {
	const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const match = new RegExp(`${escaped}\\s*:\\s*([^;]+);`).exec(block);
	assert.ok(match, `missing QLNotes variable ${name}`);
	return normalizeColor(match[1]);
}

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
		const name = relative(sourceRoot, path).replaceAll("\\", "/");
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

test("the standalone QLNotes theme follows the site palette", () => {
	const sitePalette = readFileSync(join(sourceRoot, authority), "utf8");
	const notesTheme = readFileSync(notesThemePath, "utf8");
	const light = cssBlock(notesTheme, ":root");
	const dark = cssBlock(notesTheme, ":root.dark");
	const mappings = [
		["--ql-blue", "--primary"],
		["--ql-primary-contrast", "--primary-contrast"],
		["--ql-ink", "--text-strong"],
		["--ql-text", "--text"],
		["--ql-muted", "--text-muted"],
		["--ql-canvas", "--page-bg"],
		["--ql-paper", "--card-bg"],
		["--ql-border", "--border"],
		["--ql-violet", "--violet"],
		["--ql-teal", "--cyan"],
		["--ql-orange", "--yellow"],
		["--ql-code", "--inline-code-color"],
		["--ql-code-soft", "--inline-code-bg"],
	];

	for (const [notesName, siteName] of mappings) {
		const [siteLight, siteDark] = siteColorPair(sitePalette, siteName);
		assert.equal(cssColor(light, notesName), siteLight, `${notesName} light`);
		assert.equal(cssColor(dark, notesName), siteDark, `${notesName} dark`);
	}
});

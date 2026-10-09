import assert from "node:assert/strict";
import test from "node:test";

import {
	buildKnowledgeIndex,
	loadListedNoteSources,
	loadMarkdownNotes,
	renderKnowledgeMarkdown,
} from "../sources.ts";

test("the source registry publishes and lists only the selected notes", () => {
	const listed = loadListedNoteSources();
	assert.deepEqual(listed.map((source) => source.id), [
		"math:a-bit-of-abstract-algebra",
		"cs:cpp-programming",
		"cs:data-structures-algorithms",
		"math:everything-about-linear-algebra",
		"math:measure-theory",
		"math:probability",
		"math:single-and-multivariate-mathematical-analysis",
	]);
	assert.deepEqual(listed.map((source) => source.href), [
		"/notes/math/a-bit-of-abstract-algebra/",
		"/notes/cs/cpp-programming/",
		"/notes/cs/data-structures-algorithms/",
		"/notes/math/everything-about-linear-algebra/",
		"/notes/math/measure-theory/",
		"/notes/math/probability/",
		"/notes/math/single-and-multivariate-mathematical-analysis/",
	]);
	assert.deepEqual(
		listed.map((source) => source.navigationHref.replace(/[a-f0-9]{12}$/, "VERSION")),
		[
			"/notes/math/a-bit-of-abstract-algebra/?v=VERSION",
			"/notes/cs/cpp-programming/",
			"/notes/cs/data-structures-algorithms/",
			"/notes/math/everything-about-linear-algebra/?v=VERSION",
			"/notes/math/measure-theory/?v=VERSION",
			"/notes/math/probability/?v=VERSION",
			"/notes/math/single-and-multivariate-mathematical-analysis/?v=VERSION",
		],
	);
	assert.deepEqual(listed.map((source) => source.standalone), [true, false, false, true, true, true, true]);
	assert.equal(
		loadMarkdownNotes().some((note) => note.sourceId === "cs:computer-organization"),
		false,
	);
	const markdownNotes = loadMarkdownNotes();
	const cppNotes = markdownNotes.filter((note) => note.sourceId === "cs:cpp-programming");
	const dataStructuresNotes = markdownNotes.filter((note) => note.sourceId === "cs:data-structures-algorithms");
	assert.equal(cppNotes.length, 27);
	assert.equal(dataStructuresNotes.length, 4);
	assert.equal(cppNotes.some((note) => note.authority.endsWith("280-midterm-cheatsheet.md")), true);
	assert.equal(dataStructuresNotes.every((note) => note.authority.includes("/docs/")), true);
	assert.equal(markdownNotes.some((note) => /FinalReview|notes-project-optimization|\/README\.md$/.test(note.authority)), false);
	assert.equal(markdownNotes.every((note) => note.heroImage === "/assets/backgrounds/one-dark-sakura-right-v3.webp"), true);
	assert.equal(markdownNotes.every((note) => note.backgroundImage === undefined), true);
	const debuggerNote = loadMarkdownNotes().find((note) => note.authority.endsWith("04-Debuggers.md"));
	assert.match(debuggerNote?.html ?? "", /\/_notes-assets\/cs-cpp-programming\/Assets\/image-20231223020225955\.png/);
	const cppHome = cppNotes.find((note) => note.slug === "cs/cpp-programming");
	assert.doesNotMatch(cppHome?.html ?? "", /<h1\b/);
	assert.equal(cppHome?.headings.every((heading) => heading.depth > 1), true);
	assert.equal(cppHome?.navigation.some((heading) => heading.documentSlug.endsWith("01-Command-Line Interface-(CLI)")), true);
	assert.equal(cppHome?.navigation.some((heading) => heading.documentSlug.endsWith("280-midterm-cheatsheet")), true);
	const dataStructuresHome = dataStructuresNotes.find((note) => note.slug === "cs/data-structures-algorithms");
	assert.equal(dataStructuresHome?.navigation.some((heading) => heading.text === "Lec 24 (Knapsack and Floyd's algorithm)"), true);
	assert.equal(dataStructuresHome?.navigation.some((heading) => heading.documentSlug === dataStructuresHome.slug), false);
});

test("Markdown knowledge markers are anchors and ordinary wikilinks are backlinks", () => {
	const source = [
		"> **Definition: --[[cache line]]--**",
		">",
		"> A [[cache line|line]] is transferred as one unit.",
		"",
		"$$",
		"T = C + M",
		"$$",
		"",
		"```cpp",
		"int main() { return 0; }",
		"```",
		"",
		"See [[write buffer]].",
	].join("\n");
	const index = buildKnowledgeIndex([{ source, address: "https://example.test/notes/cache" }]);

	assert.deepEqual([...index.definitions], [["cache line", { id: "cache-line", href: "https://example.test/notes/cache/#kn-cache-line" }]]);

	const rendered = renderKnowledgeMarkdown(source, index);

	assert.match(rendered.html, /<strong id="kn-cache-line"[^>]*>cache line<\/strong>/);
	assert.doesNotMatch(rendered.html, /<a[^>]+id="kn-cache-line"/);
	assert.match(rendered.html, /<a class="ql-ref"[^>]+href="https:\/\/example\.test\/notes\/cache\/#kn-cache-line">line<\/a>/);
	assert.match(rendered.html, /<span class="ql-ref ql-unresolved" title="未找到对应定义">write buffer<\/span>/);
	assert.match(rendered.html, /class="katex-display"/);
	assert.match(rendered.html, /class="ql-code-block" data-language="cpp"/);
	assert.match(rendered.html, /--shiki-dark:/);
});

test("Markdown references resolve to the notes registry's Typst and LaTeX anchors by identity key", () => {
	const measure = "https://example.test/notes/math/measure/#kn-";
	const registry = [
		{ names: ["measure space"], id: "measure-space", url: `${measure}measure-space` },
		{ names: ["$σ$-finite measure", "σ-finite measure"], id: "sigma-finite-measure", url: `${measure}sigma-finite-measure` },
		{ names: ["Measure"], id: "measure-a", url: `${measure}measure-a` },
		{ names: ["MEASURE"], id: "measure-b", url: `${measure}measure-b` },
	];
	const source = [
		"A [[measure space]] is a [[Measure  Space|triple]]; see [[Σ-FINITE measure]].",
		"",
		"Unknown: [[outer measure]], [[measure-space]], [[measure]].",
	].join("\n");
	const index = buildKnowledgeIndex([{ source, address: "https://example.test/notes/cs/demo" }], registry);
	const { html } = renderKnowledgeMarkdown(source, index);

	assert.equal(index.definitions.size, 0);
	assert.match(html, /<a class="ql-ref" data-ql-ref="measure-space" href="https:\/\/example\.test\/notes\/math\/measure\/#kn-measure-space">measure space<\/a>/);
	assert.match(html, /<a class="ql-ref" data-ql-ref="measure-space" href="[^"]+#kn-measure-space">triple<\/a>/);
	assert.match(html, /<a class="ql-ref" data-ql-ref="sigma-finite-measure" href="[^"]+#kn-sigma-finite-measure">Σ-FINITE measure<\/a>/);
	for (const unresolved of ["outer measure", "measure-space", "measure"]) {
		assert.match(html, new RegExp(`<span class="ql-ref ql-unresolved" title="未找到对应定义">${unresolved}</span>`));
	}
	assert.doesNotMatch(html, /id="kn-/);
});

test("knowledge definitions must be unique and produce an anchor id", () => {
	assert.throws(
		() => buildKnowledgeIndex([
			{ source: "--[[cache line]]--", address: "https://example.test/notes/a" },
			{ source: "--[[cache line]]--", address: "https://example.test/notes/b" },
		]),
		/defined more than once/,
	);
	assert.throws(
		() => buildKnowledgeIndex(
			[{ source: "--[[measure space]]--", address: "https://example.test/notes/a" }],
			[{ names: ["measure space"], id: "measure-space", url: "https://example.test/notes/math/measure/#kn-measure-space" }],
		),
		/defined more than once/,
	);
	assert.throws(
		() => buildKnowledgeIndex([{ source: "--[[缓存]]--", address: "https://example.test/notes/a" }]),
		/no usable id/,
	);
});

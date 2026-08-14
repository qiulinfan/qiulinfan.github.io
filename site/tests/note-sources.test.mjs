import assert from "node:assert/strict";
import test from "node:test";

import {
	loadListedNoteSources,
	loadMarkdownNotes,
	renderKnowledgeMarkdown,
} from "../src/utils/note-sources.ts";

test("the source registry publishes and lists only the selected notes", () => {
	const listed = loadListedNoteSources();
	assert.deepEqual(listed.map((source) => source.id), [
		"cs:cpp-programming",
		"cs:data-structures-algorithms",
		"math:measure-theory",
		"math:probability",
	]);
	assert.deepEqual(listed.map((source) => source.href), [
		"/notes/cs/cpp-programming/",
		"/notes/cs/data-structures-algorithms/",
		"/notes/math/measure-theory/",
		"/notes/math/probability/",
	]);
	assert.deepEqual(
		listed.map((source) => source.navigationHref.replace(/[a-f0-9]{12}$/, "VERSION")),
		[
			"/notes/cs/cpp-programming/",
			"/notes/cs/data-structures-algorithms/",
			"/notes/math/measure-theory/?v=VERSION",
			"/notes/math/probability/?v=VERSION",
		],
	);
	assert.deepEqual(listed.map((source) => source.standalone), [false, false, true, true]);
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
	assert.equal(cppHome?.navigation.some((heading) => heading.documentSlug.endsWith("01-Command-Line Interface-(CLI)")), true);
	assert.equal(cppHome?.navigation.some((heading) => heading.documentSlug.endsWith("280-midterm-cheatsheet")), true);
	const dataStructuresHome = dataStructuresNotes.find((note) => note.slug === "cs/data-structures-algorithms");
	assert.equal(dataStructuresHome?.navigation.some((heading) => heading.text === "Lec 24 (Knapsack and Floyd's algorithm)"), true);
	assert.equal(dataStructuresHome?.navigation.some((heading) => heading.documentSlug === dataStructuresHome.slug), false);
});

test("Markdown authority markers are anchors and ordinary wikilinks are backlinks", () => {
	const authority = "notes/cs/demo/cache.md";
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
	].join("\n");
	const nodes = [{
		id: "cache-line",
		label: "cache line",
		properties: { source_name: "cache line" },
		provenance: {
			authority,
			line: 1,
			web: "https://example.test/notes/cache/#kn-cache-line",
		},
	}];
	const references = [{
		target: "cache-line",
		authority,
		line: 3,
		source_name: "cache line",
		display_markup: "line",
	}];

	const rendered = renderKnowledgeMarkdown(source, authority, nodes, references);

	assert.match(rendered.html, /<strong id="kn-cache-line"[^>]*>cache line<\/strong>/);
	assert.doesNotMatch(rendered.html, /<a[^>]+id="kn-cache-line"/);
	assert.match(rendered.html, /<a class="ql-ref"[^>]+href="https:\/\/example\.test\/notes\/cache\/#kn-cache-line">line<\/a>/);
	assert.match(rendered.html, /class="katex-display"/);
	assert.match(rendered.html, /class="ql-code-block" data-language="cpp"/);
	assert.match(rendered.html, /--shiki-dark:/);
});

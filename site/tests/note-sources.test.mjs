import assert from "node:assert/strict";
import test from "node:test";

import {
	loadListedNoteSources,
	loadMarkdownNotes,
	renderKnowledgeMarkdown,
} from "../src/utils/note-sources.ts";
import { GET as getPublicGraph } from "../src/pages/knowledge/graph.json.ts";

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
	assert.equal(loadMarkdownNotes().filter((note) => note.sourceId === "cs:cpp-programming").length, 27);
	assert.equal(loadMarkdownNotes().filter((note) => note.sourceId === "cs:data-structures-algorithms").length, 7);
	const debuggerNote = loadMarkdownNotes().find((note) => note.authority.endsWith("04-Debuggers.md"));
	assert.match(debuggerNote?.html ?? "", /\/_notes-assets\/cs-cpp-programming\/Assets\/image-20231223020225955\.png/);
	const finalReview = loadMarkdownNotes().find((note) => note.authority.endsWith("data-structures-algorithms/FinalReview.md"));
	assert.match(finalReview?.html ?? "", /\/_notes-assets\/cs-data-structures-algorithms\/docs\/note-assets\//);
	const dataStructuresHome = loadMarkdownNotes().find((note) => note.authority.endsWith("data-structures-algorithms/README.md"));
	assert.match(dataStructuresHome?.html ?? "", /href="\/notes\/cs\/data-structures-algorithms\/docs\/"/);
	assert.match(dataStructuresHome?.html ?? "", /href="\/notes\/cs\/data-structures-algorithms\/FinalReview\/"/);
});

test("the public graph excludes unpublished sources without changing the local graph", async () => {
	const response = getPublicGraph();
	const graph = await response.json();
	const ids = new Set(graph.nodes.map((node) => node.id));
	assert.equal(ids.has("cpp-programming"), true);
	assert.equal(ids.has("programming-languages"), true);
	assert.equal(ids.has("data-structures-algorithms"), true);
	assert.equal(ids.has("data-structures-and-algorithms"), true);
	assert.equal(ids.has("computer-organization"), false);
	assert.equal(ids.has("computer-architecture"), false);
	assert.equal("source_hashes" in graph.manifest, false);
	assert.equal("entry_store" in graph.manifest, false);
	assert.equal(graph.manifest.counts.nodes, graph.nodes.length);
	assert.equal(graph.manifest.counts.edges, graph.edges.length);
	assert.equal(graph.manifest.counts.references, graph.references.length);
	assert.equal(
		graph.edges.every((edge) => ids.has(edge.source) && ids.has(edge.target)),
		true,
	);
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
});

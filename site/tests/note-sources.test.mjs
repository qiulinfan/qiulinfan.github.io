import assert from "node:assert/strict";
import test from "node:test";

import {
	loadListedNoteSources,
	loadMarkdownNotes,
	renderKnowledgeMarkdown,
} from "../src/utils/note-sources.ts";
import { GET as getPublicGraph } from "../src/pages/knowledge/graph.json.ts";

test("the source registry publishes and lists only the selected math notes", () => {
	const listed = loadListedNoteSources();
	assert.deepEqual(listed.map((source) => source.id), ["math:measure-theory", "math:probability"]);
	assert.deepEqual(listed.map((source) => source.href), [
		"/notes/math/measure-theory/",
		"/notes/math/probability/",
	]);
	assert.deepEqual(listed.map((source) => source.standalone), [true, true]);
	assert.equal(
		loadMarkdownNotes().some((note) => note.sourceId === "cs:computer-organization"),
		false,
	);
});

test("the public graph excludes unpublished sources without changing the local graph", async () => {
	const response = getPublicGraph();
	const graph = await response.json();
	const ids = new Set(graph.nodes.map((node) => node.id));
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

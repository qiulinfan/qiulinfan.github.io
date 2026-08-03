import assert from "node:assert/strict";
import test from "node:test";

import { renderKnowledgeMarkdown } from "../src/utils/note-sources.ts";

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

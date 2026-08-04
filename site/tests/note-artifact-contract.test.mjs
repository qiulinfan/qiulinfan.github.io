import assert from "node:assert/strict";
import test from "node:test";

import { prepareStandaloneHtml } from "../scripts/install-note-artifacts.mjs";

test("standalone notes install their theme controls and recovery runtime in head", () => {
	const source = [
		'<!doctype html><html><head><meta charset="utf-8"><title>Demo</title></head>',
		"<body><style>:root{--ql-canvas:#fff}:root.dark{--ql-canvas:#000}</style>",
		'<main class="ql-site">Demo</main></body></html>',
	].join("");
	const html = prepareStandaloneHtml(source, "demo");
	const head = html.slice(html.indexOf("<head>"), html.indexOf("</head>"));

	assert.match(head, /data-qlnotes-theme-runtime/);
	assert.match(head, /data-qlnotes-theme/);
	assert.match(head, /pageshow/);
	assert.match(html, /class="ql-theme-switcher"/);
	assert.match(html, /data-ql-theme-value="light"/);
	assert.match(html, /data-ql-theme-value="dark"/);
	assert.match(html, /data-ql-theme-value="auto"/);
	assert.doesNotMatch(html, /<body><style>/);
});

import type { APIRoute } from "astro";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

export const prerender = true;

const graphDirectory = resolve(
	process.cwd(),
	"../notes/math/knowledge/graph",
);

function readJson(name: string) {
	return JSON.parse(readFileSync(`${graphDirectory}/${name}`, "utf-8"));
}

function readJsonLines(name: string) {
	return readFileSync(`${graphDirectory}/${name}`, "utf-8")
		.split("\n")
		.filter(Boolean)
		.map((line) => JSON.parse(line));
}

export const GET: APIRoute = () => {
	const payload = {
		manifest: readJson("manifest.json"),
		diagnostics: readJson("diagnostics.json"),
		nodes: readJsonLines("nodes.jsonl"),
		edges: readJsonLines("edges.jsonl"),
	};

	return new Response(JSON.stringify(payload), {
		headers: {
			"Content-Type": "application/json; charset=utf-8",
			"Cache-Control": "public, max-age=0, must-revalidate",
		},
	});
};

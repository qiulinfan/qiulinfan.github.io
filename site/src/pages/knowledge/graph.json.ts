import type { APIRoute } from "astro";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

export const prerender = true;

const graphDirectory = resolve(
	process.cwd(),
	"../knowledge/graph",
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
	const manifest = readJson("manifest.json");
	const nodes = readJsonLines("nodes.jsonl").map((node) => ({ ...node, text: "" }));
	const nodeIndex = new Map(nodes.map((node) => [String(node.id), node]));
	for (const shard of manifest.entry_store?.shards ?? []) {
		for (const record of readJsonLines(String(shard.path))) {
			const node = nodeIndex.get(String(record.id));
			if (!node) throw new Error(`Entry shard references unknown node: ${record.id}`);
			node.text = String(record.text ?? "");
			if (record.entry) node.entry = record.entry;
		}
	}
	const payload = {
		manifest,
		diagnostics: readJson("diagnostics.json"),
		nodes,
		edges: readJsonLines("edges.jsonl"),
		references: readJsonLines("references.jsonl"),
	};

	return new Response(JSON.stringify(payload), {
		headers: {
			"Content-Type": "application/json; charset=utf-8",
			"Cache-Control": "public, max-age=0, must-revalidate",
		},
	});
};

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { APIRoute } from "astro";

export const prerender = true;

const repositoryRoot = resolve(process.cwd(), "..");
const graphDirectory = resolve(repositoryRoot, "knowledge/graph");

function readJson(name: string) {
	return JSON.parse(readFileSync(`${graphDirectory}/${name}`, "utf-8"));
}

function readJsonLines(name: string) {
	return readFileSync(`${graphDirectory}/${name}`, "utf-8")
		.split("\n")
		.filter(Boolean)
		.map((line) => JSON.parse(line));
}

function increment(counts: Record<string, number>, key: string) {
	counts[key] = (counts[key] ?? 0) + 1;
}

export const GET: APIRoute = () => {
	const manifest = readJson("manifest.json");
	const registry = JSON.parse(
		readFileSync(resolve(repositoryRoot, "knowledge/sources.json"), "utf-8"),
	);
	const publishedSources = registry.sources.filter(
		(source: { publish?: boolean }) => source.publish === true,
	);
	const publishedKeys = new Set(
		publishedSources.map(
			(source: { subject: string; course: string }) =>
				`${source.subject}/${source.course}`,
		),
	);
	const publishedRoots = publishedSources.map((source: { root: string }) =>
		source.root.replace(/\/+$/, ""),
	);

	const allNodes = readJsonLines("nodes.jsonl").map((node) => ({
		...node,
		text: "",
	}));
	const nodeIndex = new Map(allNodes.map((node) => [String(node.id), node]));
	for (const shard of manifest.entry_store?.shards ?? []) {
		for (const record of readJsonLines(String(shard.path))) {
			const node = nodeIndex.get(String(record.id));
			if (!node)
				throw new Error(`Entry shard references unknown node: ${record.id}`);
			node.text = String(record.text ?? "");
			if (record.entry) node.entry = record.entry;
		}
	}

	const sourceNodes = allNodes.filter((node) => {
		if (node.type === "field") return false;
		const subject = String(node.properties?.subject ?? "");
		const course = String(node.properties?.course ?? "");
		return publishedKeys.has(`${subject}/${course}`);
	});
	const publishedFields = new Set(
		sourceNodes
			.flatMap((node) => [
				...(node.properties?.fields ?? []),
				...(node.properties?.additional_fields ?? []),
			])
			.map(String),
	);
	const publishedSourceNodeIds = new Set(
		sourceNodes.map((node) => String(node.id)),
	);
	const nodes = allNodes.filter((node) =>
		node.type === "field"
			? publishedFields.has(String(node.id))
			: publishedSourceNodeIds.has(String(node.id)),
	);
	const publishedNodeIds = new Set(nodes.map((node) => String(node.id)));
	const edges = readJsonLines("edges.jsonl").filter(
		(edge) =>
			publishedNodeIds.has(String(edge.source)) &&
			publishedNodeIds.has(String(edge.target)),
	);
	const references = readJsonLines("references.jsonl").filter((reference) => {
		const authority = String(reference.authority ?? "");
		return (
			publishedNodeIds.has(String(reference.target)) &&
			publishedRoots.some(
				(root: string) =>
					authority === root || authority.startsWith(`${root}/`),
			)
		);
	});
	const diagnostics = readJson("diagnostics.json");
	const publicDiagnostics = Object.fromEntries(
		Object.entries(diagnostics).map(([level, entries]) => [
			level,
			(entries as Array<{ node?: string; source?: string }>).filter((entry) => {
				if (entry.node) return publishedNodeIds.has(String(entry.node));
				if (entry.source)
					return publishedRoots.some(
						(root: string) =>
							entry.source === root || entry.source?.startsWith(`${root}/`),
					);
				return true;
			}),
		]),
	);
	const nodeTypes: Record<string, number> = {};
	const relations: Record<string, number> = {};
	const knowledgeOrigins: Record<string, number> = {};
	const statuses: Record<string, number> = {};
	for (const node of nodes) {
		increment(nodeTypes, String(node.type));
		increment(statuses, String(node.properties?.source_status ?? "unknown"));
		if (node.type === "knowledge") {
			increment(
				knowledgeOrigins,
				String(node.properties?.knowledge_origin ?? "unknown"),
			);
		}
	}
	for (const edge of edges) increment(relations, String(edge.relation));
	const payload = {
		manifest: {
			schema: manifest.schema,
			generator: manifest.generator,
			graph_sha256: manifest.graph_sha256,
			knowledge_origins: knowledgeOrigins,
			statuses,
			counts: {
				nodes: nodes.length,
				edges: edges.length,
				references: references.length,
			},
			node_types: nodeTypes,
			relations,
		},
		diagnostics: publicDiagnostics,
		nodes,
		edges,
		references,
	};

	return new Response(JSON.stringify(payload), {
		headers: {
			"Content-Type": "application/json; charset=utf-8",
			"Cache-Control": "public, max-age=0, must-revalidate",
		},
	});
};

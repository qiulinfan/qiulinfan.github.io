import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { APIRoute } from "astro";

export const prerender = true;

const exportDirectory = resolve(
	process.cwd(),
	"../knowledge/export/site",
);

export const GET: APIRoute = () => {
	const manifest = JSON.parse(
		readFileSync(resolve(exportDirectory, "manifest.json"), "utf8"),
	);
	const graphText = readFileSync(resolve(exportDirectory, "graph.json"), "utf8");
	const graph = JSON.parse(graphText);
	if (manifest.schema !== "qlkg-static-export-v1") {
		throw new Error(`Unsupported knowledge export: ${manifest.schema}`);
	}
	if (graph.schema !== "qlkg-site-graph-v1") {
		throw new Error(`Unsupported public graph: ${graph.schema}`);
	}
	if (manifest.graph?.public_sha256 !== graph.graph_sha256) {
		throw new Error("Public graph digest does not match its export manifest");
	}

	return new Response(graphText, {
		headers: {
			"Content-Type": "application/json; charset=utf-8",
			"Cache-Control": "public, max-age=0, must-revalidate",
		},
	});
};

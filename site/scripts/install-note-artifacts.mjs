import { copyFileSync, existsSync, mkdirSync, readFileSync } from "node:fs";
import { dirname, relative, resolve, sep } from "node:path";

const siteRoot = resolve(import.meta.dirname, "..");
const repositoryRoot = resolve(siteRoot, "..");
const outputRoot = resolve(siteRoot, "dist");
const registry = JSON.parse(
	readFileSync(resolve(repositoryRoot, "knowledge/sources.json"), "utf-8"),
);

function assertContained(parent, child, label) {
	const local = relative(parent, child);
	if (local.startsWith("..") || local.includes(`${sep}..${sep}`)) {
		throw new Error(`${label} escapes ${parent}: ${child}`);
	}
}

let installed = 0;
for (const spec of registry.sources) {
	if (typeof spec.publish !== "boolean" || typeof spec.listed !== "boolean") {
		throw new Error(
			`Source ${spec.id} must explicitly declare boolean publish and listed values.`,
		);
	}
	if (spec.listed && !spec.publish) {
		throw new Error(
			`Source ${spec.id} cannot be listed when publish is false.`,
		);
	}
	if (!spec.publish) continue;

	const sourceRoot = resolve(repositoryRoot, spec.root);
	const publicRoot = new URL(spec.web).pathname.replace(/^\/+|\/+$/g, "");
	for (const artifact of spec.web_artifacts ?? []) {
		const source = resolve(sourceRoot, artifact.source);
		assertContained(sourceRoot, source, `Artifact source for ${spec.id}`);
		if (!existsSync(source))
			throw new Error(`Missing built note artifact for ${spec.id}: ${source}`);

		const route = String(artifact.route ?? "").replace(/^\/+|\/+$/g, "");
		const destination = resolve(outputRoot, publicRoot, route, "index.html");
		assertContained(
			outputRoot,
			destination,
			`Artifact destination for ${spec.id}`,
		);
		mkdirSync(dirname(destination), { recursive: true });
		copyFileSync(source, destination);
		installed += 1;
	}
}

console.log(`Installed ${installed} published note artifact(s).`);

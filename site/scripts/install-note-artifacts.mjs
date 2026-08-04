import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
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

const themeBootstrap = `<script data-qlnotes-theme-bootstrap>(()=>{const root=document.documentElement;const stored=localStorage.getItem("theme")||"auto";const dark=stored==="dark"||(stored==="auto"&&matchMedia("(prefers-color-scheme: dark)").matches);root.classList.toggle("dark",dark);root.dataset.qlTheme=dark?"dark":"light";})();</script>`;

function prepareStandaloneHtml(source, sourceId) {
	const bodyStyle = /<body><style>([\s\S]*?)<\/style>/u.exec(source);
	if (!bodyStyle) {
		throw new Error(`QLNotes theme style was not found for ${sourceId}.`);
	}
	const withHeadStyle = source
		.replace(bodyStyle[0], "<body>")
		.replace(
			"</head>",
			`${themeBootstrap}<style data-qlnotes-theme>${bodyStyle[1]}</style></head>`,
		);
	if (
		withHeadStyle === source ||
		!withHeadStyle.includes("data-qlnotes-theme")
	) {
		throw new Error(`QLNotes theme integration failed for ${sourceId}.`);
	}
	return withHeadStyle;
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
		const html = prepareStandaloneHtml(readFileSync(source, "utf-8"), spec.id);
		writeFileSync(destination, html, "utf-8");
		installed += 1;
	}
}

console.log(`Installed ${installed} published note artifact(s).`);

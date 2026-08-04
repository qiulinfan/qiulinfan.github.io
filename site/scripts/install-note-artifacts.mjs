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

const themeControl = `<div class="ql-theme-switcher" role="group" aria-label="Color theme"><button type="button" data-ql-theme-value="light" aria-pressed="false">Light</button><button type="button" data-ql-theme-value="dark" aria-pressed="false">Dark</button><button type="button" data-ql-theme-value="auto" aria-pressed="false">Auto</button></div>`;

const themeRuntime = `<script data-qlnotes-theme-runtime>(()=>{const root=document.documentElement;const media=matchMedia("(prefers-color-scheme: dark)");const modes=new Set(["light","dark","auto"]);const read=()=>{const value=localStorage.getItem("theme")||"auto";return modes.has(value)?value:"auto"};const apply=mode=>{const dark=mode==="dark"||(mode==="auto"&&media.matches);root.classList.toggle("dark",dark);root.dataset.qlTheme=dark?"dark":"light";root.dataset.qlThemeMode=mode;document.querySelectorAll("[data-ql-theme-value]").forEach(button=>button.setAttribute("aria-pressed",String(button.dataset.qlThemeValue===mode)))};const install=()=>{const control=document.querySelector(".ql-theme-switcher");control?.addEventListener("click",event=>{const button=event.target.closest("button[data-ql-theme-value]");if(!button)return;const mode=button.dataset.qlThemeValue;if(!modes.has(mode))return;localStorage.setItem("theme",mode);apply(mode)});apply(read())};apply(read());if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",install,{once:true});else install();media.addEventListener?.("change",()=>{if(read()==="auto")apply("auto")});addEventListener("storage",event=>{if(event.key==="theme")apply(read())});addEventListener("pageshow",event=>{apply(read());if(event.persisted&&(!document.head.querySelector("style[data-qlnotes-theme]")||!getComputedStyle(root).getPropertyValue("--ql-canvas").trim()))location.reload()})})();</script>`;

export function prepareStandaloneHtml(source, sourceId) {
	const bodyStyle = /<body><style>([\s\S]*?)<\/style>/u.exec(source);
	if (!bodyStyle) {
		throw new Error(`QLNotes theme style was not found for ${sourceId}.`);
	}
	const withHeadStyle = source
		.replace(bodyStyle[0], `<body>${themeControl}`)
		.replace(
			"</head>",
			`${themeRuntime}<style data-qlnotes-theme>${bodyStyle[1]}</style></head>`,
		);
	if (
		withHeadStyle === source ||
		!withHeadStyle.includes("data-qlnotes-theme") ||
		!withHeadStyle.includes("ql-theme-switcher")
	) {
		throw new Error(`QLNotes theme integration failed for ${sourceId}.`);
	}
	return withHeadStyle;
}

export function installPublishedNoteArtifacts() {
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
				throw new Error(
					`Missing built note artifact for ${spec.id}: ${source}`,
				);

			const route = String(artifact.route ?? "").replace(/^\/+|\/+$/g, "");
			const destination = resolve(outputRoot, publicRoot, route, "index.html");
			assertContained(
				outputRoot,
				destination,
				`Artifact destination for ${spec.id}`,
			);
			mkdirSync(dirname(destination), { recursive: true });
			const html = prepareStandaloneHtml(
				readFileSync(source, "utf-8"),
				spec.id,
			);
			writeFileSync(destination, html, "utf-8");
			installed += 1;
		}
	}

	console.log(`Installed ${installed} published note artifact(s).`);
	return installed;
}

if (process.argv[1] && resolve(process.argv[1]) === import.meta.filename) {
	installPublishedNoteArtifacts();
}

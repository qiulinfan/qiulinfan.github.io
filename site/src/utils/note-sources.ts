import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { basename, dirname, extname, relative, resolve, sep } from "node:path";
import katex from "katex";
import MarkdownIt from "markdown-it";
import { createHighlighter } from "shiki";
import type { MarkdownHeading } from "astro";
import { markdownNoteConfig } from "../config/note-presentation.ts";

interface SourceSpec {
	id: string;
	title: string;
	description: string;
	subject: string;
	course: string;
	root: string;
	files: string[];
	fields: string[];
	publish: boolean;
	listed: boolean;
	web: string;
	web_artifacts?: Array<{ source: string; route: string }>;
}

interface FieldSpec {
	id: string;
	label: string;
}

interface SourceRegistry {
	fields: FieldSpec[];
	sources: SourceSpec[];
}

interface GraphNode {
	id: string;
	label: string;
	properties?: Record<string, unknown>;
	provenance?: {
		authority?: string;
		line?: number;
		web?: string;
	};
}

interface GraphReference {
	target: string;
	authority: string;
	line: number;
	source_name?: string;
	display_markup?: string;
}

export interface MarkdownNote {
	slug: string;
	title: string;
	description: string;
	subject: string;
	course: string;
	sourceTitle: string;
	sourceId: string;
	authority: string;
	html: string;
	headings: MarkdownHeading[];
	heroImage?: string;
	backgroundImage?: string;
	navigation: MarkdownNavigationItem[];
}

export interface MarkdownNavigationItem extends MarkdownHeading {
	href: string;
	documentSlug: string;
}

export interface NoteSource {
	id: string;
	title: string;
	description: string;
	subject: string;
	course: string;
	authority: string;
	href: string;
	navigationHref: string;
	fields: string[];
	standalone: boolean;
}

interface RenderOptions {
	resolveTarget?: (target: string, kind: "image" | "link") => string;
}

const repositoryRoot = resolve(process.cwd(), "..");
const registryPath = resolve(repositoryRoot, "knowledge/sources.json");
const publicGraphPath = resolve(
	repositoryRoot,
	"knowledge/export/site/graph.json",
);
const standalonePresentationPaths = [
	resolve(repositoryRoot, "notes/math/toolchain/qlnotes.typ"),
	resolve(repositoryRoot, "notes/math/toolchain/web.css"),
	resolve(repositoryRoot, "site/scripts/install-note-artifacts.mjs"),
];
const codeHighlighter = await createHighlighter({
	themes: [markdownNoteConfig.codeThemes.light, markdownNoteConfig.codeThemes.dark],
	langs: ["plaintext", "cpp", "bash", "bat", "makefile", "json", "powershell", "latex", "typst"],
});
const codeLanguageAliases = new Map([
	["c++", "cpp"],
	["shell", "bash"],
	["sh", "bash"],
	["cmd", "bat"],
	["makefile", "makefile"],
	["tex", "latex"],
]);

interface PublicGraph {
	schema: "qlkg-site-graph-v1";
	nodes: GraphNode[];
	references: GraphReference[];
}

let cachedPublicGraph: PublicGraph | undefined;

function publicGraph(): PublicGraph {
	if (cachedPublicGraph) return cachedPublicGraph;
	const payload = JSON.parse(
		readFileSync(publicGraphPath, "utf-8"),
	) as PublicGraph;
	if (payload.schema !== "qlkg-site-graph-v1") {
		throw new Error(`Unsupported public graph export: ${payload.schema}`);
	}
	cachedPublicGraph = payload;
	return payload;
}

let cachedRegistry: SourceRegistry | undefined;

function sourceRegistry(): SourceRegistry {
	if (cachedRegistry) return cachedRegistry;
	const payload = JSON.parse(readFileSync(registryPath, "utf-8")) as SourceRegistry;
	for (const spec of payload.sources) {
		if (typeof spec.publish !== "boolean" || typeof spec.listed !== "boolean") {
			throw new Error(`Source ${spec.id} must explicitly declare boolean publish and listed values.`);
		}
		if (spec.listed && !spec.publish) {
			throw new Error(`Source ${spec.id} cannot be listed when publish is false.`);
		}
		if (!spec.title.trim() || !spec.description.trim()) {
			throw new Error(`Source ${spec.id} must declare a title and description for site publication.`);
		}
	}
	cachedRegistry = payload;
	return cachedRegistry;
}

function sourceWebPath(spec: SourceSpec): string {
	const pathname = new URL(spec.web).pathname.replace(/\/+$/, "");
	return `${pathname || "/"}${pathname ? "/" : ""}`;
}

let cachedStandalonePresentationVersion: string | undefined;

function standalonePresentationVersion(): string {
	if (cachedStandalonePresentationVersion) return cachedStandalonePresentationVersion;
	const digest = createHash("sha256");
	for (const path of standalonePresentationPaths) digest.update(readFileSync(path, "utf8"));
	cachedStandalonePresentationVersion = digest.digest("hex").slice(0, 12);
	return cachedStandalonePresentationVersion;
}

export function loadListedNoteSources(): NoteSource[] {
	const registry = sourceRegistry();
	const fieldLabels = new Map(registry.fields.map((field) => [field.id, field.label]));
	return registry.sources
		.filter((spec) => spec.publish && spec.listed)
		.map((spec) => {
			const href = sourceWebPath(spec);
			const standalone = Boolean(spec.web_artifacts?.length);
			return {
				id: spec.id,
				title: spec.title,
				description: spec.description,
				subject: spec.subject,
				course: spec.course,
				authority: spec.root,
				href,
				navigationHref: standalone ? `${href}?v=${standalonePresentationVersion()}` : href,
				fields: spec.fields.map((field) => fieldLabels.get(field) ?? field),
				standalone,
			};
		})
		.sort((left, right) => left.title.localeCompare(right.title));
}

function walk(directory: string): string[] {
	const result: string[] = [];
	for (const entry of readdirSync(directory, { withFileTypes: true })) {
		if (entry.name.startsWith(".") || ["build", "dist", "exports", "node_modules"].includes(entry.name)) {
			continue;
		}
		const path = resolve(directory, entry.name);
		if (entry.isDirectory()) result.push(...walk(path));
		else if (entry.isFile()) result.push(path);
	}
	return result;
}

function matchesPattern(path: string, pattern: string): boolean {
	let expression = "^";
	for (let index = 0; index < pattern.length; index += 1) {
		const character = pattern[index];
		if (character === "*" && pattern[index + 1] === "*") {
			expression += ".*";
			index += 1;
		} else if (character === "*") {
			expression += "[^/]*";
		} else if (character === "?") {
			expression += "[^/]";
		} else {
			expression += character.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
		}
	}
	return new RegExp(`${expression}$`).test(path);
}

function markdownFiles(spec: SourceSpec): string[] {
	if (!spec.files.some((pattern) => pattern.toLowerCase().includes(".md"))) return [];
	const root = resolve(repositoryRoot, spec.root);
	return walk(root)
		.filter((path) => extname(path).toLowerCase() === ".md")
		.filter((path) => {
			const local = relative(root, path).split(sep).join("/");
			return spec.files.some((pattern) => matchesPattern(local, pattern));
		})
		.sort();
}

function noteSlug(spec: SourceSpec, path: string): string {
	const root = resolve(repositoryRoot, spec.root);
	const parts = relative(root, path).split(sep);
	parts[parts.length - 1] = basename(parts[parts.length - 1], extname(path));
	if (["index", "readme"].includes(parts.at(-1)?.toLowerCase() ?? "")) parts.pop();
	return [spec.subject, spec.course, ...parts].join("/");
}

function sitePath(path: string): string {
	const base = import.meta.env?.BASE_URL ?? "/";
	return `${base.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;
}

function localSourceTarget(spec: SourceSpec, sourcePath: string, rawTarget: string): string | undefined {
	const decoded = (() => {
		try { return decodeURIComponent(rawTarget); } catch { return rawTarget; }
	})().replaceAll("\\", "/").trim();
	const windowsDrivePath = /^[A-Za-z]:\//.test(decoded);
	if (!decoded || decoded.startsWith("#") || (!windowsDrivePath && /^[A-Za-z][A-Za-z0-9+.-]*:/.test(decoded))) return undefined;
	const withoutQuery = decoded.split(/[?#]/, 1)[0];
	const root = resolve(repositoryRoot, spec.root);
	const candidates = [resolve(dirname(sourcePath), withoutQuery), resolve(root, withoutQuery)];
	const segments = withoutQuery.split("/").filter(Boolean);
	for (let index = 0; index < segments.length; index += 1) {
		candidates.push(resolve(root, ...segments.slice(index)));
	}
	const direct = candidates.find((candidate) => {
		const local = relative(root, candidate);
		return local !== "" && !local.startsWith("..") && !local.includes(`${sep}..${sep}`) && existsSync(candidate) && statSync(candidate).isFile();
	});
	if (direct) return direct;
	const suffix = withoutQuery.replace(/^\/+/, "").split("/").filter(Boolean).join(sep);
	const relocated = walk(root).filter((candidate) => candidate.endsWith(`${sep}${suffix}`));
	return relocated.length === 1 ? relocated[0] : undefined;
}

function publishedTarget(spec: SourceSpec, sourcePath: string, rawTarget: string): string {
	const target = localSourceTarget(spec, sourcePath, rawTarget);
	if (!target) return rawTarget;
	if (extname(target).toLowerCase() === ".md") {
		return sitePath(`/notes/${noteSlug(spec, target)}/`);
	}
	const root = resolve(repositoryRoot, spec.root);
	const local = relative(root, target).split(sep).map(encodeURIComponent).join("/");
	const sourceId = spec.id.replace(/[^A-Za-z0-9._-]+/g, "-");
	return sitePath(`/_notes-assets/${sourceId}/${local}`);
}

function presentationImage(
	spec: SourceSpec,
	sourcePath: string,
	rawValue: string | undefined,
	defaultValue: string | undefined,
): string | undefined {
	const value = (rawValue ?? defaultValue)?.trim();
	if (!value || ["false", "none", "null", "off"].includes(value.toLowerCase())) return undefined;
	const resolved = publishedTarget(spec, sourcePath, value);
	if (resolved === value && value.startsWith("/")) return sitePath(value);
	return resolved;
}

function rewriteRawHtmlTargets(source: string, spec: SourceSpec, sourcePath: string): string {
	return source.replace(/\b(src|href)\s*=\s*(["'])(.*?)\2/gi, (_whole, attribute: string, quote: string, target: string) => {
		const rewritten = publishedTarget(spec, sourcePath, target);
		return `${attribute}=${quote}${rewritten}${quote}`;
	});
}

function authority(path: string): string {
	return relative(repositoryRoot, path).split(sep).join("/");
}

function splitFrontmatter(source: string): { body: string; metadata: Record<string, string> } {
	if (!source.startsWith("---\n")) return { body: source, metadata: {} };
	const end = source.indexOf("\n---\n", 4);
	if (end < 0) return { body: source, metadata: {} };
	const metadata: Record<string, string> = {};
	for (const line of source.slice(4, end).split("\n")) {
		const match = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(line);
		if (match) metadata[match[1]] = match[2].replace(/^['"]|['"]$/g, "");
	}
	return { body: source.slice(end + 5), metadata };
}

function escapeHtml(value: string): string {
	return value
		.replaceAll("&", "&amp;")
		.replaceAll("<", "&lt;")
		.replaceAll(">", "&gt;")
		.replaceAll('"', "&quot;")
		.replaceAll("'", "&#39;");
}

function installMath(renderer: MarkdownIt) {
	const md = renderer as any;
	md.inline.ruler.after("escape", "ql_math_inline", (state: any, silent: boolean) => {
		if (state.src[state.pos] !== "$" || state.src[state.pos + 1] === "$") return false;
		let end = state.pos + 1;
		while ((end = state.src.indexOf("$", end)) >= 0) {
			if (state.src[end - 1] !== "\\") break;
			end += 1;
		}
		if (end < 0 || end === state.pos + 1) return false;
		if (!silent) {
			const token = state.push("ql_math_inline", "math", 0);
			token.content = state.src.slice(state.pos + 1, end);
		}
		state.pos = end + 1;
		return true;
	});
	md.block.ruler.before("fence", "ql_math_block", (state: any, startLine: number, endLine: number, silent: boolean) => {
		const start = state.bMarks[startLine] + state.tShift[startLine];
		const maximum = state.eMarks[startLine];
		if (state.src.slice(start, maximum).trim() !== "$$") return false;
		let next = startLine + 1;
		while (next < endLine) {
			const begin = state.bMarks[next] + state.tShift[next];
			const end = state.eMarks[next];
			if (state.src.slice(begin, end).trim() === "$$") break;
			next += 1;
		}
		if (next >= endLine) return false;
		if (!silent) {
			const token = state.push("ql_math_block", "math", 0);
			token.block = true;
			token.map = [startLine, next + 1];
			token.content = state.getLines(startLine + 1, next, state.tShift[startLine], true).trim();
		}
		state.line = next + 1;
		return true;
	});
	md.renderer.rules.ql_math_inline = (tokens: any[], index: number) =>
		katex.renderToString(tokens[index].content, { strict: false, throwOnError: false, output: "htmlAndMathml" });
	md.renderer.rules.ql_math_block = (tokens: any[], index: number) =>
		katex.renderToString(tokens[index].content, { displayMode: true, strict: false, throwOnError: false, output: "htmlAndMathml" });
}

function installCodeHighlighting(renderer: MarkdownIt) {
	const loaded = new Set(codeHighlighter.getLoadedLanguages());
	renderer.renderer.rules.fence = (tokens: any[], index: number) => {
		const token = tokens[index];
		const sourceLanguage = String(token.info ?? "").trim().split(/\s+/, 1)[0];
		const normalized = sourceLanguage.toLowerCase();
		const candidate = codeLanguageAliases.get(normalized) ?? normalized;
		const language = loaded.has(candidate) ? candidate : "plaintext";
		const label = sourceLanguage || "text";
		const highlighted = codeHighlighter.codeToHtml(token.content, {
			lang: language as any,
			themes: markdownNoteConfig.codeThemes,
		});
		return `<figure class="ql-code-block" data-language="${escapeHtml(label)}"><figcaption>${escapeHtml(label)}</figcaption>${highlighted}</figure>`;
	};
}

function installHeadingIds(renderer: MarkdownIt, headings: MarkdownHeading[], markerLabels: string[]) {
	const counts = new Map<string, number>();
	(renderer as any).core.ruler.push("ql_heading_ids", (state: any) => {
		for (let index = 0; index < state.tokens.length; index += 1) {
			const token = state.tokens[index];
			if (token.type !== "heading_open") continue;
			const inline = state.tokens[index + 1];
			const inlineText = Array.isArray(inline?.children)
				? inline.children.map((child: any) => child.content ?? "").join("")
				: (inline?.content ?? "");
			const text = inlineText
				.replace(/QLKGMARKER(\d+)END/g, (_: string, rawIndex: string) => markerLabels[Number(rawIndex)] ?? "")
				.trim() || "section";
			const base = text
				.normalize("NFKC")
				.toLowerCase()
				.replace(/[^\p{Letter}\p{Number}]+/gu, "-")
				.replace(/^-+|-+$/g, "") || "section";
			const count = counts.get(base) ?? 0;
			counts.set(base, count + 1);
			const slug = count ? `${base}-${count + 1}` : base;
			token.attrSet("id", slug);
			headings.push({ depth: Number(token.tag.slice(1)), slug, text });
		}
	});
}

function wikilinkParts(body: string): { target: string; display: string } {
	const separator = body.indexOf("|");
	if (separator < 0) return { target: body.trim(), display: body.trim() };
	const target = body.slice(0, separator).trim();
	const display = body.slice(separator + 1).trim();
	return { target, display: display || target };
}

export function renderKnowledgeMarkdown(
	source: string,
	fileAuthority: string,
	nodes: GraphNode[],
	references: GraphReference[],
	options: RenderOptions = {},
): { html: string; headings: MarkdownHeading[] } {
	const headings: MarkdownHeading[] = [];
	const markerLabels: string[] = [];
	const renderer = new MarkdownIt({ html: true, linkify: true });
	installMath(renderer);
	installCodeHighlighting(renderer);
	installHeadingIds(renderer, headings, markerLabels);
	if (options.resolveTarget) {
		const defaultImage = renderer.renderer.rules.image;
		renderer.renderer.rules.image = (tokens, index, renderOptions, environment, self) => {
			const source = tokens[index].attrGet("src");
			if (source) tokens[index].attrSet("src", options.resolveTarget?.(source, "image") ?? source);
			return defaultImage ? defaultImage(tokens, index, renderOptions, environment, self) : self.renderToken(tokens, index, renderOptions);
		};
		const defaultLink = renderer.renderer.rules.link_open;
		renderer.renderer.rules.link_open = (tokens, index, renderOptions, environment, self) => {
			const href = tokens[index].attrGet("href");
			if (href) tokens[index].attrSet("href", options.resolveTarget?.(href, "link") ?? href);
			return defaultLink ? defaultLink(tokens, index, renderOptions, environment, self) : self.renderToken(tokens, index, renderOptions);
		};
	}
	const nodesById = new Map(nodes.map((node) => [node.id, node]));
	const markers: string[] = [];
	const markerPattern = /(?<definition>(?<![!\\])--\[\[(?<definitionBody>[^\]\n]+)\]\]--)|(?<reference>(?<![!\-\\])\[\[(?<referenceBody>[^\]\n]+)\]\](?!--))/g;
	const transformed = source.replace(markerPattern, (...arguments_: unknown[]) => {
		const offset = Number(arguments_[arguments_.length - 3]);
		const groups = arguments_.at(-1) as Record<string, string | undefined>;
		const isDefinition = Boolean(groups.definition);
		const body = groups.definitionBody ?? groups.referenceBody ?? "";
		const { target, display } = wikilinkParts(body);
		markerLabels.push(display);
		const line = source.slice(0, offset).split("\n").length;
		let node: GraphNode | undefined;
		if (isDefinition) {
			node = nodes.find((candidate) =>
				candidate.provenance?.authority === fileAuthority &&
				candidate.provenance?.line === line &&
				String(candidate.properties?.source_name ?? "") === target
			);
		} else {
			const reference = references.find((candidate) =>
				candidate.authority === fileAuthority &&
				candidate.line === line &&
				(candidate.source_name ?? "") === target
			);
			node = reference ? nodesById.get(reference.target) : undefined;
		}
		const label = renderer.renderInline(display);
		if (isDefinition && node) {
			markers.push(`<strong id="kn-${escapeHtml(node.id)}" class="ql-kn" data-ql-kn="${escapeHtml(node.id)}">${label}</strong>`);
		} else if (!isDefinition && node?.provenance?.web) {
			markers.push(`<a class="ql-ref" data-ql-ref="${escapeHtml(node.id)}" href="${escapeHtml(node.provenance.web)}">${label}</a>`);
		} else {
			markers.push(`<span class="ql-${isDefinition ? "kn" : "ref"} ql-unresolved" title="图谱尚未同步">${label}</span>`);
		}
		return `QLKGMARKER${markers.length - 1}END`;
	});
	let html = renderer.render(transformed);
	for (let index = 0; index < markers.length; index += 1) {
		html = html.replaceAll(`QLKGMARKER${index}END`, markers[index]);
	}
	return { html, headings };
}

function titleFrom(source: string, metadata: Record<string, string>, path: string): string {
	if (metadata.title) return metadata.title;
	const match = /^#\s+(.+)$/m.exec(source);
	return match?.[1].replace(/--?\[\[|\]\]--?/g, "").trim() || basename(path, extname(path));
}

let cachedNotes: MarkdownNote[] | undefined;

export function loadMarkdownNotes(): MarkdownNote[] {
	if (cachedNotes) return cachedNotes;
	const { nodes, references } = publicGraph();
	const notes: MarkdownNote[] = [];
	for (const spec of sourceRegistry().sources.filter((source) => source.publish)) {
		for (const path of markdownFiles(spec)) {
			const raw = readFileSync(path, "utf-8");
			const { body, metadata } = splitFrontmatter(raw);
			const fileAuthority = authority(path);
			const prepared = rewriteRawHtmlTargets(body, spec, path);
			const rendered = renderKnowledgeMarkdown(prepared, fileAuthority, nodes, references, {
				resolveTarget: (target) => publishedTarget(spec, path, target),
			});
			notes.push({
				slug: noteSlug(spec, path),
				title: titleFrom(body, metadata, path),
				description: metadata.description ?? `${spec.course} · ${fileAuthority}`,
				subject: spec.subject,
				course: spec.course,
				sourceTitle: spec.title,
				sourceId: spec.id,
				authority: fileAuthority,
				html: rendered.html,
				headings: rendered.headings,
				heroImage: presentationImage(spec, path, metadata.hero_image, markdownNoteConfig.defaultHeroImage),
				backgroundImage: presentationImage(spec, path, metadata.background_image, markdownNoteConfig.defaultBackgroundImage),
				navigation: [],
			});
		}
	}
	cachedNotes = notes.sort((left, right) => left.slug.localeCompare(right.slug));
	for (const note of cachedNotes) {
		const courseRoot = `${note.subject}/${note.course}`;
		note.navigation = cachedNotes
			.filter((candidate) => candidate.sourceId === note.sourceId && candidate.slug !== courseRoot)
			.flatMap((candidate) => candidate.headings.map((heading) => ({
				...heading,
				documentSlug: candidate.slug,
				href: sitePath(`/notes/${candidate.slug}/#${heading.slug}`),
			})));
	}
	return cachedNotes;
}

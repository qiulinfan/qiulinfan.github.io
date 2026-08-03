import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { basename, dirname, extname, relative, resolve, sep } from "node:path";
import katex from "katex";
import MarkdownIt from "markdown-it";
import type { MarkdownHeading } from "astro";

interface SourceSpec {
	id: string;
	subject: string;
	course: string;
	root: string;
	files: string[];
	web: string;
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
	sourceId: string;
	authority: string;
	html: string;
	headings: MarkdownHeading[];
}

interface RenderOptions {
	resolveTarget?: (target: string, kind: "image" | "link") => string;
}

const repositoryRoot = resolve(process.cwd(), "..");
const registryPath = resolve(repositoryRoot, "knowledge/sources.json");
const graphRoot = resolve(repositoryRoot, "knowledge/graph");

function readJsonLines<T>(path: string): T[] {
	return readFileSync(path, "utf-8")
		.split("\n")
		.filter(Boolean)
		.map((line) => JSON.parse(line) as T);
}

function sourceRegistry(): SourceSpec[] {
	const payload = JSON.parse(readFileSync(registryPath, "utf-8")) as {
		sources: SourceSpec[];
	};
	return payload.sources;
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
	if (!decoded || decoded.startsWith("#") || /^[A-Za-z][A-Za-z0-9+.-]*:/.test(decoded)) return undefined;
	const withoutQuery = decoded.split(/[?#]/, 1)[0];
	const root = resolve(repositoryRoot, spec.root);
	const candidates = [resolve(dirname(sourcePath), withoutQuery), resolve(root, withoutQuery)];
	const segments = withoutQuery.split("/").filter(Boolean);
	for (let index = 0; index < segments.length; index += 1) {
		candidates.push(resolve(root, ...segments.slice(index)));
	}
	return candidates.find((candidate) => {
		const local = relative(root, candidate);
		return local !== "" && !local.startsWith("..") && !local.includes(`${sep}..${sep}`) && existsSync(candidate) && statSync(candidate).isFile();
	});
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

function installHeadingIds(renderer: MarkdownIt, headings: MarkdownHeading[], markerLabels: string[]) {
	const counts = new Map<string, number>();
	(renderer as any).core.ruler.push("ql_heading_ids", (state: any) => {
		for (let index = 0; index < state.tokens.length; index += 1) {
			const token = state.tokens[index];
			if (token.type !== "heading_open") continue;
			const inline = state.tokens[index + 1];
			const text = (inline?.content ?? "")
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
	const nodes = readJsonLines<GraphNode>(resolve(graphRoot, "nodes.jsonl"));
	const references = readJsonLines<GraphReference>(resolve(graphRoot, "references.jsonl"));
	const notes: MarkdownNote[] = [];
	for (const spec of sourceRegistry()) {
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
				sourceId: spec.id,
				authority: fileAuthority,
				html: rendered.html,
				headings: rendered.headings,
			});
		}
	}
	cachedNotes = notes.sort((left, right) => left.slug.localeCompare(right.slug));
	return cachedNotes;
}

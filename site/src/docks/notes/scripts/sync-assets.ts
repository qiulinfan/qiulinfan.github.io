import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync } from "node:fs";
import { dirname, extname, relative, resolve, sep } from "node:path";

interface SourceSpec {
	id: string;
	root: string;
	files: string[];
	publish: boolean;
}

const staticExtensions = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".pdf"]);

function walk(directory: string): string[] {
	const result: string[] = [];
	for (const entry of readdirSync(directory, { withFileTypes: true })) {
		if (entry.name.startsWith(".") || ["build", "dist", "exports", "node_modules"].includes(entry.name)) continue;
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
		if (character === "*" && pattern[index + 1] === "*") { expression += ".*"; index += 1; }
		else if (character === "*") expression += "[^/]*";
		else if (character === "?") expression += "[^/]";
		else expression += character.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	}
	return new RegExp(`${expression}$`).test(path);
}

function resolveTarget(root: string, sourcePath: string, rawTarget: string): string | undefined {
	let decoded = rawTarget;
	try { decoded = decodeURIComponent(rawTarget); } catch {}
	decoded = decoded.replaceAll("\\", "/").trim();
	const windowsDrivePath = /^[A-Za-z]:\//.test(decoded);
	if (!decoded || decoded.startsWith("#") || (!windowsDrivePath && /^[A-Za-z][A-Za-z0-9+.-]*:/.test(decoded))) return undefined;
	const withoutQuery = decoded.split(/[?#]/, 1)[0];
	const candidates = [resolve(dirname(sourcePath), withoutQuery), resolve(root, withoutQuery)];
	const segments = withoutQuery.split("/").filter(Boolean);
	for (let index = 0; index < segments.length; index += 1) candidates.push(resolve(root, ...segments.slice(index)));
	const direct = candidates.find((candidate) => {
		const local = relative(root, candidate);
		return local !== "" && !local.startsWith("..") && !local.includes(`${sep}..${sep}`) && existsSync(candidate) && statSync(candidate).isFile();
	});
	if (direct) return direct;
	const suffix = withoutQuery.replace(/^\/+/, "").split("/").filter(Boolean).join(sep);
	const relocated = walk(root).filter((candidate) => candidate.endsWith(`${sep}${suffix}`));
	return relocated.length === 1 ? relocated[0] : undefined;
}

function targets(source: string): string[] {
	const result: string[] = [];
	for (const match of source.matchAll(/^(?:hero_image|background_image):\s*(['"]?)(.*?)\1\s*$/gim)) result.push(match[2]);
	for (const match of source.matchAll(/\b(?:src|href)\s*=\s*(["'])(.*?)\1/gi)) result.push(match[2]);
	for (const match of source.matchAll(/!?\[[^\]]*\]\(\s*(?:<([^>]+)>|([^\s)]+))/g)) result.push(match[1] ?? match[2]);
	return result;
}

// Copy the images and files that published Markdown notes reference into the
// site's public directory, where the rendered notes link to them.
export function syncNoteAssets(notesRoot: string, outputRoot: string): number {
	const registry = JSON.parse(readFileSync(resolve(notesRoot, "knowledge/sources.json"), "utf-8")) as { sources: SourceSpec[] };
	rmSync(outputRoot, { recursive: true, force: true });
	let copied = 0;
	for (const spec of registry.sources) {
		if (!spec.publish) continue;
		if (!spec.files.some((pattern) => pattern.toLowerCase().includes(".md"))) continue;
		const root = resolve(notesRoot, spec.root);
		const markdown = walk(root).filter((path) => {
			if (extname(path).toLowerCase() !== ".md") return false;
			const local = relative(root, path).split(sep).join("/");
			return spec.files.some((pattern) => matchesPattern(local, pattern));
		});
		const sourceId = spec.id.replace(/[^A-Za-z0-9._-]+/g, "-");
		const selected = new Set<string>();
		for (const path of markdown) {
			for (const rawTarget of targets(readFileSync(path, "utf-8"))) {
				const target = resolveTarget(root, path, rawTarget);
				if (target && staticExtensions.has(extname(target).toLowerCase())) selected.add(target);
			}
		}
		for (const source of selected) {
			const destination = resolve(outputRoot, sourceId, relative(root, source));
			mkdirSync(dirname(destination), { recursive: true });
			copyFileSync(source, destination);
			copied += 1;
		}
	}
	return copied;
}

import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync } from "node:fs";
import { dirname, extname, relative, resolve, sep } from "node:path";

const siteRoot = resolve(import.meta.dirname, "..");
const repositoryRoot = resolve(siteRoot, "..");
const outputRoot = resolve(siteRoot, "public/_notes-assets");
const registry = JSON.parse(readFileSync(resolve(repositoryRoot, "knowledge/sources.json"), "utf-8"));
const staticExtensions = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".pdf"]);

function walk(directory) {
	const result = [];
	for (const entry of readdirSync(directory, { withFileTypes: true })) {
		if (entry.name.startsWith(".") || ["build", "dist", "exports", "node_modules"].includes(entry.name)) continue;
		const path = resolve(directory, entry.name);
		if (entry.isDirectory()) result.push(...walk(path));
		else if (entry.isFile()) result.push(path);
	}
	return result;
}

function matchesPattern(path, pattern) {
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

function resolveTarget(root, sourcePath, rawTarget) {
	let decoded = rawTarget;
	try { decoded = decodeURIComponent(rawTarget); } catch {}
	decoded = decoded.replaceAll("\\", "/").trim();
	if (!decoded || decoded.startsWith("#") || /^[A-Za-z][A-Za-z0-9+.-]*:/.test(decoded)) return undefined;
	const withoutQuery = decoded.split(/[?#]/, 1)[0];
	const candidates = [resolve(dirname(sourcePath), withoutQuery), resolve(root, withoutQuery)];
	const segments = withoutQuery.split("/").filter(Boolean);
	for (let index = 0; index < segments.length; index += 1) candidates.push(resolve(root, ...segments.slice(index)));
	return candidates.find((candidate) => {
		const local = relative(root, candidate);
		return local !== "" && !local.startsWith("..") && !local.includes(`${sep}..${sep}`) && existsSync(candidate) && statSync(candidate).isFile();
	});
}

function targets(source) {
	const result = [];
	for (const match of source.matchAll(/\b(?:src|href)\s*=\s*(["'])(.*?)\1/gi)) result.push(match[2]);
	for (const match of source.matchAll(/!?\[[^\]]*\]\(\s*(?:<([^>]+)>|([^\s)]+))/g)) result.push(match[1] ?? match[2]);
	return result;
}

rmSync(outputRoot, { recursive: true, force: true });
let copied = 0;
for (const spec of registry.sources) {
	if (!spec.files.some((pattern) => pattern.toLowerCase().includes(".md"))) continue;
	const root = resolve(repositoryRoot, spec.root);
	const markdown = walk(root).filter((path) => {
		if (extname(path).toLowerCase() !== ".md") return false;
		const local = relative(root, path).split(sep).join("/");
		return spec.files.some((pattern) => matchesPattern(local, pattern));
	});
	const sourceId = spec.id.replace(/[^A-Za-z0-9._-]+/g, "-");
	const selected = new Set();
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
console.log(`Synced ${copied} note asset(s).`);

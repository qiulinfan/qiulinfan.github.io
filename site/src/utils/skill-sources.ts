import { readdirSync, readFileSync } from "node:fs";
import { dirname, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

export interface PublishedSkill {
	id: string;
	name: string;
	description: string;
	license?: string;
	authority: string;
	sourceHref: string;
}

const repositoryRoot = resolve(
	dirname(fileURLToPath(import.meta.url)),
	"../../..",
);
const skillsRoot = resolve(repositoryRoot, "skills");
const skillsReadme = resolve(skillsRoot, "README.md");
const workflowsDocument = resolve(skillsRoot, "WORKFLOWS.md");
const sourceBase = "https://github.com/qiulinfan/qiulinfan.github.io/blob/main";
const unpublishedSkillRoots = new Set([resolve(skillsRoot, "community")]);

function skillFiles(directory: string): string[] {
	return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
		if (entry.name.startsWith(".")) return [];
		const path = resolve(directory, entry.name);
		if (entry.isDirectory()) {
			if (unpublishedSkillRoots.has(path)) return [];
			return skillFiles(path);
		}
		return entry.name === "SKILL.md" ? [path] : [];
	});
}

function yamlScalar(value: string): string {
	const trimmed = value.trim();
	if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
		try {
			return JSON.parse(trimmed);
		} catch {
			return trimmed.slice(1, -1);
		}
	}
	if (trimmed.startsWith("'") && trimmed.endsWith("'")) {
		return trimmed.slice(1, -1).replace(/''/g, "'");
	}
	return trimmed;
}

function frontmatter(source: string): Record<string, string> {
	const block = /^---\r?\n([\s\S]*?)\r?\n---/.exec(source)?.[1];
	if (!block) return {};
	const metadata: Record<string, string> = {};
	const lines = block.split(/\r?\n/);
	for (let index = 0; index < lines.length; index += 1) {
		const line = lines[index];
		const match = /^([a-zA-Z][\w-]*):\s*(.*)$/.exec(line);
		if (!match || !match[2]) continue;
		if (match[2] === ">" || match[2] === "|") {
			const continuation: string[] = [];
			while (index + 1 < lines.length && /^\s+/.test(lines[index + 1])) {
				continuation.push(lines[index + 1].trim());
				index += 1;
			}
			metadata[match[1]] =
				match[2] === ">" ? continuation.join(" ") : continuation.join("\n");
			continue;
		}
		metadata[match[1]] = yamlScalar(match[2]);
	}
	return metadata;
}

export function loadPublishedSkills(): PublishedSkill[] {
	return skillFiles(skillsRoot)
		.map((path) => {
			const authority = relative(repositoryRoot, path).split(sep).join("/");
			const metadata = frontmatter(readFileSync(path, "utf8"));
			const id = relative(skillsRoot, dirname(path)).split(sep).join("/");
			return {
				id,
				name: metadata.name || id,
				description: metadata.description || "",
				license: metadata.license,
				authority,
				sourceHref: `${sourceBase}/${encodeURI(authority)}`,
			};
		})
		.sort((left, right) => left.name.localeCompare(right.name));
}

function markdownSection(source: string, heading: string): string {
	const startMarker = `## ${heading}`;
	const start = source.indexOf(startMarker);
	if (start === -1)
		throw new Error(`${skillsReadme} is missing ${startMarker}.`);
	const next = source.indexOf("\n## ", start + startMarker.length);
	return source.slice(start, next === -1 ? undefined : next).trim();
}

function linkedSkillIds(markdown: string): string[] {
	return [...markdown.matchAll(/\]\(\.\/([^\s)]+)\/\)/g)].map(
		(match) => match[1],
	);
}

export function loadSkillCatalogMarkdown(): string {
	const source = readFileSync(skillsReadme, "utf8");
	return markdownSection(source, "个人维护");
}

export function loadOwnedSkills(): PublishedSkill[] {
	const source = readFileSync(skillsReadme, "utf8");
	const ownedIds = linkedSkillIds(markdownSection(source, "个人维护"));
	const publishedById = new Map(
		loadPublishedSkills().map((skill) => [skill.id, skill]),
	);
	return ownedIds.map((id) => {
		const skill = publishedById.get(id);
		if (!skill) {
			throw new Error(
				`${skillsReadme} lists ${id} as personally maintained, but its SKILL.md is missing.`,
			);
		}
		return skill;
	});
}

export function loadSkillWorkflowsMarkdown(): string {
	return readFileSync(workflowsDocument, "utf8");
}

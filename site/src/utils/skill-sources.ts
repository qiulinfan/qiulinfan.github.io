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
	repository: string;
}

export interface CatalogSkill extends PublishedSkill {
	summary: string;
}

export interface SkillDirectoryGroup {
	directory: string;
	path: string;
	skills: CatalogSkill[];
	kind: "directory" | "repository";
}

const repositoryRoot = resolve(
	dirname(fileURLToPath(import.meta.url)),
	"../../..",
);
const skillsRoot = resolve(repositoryRoot, "skills");
const skillsReadme = resolve(skillsRoot, "README.md");
const workflowsDocument = resolve(skillsRoot, "WORKFLOWS.md");
const publishedRepositoriesDocument = resolve(
	skillsRoot,
	"published-skill-repositories.tsv",
);
const sourceBase = "https://github.com/qiulinfan/qiulinfan.github.io/blob/main";

function skillFiles(directory: string): string[] {
	return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
		if (entry.name.startsWith(".")) return [];
		const path = resolve(directory, entry.name);
		if (entry.isDirectory()) {
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
		if (/^[>|][+-]?$/.test(match[2])) {
			const continuation: string[] = [];
			while (index + 1 < lines.length && /^\s+/.test(lines[index + 1])) {
				continuation.push(lines[index + 1].trim());
				index += 1;
			}
			metadata[match[1]] =
				match[2].startsWith(">")
					? continuation.join(" ")
					: continuation.join("\n");
			continue;
		}
		metadata[match[1]] = yamlScalar(match[2]);
	}
	return metadata;
}

function loadQlblogSkills(): PublishedSkill[] {
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
				repository: "qiulinfan.github.io",
			};
		})
		.sort((left, right) => left.name.localeCompare(right.name));
}

interface PublishedRepository {
	name: string;
	cloneUrl: string;
	sourceUrl: string;
	checkout: string;
	skillRoot: string;
	ref: string;
}

function publishedRepositories(): PublishedRepository[] {
	return readFileSync(publishedRepositoriesDocument, "utf8")
		.split(/\r?\n/)
		.map((line) => line.trimEnd())
		.filter((line) => line.trim() && !line.trimStart().startsWith("#"))
		.map((line) => {
			const fields = line.split("\t");
			if (fields.length !== 6 || fields.some((field) => !field.trim())) {
				throw new Error(
					`${publishedRepositoriesDocument} requires six non-empty tab-separated fields per row.`,
				);
			}
			const [name, cloneUrl, sourceUrl, checkout, skillRoot, ref] = fields;
			if (
				!cloneUrl.startsWith("https://github.com/qiulinfan/") ||
				!sourceUrl.startsWith("https://github.com/qiulinfan/")
			) {
				throw new Error(
					`Published Skill repository must be owned by qiulinfan: ${name}`,
				);
			}
			return { name, cloneUrl, sourceUrl, checkout, skillRoot, ref };
		});
}

function loadExternalPublishedSkills(): PublishedSkill[] {
	return publishedRepositories().flatMap((repository) => {
		const checkoutRoot = resolve(repositoryRoot, repository.checkout);
		const repositorySkillsRoot = resolve(checkoutRoot, repository.skillRoot);
		return skillFiles(repositorySkillsRoot).map((path) => {
			const metadata = frontmatter(readFileSync(path, "utf8"));
			const relativeManifest = relative(checkoutRoot, path).split(sep).join("/");
			const relativeSkill = relative(repositorySkillsRoot, dirname(path))
				.split(sep)
				.join("/");
			return {
				id: `${repository.name}/${relativeSkill}`,
				name: metadata.name || relativeSkill,
				description: metadata.description || "",
				license: metadata.license,
				authority: `${repository.name}/${relativeManifest}`,
				sourceHref: `${repository.sourceUrl}/blob/${encodeURIComponent(repository.ref)}/${encodeURI(relativeManifest)}`,
				repository: repository.name,
			};
		});
	});
}

export function loadPublishedSkills(): PublishedSkill[] {
	const skills = [...loadQlblogSkills(), ...loadExternalPublishedSkills()].sort(
		(left, right) => left.name.localeCompare(right.name),
	);
	const duplicateNames = skills
		.map((skill) => skill.name)
		.filter((name, index, names) => names.indexOf(name) !== index);
	if (duplicateNames.length > 0) {
		throw new Error(
			`Published Skill names must be globally unique: ${[...new Set(duplicateNames)].join(", ")}`,
		);
	}
	return skills;
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

function catalogSummaries(markdown: string): Map<string, string> {
	return new Map(
		[...markdown.matchAll(/^- \[[^\]]+\]\(\.\/([^\s)]+)\/\)[：:]\s*(.+)$/gm)].map(
			(match) => [match[1], match[2].trim()],
		),
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
		loadQlblogSkills().map((skill) => [skill.id, skill]),
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

export function loadSkillDirectoryGroups(): SkillDirectoryGroup[] {
	const catalog = loadSkillCatalogMarkdown();
	const summaries = catalogSummaries(catalog);
	const groups = new Map<string, CatalogSkill[]>();

	for (const skill of loadOwnedSkills()) {
		const summary = summaries.get(skill.id);
		if (!summary) {
			throw new Error(
				`${skillsReadme} is missing a one-line summary for ${skill.id}.`,
			);
		}
		const separator = skill.id.indexOf("/");
		const directory = separator === -1 ? "" : skill.id.slice(0, separator);
		groups.set(directory, [
			...(groups.get(directory) ?? []),
			{ ...skill, summary },
		]);
	}

	return [...groups.entries()]
		.sort(([left], [right]) => {
			if (!left) return -1;
			if (!right) return 1;
			return left.localeCompare(right);
		})
		.map(([directory, skills]) => ({
			directory,
			path: directory ? `skills/${directory}/` : "skills/",
			skills: skills.sort((left, right) => left.name.localeCompare(right.name)),
			kind: "directory" as const,
		}));
}

export function loadPublishedRepositoryGroups(): SkillDirectoryGroup[] {
	const byRepository = new Map<string, CatalogSkill[]>();
	for (const skill of loadExternalPublishedSkills()) {
		byRepository.set(skill.repository, [
			...(byRepository.get(skill.repository) ?? []),
			{ ...skill, summary: skill.description },
		]);
	}
	return [...byRepository.entries()]
		.sort(([left], [right]) => left.localeCompare(right))
		.map(([repository, skills]) => ({
			directory: repository,
			path: `${repository}/skills/`,
			skills: skills.sort((left, right) => left.name.localeCompare(right.name)),
			kind: "repository" as const,
		}));
}

export function loadSkillWorkflowsMarkdown(): string {
	return readFileSync(workflowsDocument, "utf8");
}

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

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
const skillsRoot = resolve(repositoryRoot, "skills");
const sourceBase = "https://github.com/qiulinfan/qiulinfan.github.io/blob/main";

function skillFiles(directory: string): string[] {
	return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
		const path = resolve(directory, entry.name);
		if (entry.isDirectory()) return skillFiles(path);
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
			metadata[match[1]] = match[2] === ">" ? continuation.join(" ") : continuation.join("\n");
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

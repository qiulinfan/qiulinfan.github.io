import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import test from "node:test";

import {
	loadOwnedSkills,
	loadPublishedSkills,
	loadPublishedRepositoryGroups,
	loadSkillCatalogMarkdown,
	loadSkillDirectoryGroups,
	loadSkillWorkflowsMarkdown,
	orderSkillGroupsForDisplay,
} from "../src/utils/skill-sources.ts";

const repositoryRoot = fileURLToPath(new URL("../..", import.meta.url));
const communityRoot = join(repositoryRoot, "skills", "community");
const linkedRegistry = join(repositoryRoot, "skills", "linked-skill-repositories.tsv");
const publishedRegistry = join(repositoryRoot, "skills", "published-skill-repositories.tsv");

function skillAuthorities(directory) {
	return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
		if (entry.name.startsWith(".")) return [];
		const path = join(directory, entry.name);
		if (entry.isDirectory()) return skillAuthorities(path);
		return entry.name === "SKILL.md" ? [path] : [];
	});
}

test("the public skills list combines qlblog with owned published repositories only", () => {
	const skills = loadPublishedSkills();
	const allAuthorities = skillAuthorities(join(repositoryRoot, "skills"));
	const qlblogSkills = skills.filter(
		(skill) => skill.repository === "qiulinfan.github.io",
	);
	assert.equal(existsSync(communityRoot), false);
	assert.equal(existsSync(linkedRegistry), true);
	assert.equal(existsSync(publishedRegistry), true);
	assert.match(readFileSync(linkedRegistry, "utf8"), /community-skills/);
	assert.doesNotMatch(readFileSync(publishedRegistry, "utf8"), /community-skills/);
	assert.equal(qlblogSkills.length, allAuthorities.length);
	assert.equal(new Set(skills.map((skill) => skill.name)).size, skills.length);
	assert.equal(skills.every((skill) => skill.description.length > 0), true);
	assert.equal(qlblogSkills.every((skill) => skill.authority.startsWith("skills/") && skill.authority.endsWith("/SKILL.md")), true);
	assert.equal(skills.every((skill) => !skill.authority.includes("/.system/")), true);
	assert.equal(qlblogSkills.every((skill) => !skill.authority.startsWith("skills/community/")), true);
	assert.equal(qlblogSkills.every((skill) => skill.sourceHref.includes(`/blob/main/${skill.authority}`)), true);
	assert.equal(skills.some((skill) => skill.repository === "autoTA"), true);
	assert.equal(skills.some((skill) => skill.repository === "discrete-sprite-lab"), true);
	assert.equal(skills.some((skill) => skill.repository === "kgdistiller"), true);
	assert.equal(skills.some((skill) => skill.repository === "community-skills"), false);
	assert.equal(skills.some((skill) => skill.repository === "myprivateskills"), false);
});

test("the README catalog lists every visible Skill and owns the detail-page boundary", () => {
	const skills = loadPublishedSkills();
	const ownedSkills = loadOwnedSkills();
	const catalog = loadSkillCatalogMarkdown();
	const qlblogSkills = skills.filter(
		(skill) => skill.repository === "qiulinfan.github.io",
	);

	for (const skill of qlblogSkills) {
		assert.match(catalog, new RegExp(`\\./${skill.id.replaceAll("/", "\\/")}/`));
	}
	assert.equal(qlblogSkills.length, ownedSkills.length);
	assert.doesNotMatch(catalog, /## 私有与第三方来源/);
	assert.equal(ownedSkills.length > 0, true);
	assert.equal(
		ownedSkills.every((skill) => catalog.includes(`- [${skill.name}]`)),
		true,
	);
	assert.equal(
		ownedSkills.some((skill) => skill.name === "find-skill-skillhub"),
		false,
	);
	assert.equal(ownedSkills.some((skill) => skill.name === "pdf-editor"), false);
	assert.equal(
		ownedSkills.some((skill) => skill.name === "mermaid-diagram"),
		false,
	);
});

test("owned public repository groups are displayed while linked-only repositories stay hidden", () => {
	const groups = loadPublishedRepositoryGroups();
	assert.deepEqual(
		groups.map((group) => [group.directory, group.skills.length]),
		[
			["autoTA", 5],
			["discrete-sprite-lab", 2],
			["kgdistiller", 8],
		],
	);
	assert.equal(groups.every((group) => group.kind === "repository"), true);
	assert.equal(
		groups
			.flatMap((group) => group.skills)
			.every((skill) => skill.sourceHref.startsWith("https://github.com/qiulinfan/")),
		true,
	);
	assert.equal(groups.some((group) => group.directory === "community-skills"), false);
});

test("repository groups lead, semantic suites follow, and Other Skills stay last", () => {
	const [repository] = loadPublishedRepositoryGroups();
	const [suite] = loadSkillDirectoryGroups();
	const other = { ...suite, directory: "", path: "skills/", skills: [] };
	assert.deepEqual(
		orderSkillGroupsForDisplay([other, suite, repository]).map((group) =>
			group.kind === "repository" ? `repo:${group.directory}` : `dir:${group.directory || "other"}`,
		),
		[`repo:${repository.directory}`, "dir:multica-collaboration", "dir:other"],
	);
});

test("the public catalog dynamically groups every owned Skill without a community group", () => {
	const groups = loadSkillDirectoryGroups();
	const expectedMembership = loadOwnedSkills()
		.map((skill) => {
			const separator = skill.id.indexOf("/");
			return {
				directory: separator === -1 ? "" : skill.id.slice(0, separator),
				id: skill.id,
			};
		})
		.sort((left, right) => left.id.localeCompare(right.id));
	const actualMembership = groups
		.flatMap((group) =>
			group.skills.map((skill) => ({
				directory: group.directory,
				id: skill.id,
			})),
		)
		.sort((left, right) => left.id.localeCompare(right.id));

	assert.deepEqual(actualMembership, expectedMembership);
	assert.equal(groups.every((group) => group.skills.length > 0), true);
	assert.equal(groups.some((group) => group.directory === "community"), false);
	assert.deepEqual(
		groups.map((group) => [group.directory, group.skills.length]),
		[["multica-collaboration", 3]],
	);
	assert.equal(
		groups
			.flatMap((group) => group.skills)
			.every((skill) => skill.summary.length > 0),
		true,
	);
});

test("the Markdown-authored public workflows reference real published Skills", () => {
	const workflows = loadSkillWorkflowsMarkdown();
	const workflowHrefs = [
		...workflows.matchAll(/\]\(([^)]+)\)/g),
	].map((match) => match[1]);
	const skillIds = [
		...workflows.matchAll(/\]\(#skill-([a-z0-9-]+)\)/g),
	].map((match) => match[1]);
	const publishedSkillNames = new Set(
		loadPublishedSkills().map((skill) => skill.name),
	);
	const workflowCount = (workflows.match(/^## /gm) ?? []).length;
	const diagramCount = (
		workflows.match(
			/```mermaid\r?\nflowchart[ \t]+(?:TB|TD|BT|RL|LR)\b/g,
		) ?? []
	).length;

	assert.ok(workflowCount > 0);
	assert.equal(diagramCount, workflowCount);
	assert.equal(workflowHrefs.every((href) => href.startsWith("#skill-")), true);
	assert.equal(skillIds.every((skillId) => publishedSkillNames.has(skillId)), true);
	assert.equal(
		existsSync(join(repositoryRoot, "site/src/data/skill-workflows.yaml")),
		false,
	);
});

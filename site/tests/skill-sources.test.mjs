import assert from "node:assert/strict";
import { existsSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join, sep } from "node:path";
import test from "node:test";

import {
	loadOwnedSkills,
	loadPublishedSkills,
	loadSkillCatalogMarkdown,
	loadSkillDirectoryGroups,
	loadSkillWorkflowsMarkdown,
} from "../src/utils/skill-sources.ts";

const repositoryRoot = fileURLToPath(new URL("../..", import.meta.url));
const communityRoot = `${join(repositoryRoot, "skills", "community")}${sep}`;

function skillAuthorities(directory) {
	return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
		if (entry.name.startsWith(".")) return [];
		const path = join(directory, entry.name);
		if (entry.isDirectory()) return skillAuthorities(path);
		return entry.name === "SKILL.md" ? [path] : [];
	});
}

test("the public skills list includes personal Skills and excludes community authorities", () => {
	const skills = loadPublishedSkills();
	const allAuthorities = skillAuthorities(join(repositoryRoot, "skills"));
	const communityAuthorities = allAuthorities.filter((path) => path.startsWith(communityRoot));
	const publishableAuthorities = allAuthorities.filter((path) => !path.startsWith(communityRoot));
	assert.equal(communityAuthorities.length > 0, true);
	assert.equal(skills.length, publishableAuthorities.length);
	assert.equal(new Set(skills.map((skill) => skill.name)).size, skills.length);
	assert.equal(skills.every((skill) => skill.description.length > 0), true);
	assert.equal(skills.every((skill) => skill.authority.startsWith("skills/") && skill.authority.endsWith("/SKILL.md")), true);
	assert.equal(skills.every((skill) => !skill.authority.includes("/.system/")), true);
	assert.equal(skills.every((skill) => !skill.authority.startsWith("skills/community/")), true);
	assert.equal(skills.every((skill) => skill.sourceHref.includes(`/blob/main/${skill.authority}`)), true);
});

test("the README catalog lists every visible Skill and owns the detail-page boundary", () => {
	const skills = loadPublishedSkills();
	const ownedSkills = loadOwnedSkills();
	const catalog = loadSkillCatalogMarkdown();

	for (const skill of skills) {
		assert.match(catalog, new RegExp(`\\./${skill.id.replaceAll("/", "\\/")}/`));
	}
	assert.equal(skills.length, ownedSkills.length);
	assert.doesNotMatch(catalog, /## 社区来源/);
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
	assert.equal(
		groups
			.flatMap((group) => group.skills)
			.every((skill) => skill.summary.length > 0),
		true,
	);
});

test("the Markdown-authored workflows reference real qlblog Skills", () => {
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

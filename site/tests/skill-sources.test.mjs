import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import {
	loadOwnedSkills,
	loadPublishedSkills,
	loadSkillCatalogMarkdown,
	loadSkillDirectoryGroups,
	loadSkillWorkflowsMarkdown,
} from "../src/utils/skill-sources.ts";

const repositoryRoot = new URL("../..", import.meta.url).pathname;

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
	const communityAuthorities = allAuthorities.filter((path) => path.includes("/skills/community/"));
	const publishableAuthorities = allAuthorities.filter((path) => !path.includes("/skills/community/"));
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

test("the public catalog mirrors real Skill directories without a community group", () => {
	const groups = loadSkillDirectoryGroups();
	assert.deepEqual(
		groups.map((group) => group.directory),
		["", "gamemaker", "kgdistiller", "notes"],
	);
	assert.deepEqual(
		groups.map((group) => group.skills.length),
		[3, 5, 5, 2],
	);
	assert.equal(groups.some((group) => group.directory === "community"), false);
	assert.equal(
		groups.flatMap((group) => group.skills).every((skill) => skill.summary.length > 0),
		true,
	);
});

test("kgdistiller discovery skills delegate to the vendored canonical skills", () => {
	for (const name of ["query-kgdistiller", "ingest-kgdistiller"]) {
		const entryPath = join(repositoryRoot, "skills", "kgdistiller", name, "SKILL.md");
		const canonicalPath = join(repositoryRoot, "vendor", "kgdistiller", "skills", name, "SKILL.md");
		const entry = readFileSync(entryPath, "utf8");
		const canonical = readFileSync(canonicalPath, "utf8");
		assert.match(entry, new RegExp(`vendor/kgdistiller/skills/${name}/SKILL\\.md`));
		assert.match(canonical, new RegExp(`name: ${name}`));
		assert.equal(entry.match(/^description: (.+)$/m)?.[1], canonical.match(/^description: (.+)$/m)?.[1]);
	}
});

test("knowledge Skills keep extraction, query, and ingestion responsibilities separate", () => {
	const exportSkill = readFileSync(join(repositoryRoot, "skills/kgdistiller/extract-and-export-notes/SKILL.md"), "utf8");
	const paperSkill = readFileSync(join(repositoryRoot, "skills/kgdistiller/extract-paper-concepts/SKILL.md"), "utf8");
	const querySkill = readFileSync(join(repositoryRoot, "vendor/kgdistiller/skills/query-kgdistiller/SKILL.md"), "utf8");
	const ingestSkill = readFileSync(join(repositoryRoot, "vendor/kgdistiller/skills/ingest-kgdistiller/SKILL.md"), "utf8");

	for (const extractor of [exportSkill, paperSkill]) {
		assert.match(extractor, /\$query-kgdistiller/);
		assert.match(extractor, /\$ingest-kgdistiller/);
		assert.doesNotMatch(extractor, /python3 knowledge\/kgd\.py (?:apply|sync|reconcile|agent)/);
	}
	assert.match(querySkill, /Keep the boundary read-only/);
	assert.doesNotMatch(querySkill, /python3 knowledge\/kgd\.py (?:apply|sync|reconcile)/);
	assert.match(ingestSkill, /kgdistiller ingest plan REQUEST\.json/);
	assert.match(ingestSkill, /kgdistiller ingest apply REQUEST\.json/);
	assert.doesNotMatch(ingestSkill, /python3 knowledge\/kgd\.py (?:apply|sync|reconcile)/);
	assert.equal(existsSync(join(repositoryRoot, "skills/kgdistiller/kgdistiller-distill/SKILL.md")), false);
});

test("the Markdown-authored workflows reference real Skills and preserve knowledge boundaries", () => {
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
		workflows.match(/```mermaid\nflowchart LR/g) ?? []
	).length;

	assert.ok(workflowCount > 0);
	assert.equal(diagramCount, workflowCount);
	assert.equal(workflowHrefs.every((href) => href.startsWith("#skill-")), true);
	assert.equal(skillIds.every((skillId) => publishedSkillNames.has(skillId)), true);
	for (const status of ["known", "partial", "new", "uncertain", "conflict"]) {
		assert.match(workflows, new RegExp(status));
	}
	assert.match(workflows, /默认流程不修改个人知识库/);
	assert.match(workflows, /明确要求导入/);
	assert.equal(
		existsSync(join(repositoryRoot, "site/src/data/skill-workflows.yaml")),
		false,
	);
});

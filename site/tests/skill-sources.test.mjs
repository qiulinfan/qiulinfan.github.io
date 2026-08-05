import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";

import { loadPublishedSkills } from "../src/utils/skill-sources.ts";

const repositoryRoot = new URL("../..", import.meta.url).pathname;

function skillAuthorities(directory) {
	return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
		if (entry.name.startsWith(".")) return [];
		const path = join(directory, entry.name);
		if (entry.isDirectory()) return skillAuthorities(path);
		return entry.name === "SKILL.md" ? [path] : [];
	});
}

test("the public skills list is generated from every visible local SKILL.md authority", () => {
	const skills = loadPublishedSkills();
	const authorities = skillAuthorities(join(repositoryRoot, "skills"));
	assert.equal(skills.length, authorities.length);
	assert.equal(new Set(skills.map((skill) => skill.name)).size, skills.length);
	assert.equal(skills.every((skill) => skill.description.length > 0), true);
	assert.equal(skills.every((skill) => skill.authority.startsWith("skills/") && skill.authority.endsWith("/SKILL.md")), true);
	assert.equal(skills.every((skill) => !skill.authority.includes("/.system/")), true);
	assert.equal(skills.every((skill) => skill.sourceHref.includes(`/blob/main/${skill.authority}`)), true);
});

test("kgdistiller discovery skills delegate to the vendored canonical skills", () => {
	for (const name of ["query-kgdistiller", "ingest-kgdistiller"]) {
		const entryPath = join(repositoryRoot, "skills", name, "SKILL.md");
		const canonicalPath = join(repositoryRoot, "vendor", "kgdistiller", "skills", name, "SKILL.md");
		const entry = readFileSync(entryPath, "utf8");
		const canonical = readFileSync(canonicalPath, "utf8");
		assert.match(entry, new RegExp(`vendor/kgdistiller/skills/${name}/SKILL\\.md`));
		assert.match(canonical, new RegExp(`name: ${name}`));
		assert.equal(entry.match(/^description: (.+)$/m)?.[1], canonical.match(/^description: (.+)$/m)?.[1]);
	}
});

test("knowledge Skills keep extraction, query, and ingestion responsibilities separate", () => {
	const exportSkill = readFileSync(join(repositoryRoot, "skills/export-typst-math-notes/SKILL.md"), "utf8");
	const paperSkill = readFileSync(join(repositoryRoot, "skills/extract-paper-concepts/SKILL.md"), "utf8");
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
	assert.equal(existsSync(join(repositoryRoot, "skills/kgdistiller-distill/SKILL.md")), false);
});

import assert from "node:assert/strict";
import { readdirSync } from "node:fs";
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

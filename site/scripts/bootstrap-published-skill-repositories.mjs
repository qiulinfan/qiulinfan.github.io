import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, isAbsolute, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const registryPath = resolve(
	repositoryRoot,
	"skills/published-skill-repositories.tsv",
);

const repositories = readFileSync(registryPath, "utf8")
	.split(/\r?\n/)
	.map((line) => line.trimEnd())
	.filter((line) => line.trim() && !line.trimStart().startsWith("#"))
	.map((line) => {
		const fields = line.split("\t");
		if (fields.length !== 6 || fields.some((field) => !field.trim())) {
			throw new Error(
				`${registryPath} requires six non-empty tab-separated fields per row.`,
			);
		}
		const [name, cloneUrl, sourceUrl, checkout, skillRoot, ref] = fields;
		if (isAbsolute(checkout) || checkout.startsWith("~")) {
			throw new Error(`Published checkout must be relative to qlblog: ${checkout}`);
		}
		if (!cloneUrl.startsWith("https://github.com/qiulinfan/")) {
			throw new Error(`Published repository must use the owner's public HTTPS clone URL: ${name}`);
		}
		if (!sourceUrl.startsWith("https://github.com/qiulinfan/")) {
			throw new Error(`Published repository must use the owner's public HTTPS source URL: ${name}`);
		}
		return { name, cloneUrl, checkout, skillRoot, ref };
	});

for (const repository of repositories) {
	const checkoutRoot = resolve(repositoryRoot, repository.checkout);
	const skillRoot = resolve(checkoutRoot, repository.skillRoot);
	if (existsSync(skillRoot)) {
		console.log(`ready: ${repository.name} -> ${checkoutRoot}`);
		continue;
	}
	if (existsSync(checkoutRoot)) {
		throw new Error(
			`Published repository checkout exists but its Skill root is missing: ${skillRoot}`,
		);
	}
	execFileSync(
		"git",
		[
			"clone",
			"--depth",
			"1",
			"--branch",
			repository.ref,
			repository.cloneUrl,
			checkoutRoot,
		],
		{ stdio: "inherit" },
	);
	if (!existsSync(skillRoot)) {
		throw new Error(`Cloned repository is missing its Skill root: ${skillRoot}`);
	}
}

console.log(`PUBLISHED_SKILL_REPOSITORIES_OK (${repositories.length})`);

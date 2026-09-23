// The homepage mounts external repositories ("docks") listed in docks.json at the
// homepage repository root. Each dock is rendered by the adapter in
// site/src/docks/<id>/. Callers pass the homepage root explicitly because this
// module runs both in plain Node scripts and inside the bundled Astro build.
import { existsSync, readFileSync } from "node:fs";
import { isAbsolute, resolve } from "node:path";

export interface Dock {
	id: string;
	repository: string;
	ref: string;
	checkout: string;
}

const cached = new Map<string, Dock[]>();

export function loadDocks(homepageRoot: string): Dock[] {
	const hit = cached.get(homepageRoot);
	if (hit) return hit;
	const registryPath = resolve(homepageRoot, "docks.json");
	const payload = JSON.parse(readFileSync(registryPath, "utf8")) as { docks?: unknown };
	if (!Array.isArray(payload.docks)) {
		throw new Error(`${registryPath} must contain a "docks" array.`);
	}
	const ids = new Set<string>();
	const docks = payload.docks.map((entry) => {
		const { id, repository, ref, checkout } = (entry ?? {}) as Partial<Dock>;
		if (typeof id !== "string" || !/^[a-z][a-z0-9-]*$/.test(id)) {
			throw new Error(`Dock ids must match ^[a-z][a-z0-9-]*$: ${JSON.stringify(id)}`);
		}
		if (ids.has(id)) throw new Error(`Duplicate dock id: ${id}`);
		ids.add(id);
		if (typeof repository !== "string" || !/^https:\/\/github\.com\/[\w.-]+\/[\w.-]+$/.test(repository) || repository.endsWith(".git")) {
			throw new Error(`Dock ${id} must name a public GitHub repository URL without .git: ${repository}`);
		}
		if (typeof ref !== "string" || !ref.trim()) throw new Error(`Dock ${id} must name a ref.`);
		if (typeof checkout !== "string" || !checkout.trim() || isAbsolute(checkout) || checkout.startsWith("~")) {
			throw new Error(`Dock ${id} must use a checkout path relative to the homepage root.`);
		}
		return { id, repository, ref, checkout };
	});
	cached.set(homepageRoot, docks);
	return docks;
}

export function findDock(homepageRoot: string, id: string): Dock {
	const dock = loadDocks(homepageRoot).find((candidate) => candidate.id === id);
	if (!dock) throw new Error(`docks.json does not register the ${id} dock.`);
	return dock;
}

export function dockRoot(homepageRoot: string, id: string): string {
	const root = resolve(homepageRoot, findDock(homepageRoot, id).checkout);
	if (!existsSync(root)) {
		throw new Error(`The ${id} dock is not checked out at ${root}. Run make docks-bootstrap.`);
	}
	return root;
}

export function dockSourceHref(dock: Dock, path: string): string {
	return `${dock.repository}/blob/${dock.ref}/${encodeURI(path)}`;
}

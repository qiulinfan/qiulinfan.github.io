.PHONY: docks-bootstrap blog-install blog-dev blog-build blog-preview blog-check

docks-bootstrap:
	@node site/scripts/bootstrap-docks.mjs

blog-install:
	cd site && corepack pnpm install --frozen-lockfile

blog-dev:
	cd site && corepack pnpm dev

blog-build:
	cd site && corepack pnpm build

blog-preview:
	cd site && corepack pnpm preview

blog-check:
	cd site && corepack pnpm check

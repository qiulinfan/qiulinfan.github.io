.PHONY: agents-guidance agents-check skills-published-bootstrap docks-bootstrap blog-install blog-new blog-dev blog-build blog-preview blog-check

agents-guidance:
	@install/agents/build-guidance.sh

agents-check:
	@install/agents/build-guidance.sh --check

skills-published-bootstrap:
	@node site/scripts/bootstrap-published-skill-repositories.mjs

docks-bootstrap:
	@node site/scripts/bootstrap-docks.mjs

blog-install:
	cd site && corepack pnpm install --frozen-lockfile

blog-new:
	@test -n "$(NAME)" || (echo "用法: make blog-new NAME=my-first-post" && exit 1)
	cd site && corepack pnpm new-post "$(NAME)"

blog-dev:
	cd site && corepack pnpm dev

blog-build:
	cd site && corepack pnpm build

blog-preview:
	cd site && corepack pnpm preview

blog-check:
	cd site && corepack pnpm check

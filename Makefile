.PHONY: blog-install blog-new blog-dev blog-build blog-preview blog-check knowledge-build knowledge-check knowledge-search

KNOWLEDGE := notes/math/knowledge/scripts/knowledge.py

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

knowledge-build:
	@python3 $(KNOWLEDGE) build --repo-root .

knowledge-check:
	@python3 $(KNOWLEDGE) check --repo-root .

knowledge-search:
	@test -n "$(QUERY)" || (echo '用法: make knowledge-search QUERY="conditional expectation"' && exit 1)
	@python3 $(KNOWLEDGE) search "$(QUERY)" --repo-root .

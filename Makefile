.PHONY: blog-install blog-new blog-dev blog-build blog-preview blog-check knowledge-build knowledge-subject knowledge-course knowledge-file knowledge-check knowledge-search

KNOWLEDGE := knowledge/scripts/knowledge.py

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
	@python3 $(KNOWLEDGE) --repo-root . sync

knowledge-subject:
	@test -n "$(SUBJECT)" || (echo '用法: make knowledge-subject SUBJECT=math' && exit 1)
	@python3 $(KNOWLEDGE) --repo-root . sync --subject "$(SUBJECT)"

knowledge-course:
	@test -n "$(COURSE)" || (echo '用法: make knowledge-course COURSE=measure-theory' && exit 1)
	@python3 $(KNOWLEDGE) --repo-root . sync --course "$(COURSE)"

knowledge-file:
	@test -n "$(FILE)" || (echo '用法: make knowledge-file FILE=notes/math/measure-theory/chapters/01-sigma-algebra-与-measure.typ' && exit 1)
	@python3 $(KNOWLEDGE) --repo-root . sync --file "$(FILE)"

knowledge-check:
	@python3 $(KNOWLEDGE) --repo-root . check

knowledge-search:
	@test -n "$(QUERY)" || (echo '用法: make knowledge-search QUERY="conditional expectation"' && exit 1)
	@python3 $(KNOWLEDGE) --repo-root . search "$(QUERY)"

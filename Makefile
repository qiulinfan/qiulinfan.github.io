.PHONY: blog-install blog-new blog-dev blog-build blog-preview blog-check notes-source-check kgdistiller-update knowledge-build knowledge-subject knowledge-course knowledge-file knowledge-check knowledge-search knowledge-serve

KGDISTILLER := python3 knowledge/kgd.py

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

notes-source-check:
	@python3 notes/scripts/check_source_policy.py --repo-root .

kgdistiller-update:
	@git submodule update --init --remote --merge vendor/kgdistiller

knowledge-build:
	@$(KGDISTILLER) sync

knowledge-subject:
	@test -n "$(SUBJECT)" || (echo '用法: make knowledge-subject SUBJECT=math' && exit 1)
	@$(KGDISTILLER) sync --subject "$(SUBJECT)"

knowledge-course:
	@test -n "$(COURSE)" || (echo '用法: make knowledge-course COURSE=measure-theory' && exit 1)
	@$(KGDISTILLER) sync --course "$(COURSE)"

knowledge-file:
	@test -n "$(FILE)" || (echo '用法: make knowledge-file FILE=notes/math/measure-theory/chapters/01-sigma-algebra-与-measure.typ' && exit 1)
	@$(KGDISTILLER) sync --file "$(FILE)"

knowledge-check: notes-source-check
	@$(KGDISTILLER) check

knowledge-search:
	@test -n "$(QUERY)" || (echo '用法: make knowledge-search QUERY="conditional expectation"' && exit 1)
	@$(KGDISTILLER) search "$(QUERY)"

knowledge-serve:
	@$(KGDISTILLER) serve

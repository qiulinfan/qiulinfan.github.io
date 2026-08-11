.PHONY: blog-install blog-new blog-dev blog-build blog-preview blog-check notes-source-check knowledge-export-check knowledge-authoring-check knowledge-build knowledge-subject knowledge-course knowledge-file knowledge-check knowledge-search knowledge-context knowledge-agent-status knowledge-candidate knowledge-align knowledge-compare knowledge-propose knowledge-ingest-plan knowledge-ingest-apply knowledge-serve

KGDISTILLER ?= kgdistiller
KGDISTILLER_INSTANCE := $(KGDISTILLER) --repo-root .

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

knowledge-build:
	@$(KGDISTILLER_INSTANCE) sync

knowledge-subject:
	@test -n "$(SUBJECT)" || (echo '用法: make knowledge-subject SUBJECT=math' && exit 1)
	@$(KGDISTILLER_INSTANCE) sync --subject "$(SUBJECT)"

knowledge-course:
	@test -n "$(COURSE)" || (echo '用法: make knowledge-course COURSE=measure-theory' && exit 1)
	@$(KGDISTILLER_INSTANCE) sync --course "$(COURSE)"

knowledge-file:
	@test -n "$(FILE)" || (echo '用法: make knowledge-file FILE=notes/math/measure-theory/chapters/01-sigma-algebra-与-measure.typ' && exit 1)
	@$(KGDISTILLER_INSTANCE) sync --file "$(FILE)"

knowledge-export-check:
	@python3 knowledge/export/site/verify_export.py knowledge/export/site
	@cd site && node tests/knowledge-export.test.mjs

knowledge-authoring-check:
	@$(KGDISTILLER_INSTANCE) check

knowledge-check: notes-source-check knowledge-export-check

knowledge-search:
	@test -n "$(QUERY)" || (echo '用法: make knowledge-search QUERY="conditional expectation"' && exit 1)
	@$(KGDISTILLER_INSTANCE) search "$(QUERY)"

knowledge-context:
	@test -n "$(QUERY)" || (echo '用法: make knowledge-context QUERY="conditional expectation"' && exit 1)
	@$(KGDISTILLER_INSTANCE) agent context "$(QUERY)" --graph-strategy hybrid

knowledge-agent-status:
	@$(KGDISTILLER_INSTANCE) agent status

knowledge-candidate:
	@test -n "$(CANDIDATE)" || (echo 'CANDIDATE 不能为空' && exit 1)
	@test -n "$(SNAPSHOT)" || (echo 'SNAPSHOT 不能为空' && exit 1)
	@$(KGDISTILLER_INSTANCE) candidate build "$(CANDIDATE)" --output "$(SNAPSHOT)"

knowledge-align:
	@test -n "$(SNAPSHOT)" || (echo '用法: make knowledge-align SNAPSHOT=knowledge/build/paper.snapshot.json NAME=paper' && exit 1)
	@test -n "$(NAME)" || (echo 'NAME 不能为空' && exit 1)
	@$(KGDISTILLER_INSTANCE) agent align "$(SNAPSHOT)" --output "knowledge/build/reviews/$(NAME).alignment.json"

knowledge-compare:
	@test -n "$(SNAPSHOT)" || (echo '用法: make knowledge-compare SNAPSHOT=knowledge/build/paper.snapshot.json' && exit 1)
	@$(KGDISTILLER_INSTANCE) agent compare "$(SNAPSHOT)"

knowledge-propose:
	@test -n "$(SNAPSHOT)" || (echo 'SNAPSHOT 不能为空' && exit 1)
	@test -n "$(AUTHORITY)" || (echo 'AUTHORITY 不能为空' && exit 1)
	@test -n "$(NAME)" || (echo 'NAME 不能为空' && exit 1)
	@$(KGDISTILLER_INSTANCE) agent propose "$(SNAPSHOT)" --target-authority "$(AUTHORITY)" \
		--output "knowledge/build/reviews/$(NAME).proposal.json" \
		--delta-output "knowledge/build/reviews/$(NAME).delta.json"

knowledge-ingest-plan:
	@test -n "$(REQUEST)" || (echo 'REQUEST 不能为空' && exit 1)
	@test -n "$(PLAN)" || (echo 'PLAN 不能为空' && exit 1)
	@$(KGDISTILLER_INSTANCE) ingest plan "$(REQUEST)" --output "$(PLAN)"

knowledge-ingest-apply:
	@test -n "$(REQUEST)" || (echo 'REQUEST 不能为空' && exit 1)
	@test -n "$(RECEIPT)" || (echo 'RECEIPT 不能为空' && exit 1)
	@$(KGDISTILLER_INSTANCE) ingest apply "$(REQUEST)" --receipt "$(RECEIPT)"

knowledge-serve:
	@$(KGDISTILLER_INSTANCE) serve

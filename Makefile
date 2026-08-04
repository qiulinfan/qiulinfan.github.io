.PHONY: blog-install blog-new blog-dev blog-build blog-preview blog-check notes-source-check kgdistiller-update knowledge-build knowledge-subject knowledge-course knowledge-file knowledge-workflow-check knowledge-check knowledge-search knowledge-context knowledge-agent-status knowledge-align knowledge-compare knowledge-propose knowledge-reconcile knowledge-serve

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

knowledge-workflow-check:
	@python3 knowledge/workflow.py $(if $(CHANGED_FROM),--changed-from "$(CHANGED_FROM)",)

knowledge-check: notes-source-check knowledge-workflow-check
	@$(KGDISTILLER) check

knowledge-search:
	@test -n "$(QUERY)" || (echo '用法: make knowledge-search QUERY="conditional expectation"' && exit 1)
	@$(KGDISTILLER) search "$(QUERY)"

knowledge-context:
	@test -n "$(QUERY)" || (echo '用法: make knowledge-context QUERY="conditional expectation"' && exit 1)
	@$(KGDISTILLER) agent context "$(QUERY)" --graph-strategy hybrid

knowledge-agent-status:
	@$(KGDISTILLER) agent status

knowledge-align:
	@test -n "$(SNAPSHOT)" || (echo '用法: make knowledge-align SNAPSHOT=knowledge/build/paper.snapshot.json NAME=paper' && exit 1)
	@test -n "$(NAME)" || (echo 'NAME 不能为空' && exit 1)
	@$(KGDISTILLER) agent align "$(SNAPSHOT)" --output "knowledge/build/reviews/$(NAME).alignment.json"

knowledge-compare:
	@test -n "$(SNAPSHOT)" || (echo '用法: make knowledge-compare SNAPSHOT=knowledge/build/paper.snapshot.json' && exit 1)
	@$(KGDISTILLER) agent compare "$(SNAPSHOT)"

knowledge-propose:
	@test -n "$(SNAPSHOT)" || (echo 'SNAPSHOT 不能为空' && exit 1)
	@test -n "$(AUTHORITY)" || (echo 'AUTHORITY 不能为空' && exit 1)
	@test -n "$(NAME)" || (echo 'NAME 不能为空' && exit 1)
	@$(KGDISTILLER) agent propose "$(SNAPSHOT)" --target-authority "$(AUTHORITY)" \
		--output "knowledge/build/reviews/$(NAME).proposal.json" \
		--delta-output "knowledge/build/reviews/$(NAME).delta.json"

knowledge-reconcile:
	@test -n "$(SNAPSHOT)" || (echo 'SNAPSHOT 不能为空' && exit 1)
	@test -n "$(CANDIDATE_ID)" || (echo 'CANDIDATE_ID 不能为空' && exit 1)
	@test -n "$(TARGET_ID)" || (echo 'TARGET_ID 不能为空' && exit 1)
	@test -n "$(EVIDENCE)" || (echo 'EVIDENCE 不能为空' && exit 1)
	@$(KGDISTILLER) reconcile alignment "$(SNAPSHOT)" "$(CANDIDATE_ID)" "$(TARGET_ID)" \
		--evidence "$(EVIDENCE)" --justification "$(or $(JUSTIFICATION),manual-domain-review)"

knowledge-serve:
	@$(KGDISTILLER) serve

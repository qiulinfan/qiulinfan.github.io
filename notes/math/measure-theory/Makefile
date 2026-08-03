.PHONY: all release export web web-check extras-web extras-web-check pdf extras-pdf watch knowledge-sync

TYPST := typst
TOOLCHAIN := ../toolchain
SKILL := ../../../skills/export-typst-math-notes
KNOWLEDGE := ../../../knowledge/scripts/knowledge.py
REPO_ROOT := ../../..
BUILD := build/typst
EXPORTS := exports

all: release

release: export web-check extras-web-check

export:
	@python3 $(KNOWLEDGE) --repo-root $(REPO_ROOT) sync --course measure-theory
	@python3 $(TOOLCHAIN)/scripts/export_course.py \
		--document main=main.typ \
		--document extras=extras.typ \
		--root ../.. \
		--output $(EXPORTS) \
		--build $(BUILD)/export

knowledge-sync:
	@python3 $(KNOWLEDGE) --repo-root $(REPO_ROOT) sync --course measure-theory

web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../.. --features html --format html \
		main.typ $(BUILD)/index.html 2>$(BUILD)/index.log || \
		{ cat $(BUILD)/index.log >&2; exit 1; }

web-check: web
	@python3 $(SKILL)/scripts/check_web.py $(BUILD)/index.html \
		--expected-nodes 173 --expected-diagrams 0

extras-web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../.. --features html --format html \
		extras.typ $(BUILD)/extras.html 2>$(BUILD)/extras.log || \
		{ cat $(BUILD)/extras.log >&2; exit 1; }

extras-web-check: extras-web
	@python3 $(SKILL)/scripts/check_web.py $(BUILD)/extras.html \
		--expected-nodes 0 --expected-diagrams 0

pdf:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../.. main.typ $(BUILD)/main.pdf

extras-pdf:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../.. extras.typ $(BUILD)/extras.pdf

watch:
	@mkdir -p $(BUILD)
	@$(TYPST) watch --root ../.. --features html --format html \
		main.typ $(BUILD)/index.html

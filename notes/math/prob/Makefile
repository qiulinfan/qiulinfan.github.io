.PHONY: all release export web web-check homeworks-web homeworks-web-check watch knowledge-sync

TYPST := typst
TOOLCHAIN := ../toolchain
SKILL := ../../../skills/export-typst-math-notes
KNOWLEDGE := ../../../knowledge/scripts/knowledge.py
REPO_ROOT := ../../..
BUILD := build/typst
EXPORTS := exports

all: release

release: knowledge-sync web-check homeworks-web-check

export:
	@python3 $(KNOWLEDGE) --repo-root $(REPO_ROOT) sync --course probability
	@python3 $(TOOLCHAIN)/scripts/export_course.py \
		--document notes=main.typ \
		--document homeworks=homeworks.typ \
		--root ../.. \
		--output $(EXPORTS) \
		--build $(BUILD)/export

knowledge-sync:
	@python3 $(KNOWLEDGE) --repo-root $(REPO_ROOT) sync --course probability

web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../.. --features html --format html \
		main.typ $(BUILD)/index.html 2>$(BUILD)/index.log || \
		{ cat $(BUILD)/index.log >&2; exit 1; }

web-check: web
	@python3 $(SKILL)/scripts/check_web.py $(BUILD)/index.html \
		--expected-nodes 93 --expected-diagrams 14

homeworks-web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../.. --features html --format html \
		homeworks.typ $(BUILD)/homeworks.html 2>$(BUILD)/homeworks.log || \
		{ cat $(BUILD)/homeworks.log >&2; exit 1; }

homeworks-web-check: homeworks-web
	@python3 $(SKILL)/scripts/check_web.py $(BUILD)/homeworks.html \
		--expected-nodes 0 --expected-diagrams 0

watch:
	@mkdir -p $(BUILD)
	@$(TYPST) watch --root ../.. --features html --format html \
		main.typ $(BUILD)/index.html

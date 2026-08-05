.PHONY: all release export web web-check homeworks-web homeworks-web-check watch knowledge-sync knowledge-curate

TYPST := typst
TOOLCHAIN := ../toolchain
SKILL := ../../../skills/extract-and-export-notes
REPO_ROOT := ../../..
KGDISTILLER := python3 $(REPO_ROOT)/knowledge/kgd.py
BUILD := build/typst
EXPORTS := exports

all: release

release: knowledge-curate web-check homeworks-web-check

export: knowledge-curate
	@python3 $(TOOLCHAIN)/scripts/export_course.py \
		--document notes=main.typ \
		--document homeworks=homeworks.typ \
		--root ../.. \
		--output $(EXPORTS) \
		--build $(BUILD)/export

knowledge-sync:
	@$(KGDISTILLER) sync --course probability

knowledge-curate: knowledge-sync
	@$(MAKE) -C $(REPO_ROOT) knowledge-workflow-check

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

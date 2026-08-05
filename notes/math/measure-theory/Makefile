.PHONY: all release export web web-check extras-web extras-web-check watch knowledge-sync knowledge-curate

TYPST := typst
TOOLCHAIN := ../toolchain
SKILL := ../../../skills/extract-and-export-notes
REPO_ROOT := ../../..
KGDISTILLER := python3 $(REPO_ROOT)/knowledge/kgd.py
BUILD := build/typst
EXPORTS := exports

all: release

release: knowledge-curate web-check extras-web-check

export: knowledge-curate
	@python3 $(TOOLCHAIN)/scripts/export_course.py \
		--document main=main.typ \
		--document extras=extras.typ \
		--root ../.. \
		--output $(EXPORTS) \
		--build $(BUILD)/export

knowledge-sync:
	@$(KGDISTILLER) sync --course measure-theory

knowledge-curate: knowledge-sync
	@$(MAKE) -C $(REPO_ROOT) knowledge-workflow-check

web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../.. --features html --format html \
		main.typ $(BUILD)/index.html 2>$(BUILD)/index.log || \
		{ cat $(BUILD)/index.log >&2; exit 1; }

web-check: web
	@python3 $(SKILL)/scripts/check_web.py $(BUILD)/index.html \
		--expected-nodes 178 --expected-diagrams 0

extras-web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../.. --features html --format html \
		extras.typ $(BUILD)/extras.html 2>$(BUILD)/extras.log || \
		{ cat $(BUILD)/extras.log >&2; exit 1; }

extras-web-check: extras-web
	@python3 $(SKILL)/scripts/check_web.py $(BUILD)/extras.html \
		--expected-nodes 0 --expected-diagrams 0

watch:
	@mkdir -p $(BUILD)
	@$(TYPST) watch --root ../.. --features html --format html \
		main.typ $(BUILD)/index.html

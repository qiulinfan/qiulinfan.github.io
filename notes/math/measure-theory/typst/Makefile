.PHONY: all release pdf web web-check watch extras extras-pdf extras-web extras-web-check check check-extras export export-main export-extras export-check

TYPST := typst
TOOLCHAIN := ../../toolchain/typst-template
SKILL := ../../../../skills/export-typst-math-notes
BUILD := ../build/typst
EXPORTS := ../exports

all: release

release: export web-check extras-web-check

pdf:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../../.. main.typ $(BUILD)/main.pdf

web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../../.. --features html --format html \
		main.typ $(BUILD)/index.html

web-check: web
	@python3 $(SKILL)/scripts/check_web.py $(BUILD)/index.html \
		--expected-nodes 302 --expected-diagrams 0

watch:
	@mkdir -p $(BUILD)
	@$(TYPST) watch --root ../../.. --features html --format html \
		main.typ $(BUILD)/index.html

extras: extras-pdf extras-web check-extras extras-web-check

extras-pdf:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../../.. extras.typ $(BUILD)/extras.pdf

extras-web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../../.. --features html --format html \
		extras.typ $(BUILD)/extras.html

extras-web-check: extras-web
	@python3 $(SKILL)/scripts/check_web.py $(BUILD)/extras.html \
		--expected-nodes 7 --expected-diagrams 0

export: export-main export-extras

export-main:
	@python3 $(TOOLCHAIN)/scripts/export.py main.typ \
		--root ../../.. \
		--output $(EXPORTS)/main \
		--build $(BUILD)/export/main

export-extras:
	@python3 $(TOOLCHAIN)/scripts/export.py extras.typ \
		--root ../../.. \
		--output $(EXPORTS)/extras \
		--build $(BUILD)/export/extras

check:
	@$(TYPST) eval \
		'let records = query(selector(metadata)).map(it => it.value); \
		let documents = records.filter(node => node.schema == "qlnotes-document-v1"); \
		let nodes = records.filter(node => node.schema == "qlnotes-v1"); \
		assert(documents.len() == 1); \
		assert(nodes.len() > 0); \
		assert(nodes.all(node => node.id != none)); \
		assert(nodes.map(node => node.id).dedup().len() == nodes.len()); \
		(records: records.len(), nodes: nodes.len())' \
		--root ../../.. --features html --target html --in main.typ \
		--format json >/dev/null

check-extras:
	@$(TYPST) eval \
		'let records = query(selector(metadata)).map(it => it.value); \
		let documents = records.filter(node => node.schema == "qlnotes-document-v1"); \
		let nodes = records.filter(node => node.schema == "qlnotes-v1"); \
		assert(documents.len() == 1); \
		assert(nodes.len() > 0); \
		assert(nodes.all(node => node.id != none)); \
		assert(nodes.map(node => node.id).dedup().len() == nodes.len()); \
		(records: records.len(), nodes: nodes.len())' \
		--root ../../.. --features html --target html --in extras.typ \
		--format json >/dev/null

export-check: export
	@python3 $(SKILL)/scripts/check_exports.py \
		$(EXPORTS)/main --source main.typ --full
	@python3 $(SKILL)/scripts/check_exports.py \
		$(EXPORTS)/extras --source extras.typ --full

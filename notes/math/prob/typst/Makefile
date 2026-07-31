.PHONY: all pdf web homeworks export export-notes export-homeworks check export-check

TYPST := typst
TOOLCHAIN := ../../toolchain/typst-template
BUILD := ../build/typst
EXPORTS := ../exports

all: pdf web check

pdf:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../../.. main.typ $(BUILD)/main.pdf

web:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../../.. --features html --format html \
		main.typ $(BUILD)/index.html

homeworks:
	@mkdir -p $(BUILD)
	@$(TYPST) compile --root ../../.. homeworks.typ $(BUILD)/homeworks.pdf

export: export-notes export-homeworks

export-notes:
	@python3 $(TOOLCHAIN)/scripts/export.py main.typ \
		--root ../../.. \
		--output $(EXPORTS)/notes \
		--build $(BUILD)/export/notes

export-homeworks:
	@python3 $(TOOLCHAIN)/scripts/export.py homeworks.typ \
		--root ../../.. \
		--output $(EXPORTS)/homeworks \
		--build $(BUILD)/export/homeworks

check:
	@$(TYPST) eval \
		'let records = query(selector(metadata)).map(it => it.value); \
		let documents = records.filter(node => node.schema == "qlnotes-document-v1"); \
		let nodes = records.filter(node => node.schema == "qlnotes-v1"); \
		assert(documents.len() == 1); \
		assert(nodes.len() > 0); \
		assert(nodes.all(node => node.id != none)); \
		(records: records.len(), nodes: nodes.len())' \
		--root ../../.. --features html --target html --in main.typ \
		--format json >/dev/null

export-check: export
	@python3 ../../../../skills/export-typst-math-notes/scripts/check_exports.py \
		$(EXPORTS)/notes --source main.typ --full
	@python3 ../../../../skills/export-typst-math-notes/scripts/check_exports.py \
		$(EXPORTS)/homeworks --source homeworks.typ --full

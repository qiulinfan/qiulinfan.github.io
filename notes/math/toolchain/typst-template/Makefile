.PHONY: all setup doctor pdf web watch check export export-roundtrip export-check spikes clean

TYPST := typst
SOURCE := demo.typ
DIST := dist

all: pdf web check

setup:
	@sh scripts/setup.sh

doctor:
	@command -v python3 >/dev/null
	@command -v typst >/dev/null
	@command -v pandoc >/dev/null
	@command -v rsvg-convert >/dev/null
	@command -v lualatex >/dev/null
	@command -v latexmk >/dev/null
	@command -v biber >/dev/null
	@command -v rg >/dev/null
	@echo "QLNotes toolchain is ready."

pdf:
	@mkdir -p $(DIST)
	@$(TYPST) compile $(SOURCE) $(DIST)/qlnotes-demo.pdf

web:
	@mkdir -p $(DIST)
	@$(TYPST) compile --features html --format html $(SOURCE) $(DIST)/index.html

watch:
	@mkdir -p $(DIST)
	@$(TYPST) watch --features html --format html $(SOURCE) $(DIST)/index.html

check:
	@$(TYPST) eval \
		'let records = query(selector(metadata)).map(it => it.value); \
		let documents = records.filter(node => node.schema == "qlnotes-document-v1"); \
		let nodes = records.filter(node => node.schema == "qlnotes-v1"); \
		assert(documents.len() == 1); \
		assert(nodes.len() > 0); \
		assert(nodes.all(node => node.id != none)); \
		(records: records.len(), nodes: nodes.len())' \
		--features html --target html --in $(SOURCE) --format json >/dev/null

export:
	@python3 scripts/export.py demo.typ \
		--output exports/demo \
		--build dist/export-build/demo

export-roundtrip:
	@python3 scripts/export.py experiments/export-roundtrip.typ \
		--output exports/roundtrip \
		--build dist/export-build/roundtrip

export-check: doctor export export-roundtrip
	@mkdir -p dist/latex-demo dist/latex-roundtrip
	@cd exports/demo/latex && latexmk -gg -lualatex \
		-interaction=nonstopmode -halt-on-error -file-line-error \
		-outdir=../../../dist/latex-demo main.tex >/dev/null
	@cd exports/roundtrip/latex && latexmk -gg -lualatex \
		-interaction=nonstopmode -halt-on-error -file-line-error \
		-outdir=../../../dist/latex-roundtrip main.tex >/dev/null
	@pandoc exports/demo/markdown/main.md \
		--from markdown+yaml_metadata_block+tex_math_dollars+fenced_divs+pipe_tables+link_attributes \
		--to json >/dev/null
	@pandoc exports/roundtrip/markdown/main.md \
		--from markdown+yaml_metadata_block+tex_math_dollars+fenced_divs+pipe_tables+link_attributes \
		--to json >/dev/null
	@! rg -n 'data:image/' exports/demo exports/roundtrip
	@echo "Editable LaTeX and Markdown exports validated."

spikes:
	@mkdir -p $(DIST)/experiments
	@$(TYPST) compile --root . --format pdf experiments/aliases-smoke.typ $(DIST)/experiments/aliases-smoke.pdf
	@$(TYPST) compile --root . --features html --format html experiments/aliases-smoke.typ $(DIST)/experiments/aliases-smoke.html
	@$(TYPST) compile --root . --format pdf experiments/cetz-smoke.typ $(DIST)/experiments/cetz-smoke.pdf
	@$(TYPST) compile --root . --features html --format html experiments/cetz-smoke.typ $(DIST)/experiments/cetz-smoke.html
	@$(TYPST) compile --root . --format pdf experiments/probability-support-region.typ $(DIST)/experiments/probability-support-region.pdf
	@$(TYPST) compile --root . --features html --format html experiments/probability-support-region.typ $(DIST)/experiments/probability-support-region.html
	@$(TYPST) compile --root . --format pdf experiments/export-roundtrip.typ $(DIST)/experiments/export-roundtrip.pdf
	@$(TYPST) compile --root . --features html --format html experiments/export-roundtrip.typ $(DIST)/experiments/export-roundtrip.html

clean:
	@if [ -d "$(DIST)" ]; then find "$(DIST)" -mindepth 1 -delete; fi

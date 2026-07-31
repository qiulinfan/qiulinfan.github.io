.PHONY: all main chapters docs clean clean-all

PYTHON := python3
ifeq ($(OS),Windows_NT)
PYTHON := python
endif

all: chapters

main:
	@mkdir -p build
	@lualatex -interaction=nonstopmode -halt-on-error -file-line-error -output-directory=build main.tex
	@lualatex -interaction=nonstopmode -halt-on-error -file-line-error -output-directory=build main.tex
	@mv build/main.pdf main.pdf

chapters:
	@$(PYTHON) scripts/build_chapters.py

docs:
	@$(PYTHON) scripts/generate_docs_pages.py
	@$(PYTHON) scripts/generate_mkdocs_config.py
	@mkdocs build

clean:
	-@rm -f build/*.aux build/*.log build/*.out build/*.toc
	-@rm -f build/*.fdb_latexmk build/*.fls build/*.synctex.gz
	-@rm -f build/*.bcf build/*.run.xml build/*.bbl build/*.blg
	-@rm -f build/*_main.tex

clean-all: clean
	-@rm -f build/*.pdf main.pdf docs/*.pdf

# QLNotes toolchain

This is the single shared build and presentation layer for Typst-first math
notes. Course directories contain only authority content, authored assets,
bibliography data, a small Makefile, and committed chapter exports.

```text
toolchain/
├── qlnotes.typ             # PDF and HTML presentation
├── math-aliases.typ        # shared math notation
├── web.css                 # responsive web style
├── scripts/
│   ├── export.py           # one complete Typst entry -> temporary snapshots
│   ├── export_course.py    # split entry snapshots into chapter files
│   └── migrate_latex.py    # legacy migration helper
├── filters/qlnotes.lua     # semantic Pandoc mapping
└── latex/                  # standalone LaTeX class and template
```

Install or check the four runtime dependencies once:

```sh
make setup
make doctor
```

Daily commands live in each migrated course root:

```sh
make export              # chapter .tex/.md snapshots + graph refresh
make web-check           # local ignored HTML + basic UTF-8/structure check
make                     # both of the above, plus secondary web entries
```

Typst is the only authority. `export_course.py` compiles each entry once, splits
the semantic Markdown and LaTeX at real level-one chapters, and writes a flat,
browsable result:

```text
course/exports/
├── latex/
│   ├── <entry>--<chapter>.tex
│   ├── assets/
│   └── shared class/bibliography files
└── markdown/
    ├── index.md
    ├── <entry>--<chapter>.md
    ├── .assets/
    └── reference.bib
```

No whole-book `main.tex` or `main.md` is committed. HTML, PDFs, and exporter
intermediates stay under the ignored course `build/` directory. GitHub Actions
builds HTML from Typst and publishes only the Pages artifact.

CeTZ remains the diagram authority. Markdown uses Typora-compatible SVG files;
LaTeX uses the corresponding vector PDF figure assets. The exporter never
reconstructs TikZ.

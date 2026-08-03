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
│   ├── migrate_knowledge_markers.py # one-time metadata migration
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
make export              # scoped graph sync + chapter .tex/.md snapshots
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

Knowledge markers are authored directly in Typst:

```typst
#definition(title: [#kn[Radon–Nikodym theorem]])[
  ...
]

Later, #ref[Radon–Nikodym theorem] links back to that unique
definition and becomes a backlink in the global graph.
```

The authored `#kn` name is globally unique; `#ref` may occur anywhere and uses
the same name. Stable machine IDs are generated and maintained outside the
source. Graph synchronization also preserves plain searchable text and compiles
the original Typst name to inline MathML for the knowledge website. Formal
statements without `#kn` are not graph nodes. Synchronize the graph at
repository, subject, course, or individual-file granularity:

```sh
make knowledge-build
make knowledge-subject SUBJECT=math
make knowledge-course COURSE=measure-theory
make knowledge-file FILE=notes/math/measure-theory/chapters/01-sigma-algebra-与-measure.typ
```

If a file-scoped sync no longer sees a previously active `#kn`, its source is
marked orphaned. The node metadata and semantic edges remain available until the
same name is defined in its new authoritative location.

CeTZ remains the diagram authority. Markdown uses Typora-compatible SVG files;
LaTeX uses the corresponding vector PDF figure assets. The exporter never
reconstructs TikZ.

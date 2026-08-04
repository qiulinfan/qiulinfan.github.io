# QLNotes toolchain

This is the shared build and presentation layer for Typst-first math notes.
The repository-wide graph also accepts maintained Markdown and LaTeX authority;
those format adapters live in the pinned `vendor/kgdistiller` submodule, while
LaTeX web output reuses this toolchain through an ignored Typst intermediate.

The public site's palette authority is `site/src/styles/variables.styl`.
`web.css` is its single standalone Notes projection, shared by every Typst
export and copied into every generated LaTeX-to-Typst project. Do not create
course-local palettes. Keep its light, dark, and automatic theme roles aligned
with the site and verify them with `site/tests/theme-contract.test.mjs`.
Published standalone pages expose the same Light, Dark, and Auto preference as
the Astro shell; `site/scripts/install-note-artifacts.mjs` installs that runtime
and its back/forward style-recovery guard.

```text
toolchain/
├── qlnotes.typ             # HTML presentation
├── math-aliases.typ        # shared math notation
├── web.css                 # responsive web style
├── scripts/
│   ├── export.py           # one complete Typst entry -> temporary snapshots
│   ├── export_course.py    # split entry snapshots into chapter files
│   ├── convert_latex_project.py # ElegantBook -> previewable Typst project
│   ├── export_latex_web.py # maintained LaTeX -> synced graph -> Typst HTML
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

For a Typst-first course, Typst is its authority. `export_course.py` compiles
each entry once, splits the semantic Markdown and LaTeX at real level-one
chapters, and writes a flat, ignored local result:

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

No generated snapshot is committed. HTML and exporter intermediates stay under
ignored `build/` or `exports/` directories. PDF files are forbidden anywhere
below `notes/`. GitHub Actions builds HTML from Typst and publishes only the
Pages artifact.

Markdown is intentionally graph-oriented and lossy. Semantic statements,
examples, proofs, remarks, notes, and solutions become ordinary `>` blockquotes;
knowledge definitions become `--[[Dominated convergence theorem]]--` and
references become `[[Dominated convergence theorem]]`. Inline math uses
`$...$`; every display formula uses line-delimited `$$` blocks.

Knowledge markers are authored directly in Typst:

```typst
#definition(title: [#kn[Norm] and #kn[Semi-norm]])[
  ...
]

Later, #ref[Norm] links back to that unique
definition and becomes a backlink in the global graph.
```

Each authored `#kn` identifies one independently reusable concept and is
globally unique; a title that defines several concepts contains several `#kn`
markers. `#ref` may occur anywhere and uses the same name. A file gets a
meaningful `#ref` when it directly uses an immediate prerequisite whose
authority is another file; same-file concepts and transitive ancestors do not
need one.

Direct Markdown authorities use `--[[Name]]--` for the canonical `kn` and
`[[Name]]` or `[[Name|display]]` for refs. Direct LaTeX authorities use
`\kn{Name}` and `\knref{Name}`; `migrate_latex.py` preserves these as Typst
`#kn`/`#ref` during web conversion. A configured directory or file scope may
mix all three suffixes.

For an ElegantBook LaTeX course, pass its `main.tex` to
`convert_latex_project.py`. The synchronized adapter expands direct chapter
inputs and creates an ignored self-contained Typst project with `main.typ`,
local QLNotes runtime, copied assets, and preview Makefile. Web export always
compiles that project; there is no independent LaTeX-to-HTML renderer.

The agent reads one complete changed file, preserves explicit markers, extracts
a concise source-grounded entry for every local node, and chooses direct typed
semantic edges. Scripts only scan and synchronize explicit markers, apply the
reviewed delta, and check deterministic invariants; the one-time
`migrate_knowledge_markers.py` helper is not part of daily ingestion. Stable
machine IDs are maintained outside the source. Synchronization preserves agent
entries, plain searchable names, and Typst-compiled inline MathML for the
knowledge website. Formal statements without `#kn` are not graph nodes.

The changed-file workflow ends with scoped curation validation:

```sh
python3 knowledge/kgd.py scan --file path/to/chapter.typ
python3 knowledge/kgd.py apply knowledge/build/reviewed-delta.json
python3 knowledge/kgd.py sync --file path/to/chapter.typ
python3 knowledge/kgd.py curate-check --file path/to/chapter.typ
```

Direct Markdown site publication runs a format-wide version automatically:

```sh
python3 knowledge/kgd.py publish --format markdown
```

It synchronizes every configured Markdown authority before checking entries and
required refs. Semantic entries and edges still come only from an agent that has
read the source and existing graph.

The graph can also be synchronized at repository, subject, course, or
individual-file granularity:

```sh
make knowledge-build
make knowledge-subject SUBJECT=math
make knowledge-course COURSE=measure-theory
make knowledge-file FILE=notes/math/measure-theory/chapters/01-sigma-algebra-与-measure.typ
```

If a file-scoped sync no longer sees a previously active `#kn`, its source is
marked orphaned. The node metadata and semantic edges remain available until the
same name is defined in its new authoritative location.

CeTZ remains the diagram authority. Markdown and the web use SVG; editable
LaTeX snapshots use portable derived PNG assets so export never creates a PDF
inside `notes/`. The exporter never reconstructs TikZ.

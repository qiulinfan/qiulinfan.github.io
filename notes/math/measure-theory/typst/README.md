# Measure Theory Typst authority

This directory is the editable authority for MATH 597. `main.typ` preserves the
exact chapter/homework order of the legacy `main.tex`; `extras.typ` collects the
five legacy sources that were present but disabled or never included.

The content files import the shared QLNotes template themselves, so every file
remains directly editable and can be compiled independently from the repository
without per-file environment setup.

```sh
make                 # export snapshots and check both HTML entry points
make export          # editable LaTeX and Markdown snapshots only
make web-check       # main HTML UTF-8/basic structure check
make extras-web-check
make watch           # rebuild local HTML while writing (foreground process)
```

Generated HTML and any optional local PDFs live in `../build/typst/` and are
ignored by Git. The editable snapshots live in `../exports/{main,extras}/`.
GitHub Pages rebuilds the HTML from Typst and publishes it at
<https://qiulinfan.github.io/qlblog/notes/math/measure-theory/>.

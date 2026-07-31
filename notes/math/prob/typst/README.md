# Probability Typst authority

`main.typ` is the authoritative source for the five course-note chapters.
`homeworks.typ` is the authoritative source for all six worked homework files.
The legacy LaTeX files remain as the migration baseline.

```sh
make                 # export snapshots and check both HTML entry points
make export          # editable LaTeX and Markdown snapshots only
make web-check
make homeworks-web-check
```

Generated HTML, optional local PDFs, and intermediate files stay under the ignored
`../build/typst/` directory. Editable LaTeX and Markdown snapshots are written
to `../exports/notes/` and `../exports/homeworks/`. Each snapshot is
self-contained: its `main.tex` or `main.md` can be opened and edited without
the Typst toolchain. Regeneration always starts from the Typst authority.
GitHub Pages publishes the notes at
<https://qiulinfan.github.io/qlblog/notes/math/probability/>.

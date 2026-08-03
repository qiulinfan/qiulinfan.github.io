# Measure theory notes

MATH 597: Real Analysis, Winter 2025. The Typst authority now lives directly in
this course directory: [`main.typ`](main.typ) contains the course sequence and
[`extras.typ`](extras.typ) contains supplementary material. Chapters, homeworks,
and extras remain independently readable `.typ` files.

```sh
make export              # split LaTeX / Markdown exports + graph refresh
make web-check           # main HTML UTF-8 and structure check
make extras-web-check    # supplementary HTML check
make                     # complete lightweight publication workflow
```

All committed snapshots share one `exports/` directory:

```text
exports/
├── latex/<entry>--<chapter>.tex
└── markdown/<entry>--<chapter>.md
```

There is no committed whole-book export. Local HTML, PDFs, and intermediates are
written only under ignored `build/`; GitHub Actions publishes the HTML directly
to Pages.

Published notes: <https://qiulinfan.github.io/notes/math/measure-theory/>

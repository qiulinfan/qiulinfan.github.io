# Mathematics notes

数学笔记按课程独立维护。已迁移课程采用 Typst-first；尚未迁移的历史课程继续
保留原 LaTeX 工程，直到逐门完成转换。

## Typst-first 课程

Probability 与 Measure Theory 的课程根目录就是可直接编辑的 Typst 工程：

```text
course/
├── main.typ / secondary.typ
├── chapters/*.typ
├── homeworks/*.typ
├── assets/
├── reference.bib
├── Makefile
└── exports/
    ├── latex/*.tex
    └── markdown/*.md
```

模板、数学 alias、网页样式和导出程序只维护一份，位于
[`toolchain/`](toolchain/README.md)。Typst 是唯一权威源；LaTeX 与 Markdown
按一级章节生成可编辑快照，不提交整本导出文件。

```sh
make export
make web-check
```

知识节点在 Typst 中用唯一的 `#kn[名称]` 标记，其他位置用
`#ref[名称]` 链回原定义。内部稳定 ID 由同步程序在源文件之外维护。全局图谱位于仓库根目录的 `knowledge/`；普通章节、
例题和未标记陈述不会自动成为节点。可用 `make knowledge-subject SUBJECT=math`、
`make knowledge-course COURSE=measure-theory` 或 `make knowledge-file FILE=...`
按不同粒度同步。

课程本地 HTML、PDF、编译中间文件和 `site/` 均被忽略。GitHub Actions 从
Typst 源构建 HTML，并只把构建产物发布到 GitHub Pages：

- Probability: <https://qiulinfan.github.io/qlblog/notes/math/probability/>
- Measure Theory: <https://qiulinfan.github.io/qlblog/notes/math/measure-theory/>

## 尚未迁移的 LaTeX 课程

现有 LaTeX 工程继续使用 ElegantBook 与 LuaLaTeX/latexmk；迁移前不要机械
套用 Typst 目录。当前主要历史工程包括：

- `advanced-linear-algebra/latex-note/`
- `multivariate-analysis/lec-note/`
- `numerical-linear-algebra/notes/`
- `pde-boundary-problems/latex-note/`
- `topological-manifolds/latex-note/`

所有课程都只提交可编辑源与必要原始资源；整本 PDF、章节 PDF、分页预览、
`build/` 和课程本地 `site/` 不进入版本控制。

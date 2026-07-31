# Mathematics notes

课程讲义型 LaTeX 工程统一采用
[`qiulinfan/localLatexenv`](https://github.com/qiulinfan/localLatexenv)
的 ElegantBook 与 LuaLaTeX/latexmk 工作流。当前同步基准为提交
`f62053086eec079f6c7db99eac23d9c66e28b63f`（2026-04-17）。

本地构建依赖 TeX Live（包含 `lualatex`、`latexmk` 与 `biber`）、
Python 3，以及 MkDocs Material。

## 标准目录

```text
course/
├── assets/                 # 图片与其他静态资源
├── chapters/               # 每个顶层章节一个 .tex 文件
├── docs/                   # 章节 PDF 与 MkDocs 页面
├── scripts/                # 章节和文档构建脚本
├── .vscode/settings.json   # LaTeX Workshop / LuaLaTeX
├── elegantbook.cls         # 与根模板同步的文档类
├── main.tex                # 唯一的整书入口
├── Makefile
└── reference.bib
```

`main.tex` 只保存课程元数据、课程特有宏包和章节顺序；正文放在
`chapters/`。图片路径始终相对于课程工程根目录。

## 统一命令

```bash
make          # 为 main.tex 中启用的章节生成独立 PDF
make main     # 生成整书 main.pdf
make docs     # 生成 MkDocs 页面并构建本地站点
make clean    # 清理 LaTeX 中间文件
make clean-all
```

`make docs` 只构建本地站点。这个仓库统一由根目录的 Astro 工程发布，
课程子目录不应单独执行 `mkdocs gh-deploy`。

版本控制中保留 `docs/` 下的章节 PDF；整书 `main.pdf` 以及 `build/`、
`site/` 等中间产物只保留在本地，不提交到 Git。

## 当前课程讲义工程

- `advanced-linear-algebra/latex-note/`
- `measure-theory/`
- `multivariate-analysis/lec-note/`
- `numerical-linear-algebra/notes/`
- `pde-boundary-problems/latex-note/`
- `prob/`
- `topological-manifolds/latex-note/`

作业、考试速查表和项目 proposal 属于不同文档类型，不要求使用本目录结构。

## Typst-first toolchain

新的单向导出工具链位于
[`toolchain/typst-template/`](toolchain/typst-template/README.md)。它以 Typst
为唯一权威源，并生成完整、可直接编辑的 LaTeX 与 Markdown 快照。

`prob/` 已完成首个全量迁移：五章讲义、六份作业、147 个知识图谱节点和
14 张 CeTZ 图均由 Typst 维护，并通过 PDF/HTML、Markdown 解析和独立
LuaLaTeX 编译验证。其他课程仍应按课程逐一清点、迁移和验收。

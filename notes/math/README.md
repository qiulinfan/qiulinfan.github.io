# Mathematics notes

课程讲义型 LaTeX 工程统一采用
[`qiulinfan/localLatexenv`](https://github.com/qiulinfan/localLatexenv)
的 ElegantBook 与 LuaLaTeX 工作流。当前同步基准为提交
`f62053086eec079f6c7db99eac23d9c66e28b63f`（2026-04-17）。

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

## 当前课程讲义工程

- `advanced-linear-algebra/latex-note/`
- `measure-theory/`
- `multivariate-analysis/lec-note/`
- `numerical-linear-algebra/notes/`
- `pde-boundary-problems/latex-note/`
- `prob/`
- `topological-manifolds/latex-note/`

作业、考试速查表和项目 proposal 属于不同文档类型，不要求使用本目录结构。

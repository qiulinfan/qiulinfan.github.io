# Probability notes

Math 525 概率论课程笔记以课程根目录的 [`main.typ`](main.typ) 与
[`homeworks.typ`](homeworks.typ) 为入口；正文分别位于 `chapters/` 和
`homeworks/`。这里不再保留一套并行的 LaTeX 权威源。

```sh
make export                 # 分章导出 LaTeX / Markdown，并刷新知识图谱
make web-check              # 检查讲义网页的 UTF-8 与基本结构
make homeworks-web-check    # 检查作业网页
make                        # 运行以上发布流程
```

可提交导出统一位于：

```text
exports/
├── latex/<entry>--<chapter>.tex
└── markdown/<entry>--<chapter>.md
```

`exports/markdown/index.md` 是轻量目录，不包含整本正文。Markdown 图形使用
`.assets/*.svg`；LaTeX 图形依赖位于 `exports/latex/assets/`。本地 HTML、
PDF 和所有中间文件只写入忽略的 `build/`。

网页：<https://qiulinfan.github.io/qlblog/notes/math/probability/>

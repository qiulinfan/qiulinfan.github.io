# Probability notes

Math 525 概率论课程笔记现以 [`typst/`](typst/README.md) 为唯一日常权威源。
五章课程讲义和六份作业解答都已迁移；原 `chapters/*.tex` 与 `main.tex`
保留为只读迁移基线。

## Typst 构建与导出

```bash
cd typst
make                 # 导出 LaTeX/Markdown，并检查两份 HTML
make export          # 只生成讲义、作业的 LaTeX/Markdown
make web-check       # 检查讲义网页的 UTF-8 与基本结构
make homeworks-web-check
```

本地 PDF、HTML 和中间文件写入忽略的 `build/typst/`。可提交、可直接编辑的
快照写入：

```text
exports/
├── notes/{latex,markdown}/
└── homeworks/{latex,markdown}/
```

Markdown 图使用 Typora 可直接显示的 `main.assets/*.svg`；LaTeX 使用对应的
图形依赖。重新导出会覆盖快照，需长期保留的修改必须回到 Typst。

发布页面：<https://qiulinfan.github.io/qlblog/notes/math/probability/>

## 旧 LaTeX 基线

旧工作流仍可用于迁移对照：

```bash
make main
```

整书 PDF、章节 PDF、分页预览图和所有中间产物都不提交。
旧 `scripts/convert_notes.py` 仅作历史工具，不再承担权威格式转换。

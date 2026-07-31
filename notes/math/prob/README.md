# Probability notes

Math 525 概率论课程笔记现以 [`typst/`](typst/README.md) 为唯一日常权威源。
五章课程讲义和六份作业解答都已迁移；原 `chapters/*.tex` 与 `main.tex`
保留为只读迁移基线。

## Typst 构建与导出

```bash
cd typst
make                 # 讲义 PDF、HTML 与语义检查
make homeworks       # 六份作业合集 PDF
make export          # 同时生成讲义、作业的 LaTeX/Markdown
make export-check    # 解析 Markdown，并独立编译两份 LaTeX
```

本地 PDF、HTML 和中间文件写入忽略的 `build/typst/`。可提交、可直接编辑的
快照写入：

```text
exports/
├── notes/{latex,markdown}/
└── homeworks/{latex,markdown}/
```

Markdown 图使用 Typora 可直接显示的 `main.assets/*.svg`；LaTeX 使用对应的
`assets/*.pdf`。重新导出会覆盖快照，需长期保留的修改必须回到 Typst。

## 旧 LaTeX 基线

旧工作流仍可用于迁移对照：

```bash
make main
```

整书 `main.pdf` 和所有中间产物不提交；`docs/` 下的章节 PDF 可按仓库约定提交。
旧 `scripts/convert_notes.py` 仅作历史工具，不再承担权威格式转换。

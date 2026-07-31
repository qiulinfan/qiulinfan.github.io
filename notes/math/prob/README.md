# Probability notes

Math 525 概率论课程笔记。LaTeX 目录结构和构建命令遵循
[`notes/math/README.md`](../README.md) 中的统一约定。

## 构建

```bash
make          # 为启用的章节生成 docs/*.pdf
make main     # 生成整书 main.pdf
make docs     # 生成并构建本地 MkDocs 页面
make clean
```

章节启用顺序由 [`main.tex`](main.tex) 中未注释的 `\input` 命令决定。
编译引擎为 LuaLaTeX。

## LaTeX / Markdown 转换

本课程额外保留了 `scripts/convert_notes.py`，用于在单个章节的 LaTeX
和 Markdown 之间做基础结构转换：

```bash
python3 scripts/convert_notes.py \
  chapters/01-combinatorics\&prob_space.tex \
  --direction tex-to-md
```

该脚本只处理常见标题、定理、列表、图片和数学环境，不是完整的
LaTeX/Markdown 解析器。转换后应人工检查结果。

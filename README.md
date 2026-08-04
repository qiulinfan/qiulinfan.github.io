# qiulinfan.github.io

个人知识与内容仓库，按内容类型分为三个顶层目录：

- [`notes/`](notes/): 只保存 Typst、Markdown、LaTeX 权威源及正文实际引用的轻量资产；知识图谱和网页均由这些源生成，不保存 PDF、课程归档或站点构建物。
- [`blogs/`](blogs/): 日常的一些知识分享和闲聊. (保证都是碎碎念
- [`skills/`](skills/)：个人积累和维护的 skills. (也有偷别人开源的, 会标明出处

个人主页、blog、notes 网页和知识图谱由 [`site/`](site/) 中的同一个 Fuwari/Astro 工程生成。全站视觉只在 [`site/src/styles/variables.styl`](site/src/styles/variables.styl) 中维护一次。

## 博客常用命令

```bash
# 新建 blogs/posts/typeshxt.md
make blog-new NAME=typeshxt

# 本地预览，保存 md 文件自动刷新
make blog-dev

# 检查并构建静态网站
make blog-check
make blog-build
```

首次使用或依赖变化后运行：

```bash
make blog-install
```

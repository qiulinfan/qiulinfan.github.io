# Blogs

这里是日常博客写作入口。文章均为 Markdown 或 MDX，存放在 [`posts/`](posts/)；该目录映射到 Fuwari 的文章源目录。

## 工作流

在仓库根目录运行：

```bash
make blog-new NAME=my-first-post
make blog-dev
```

然后编辑 `blogs/posts/my-first-post.md`，浏览器打开：

<http://localhost:4321/>

文章头部格式：

```yaml
---
title: 文章标题
published: 2026-07-13
description: 一句话摘要
image: ""
tags: [标签]
category: 分类
draft: false
lang: zh_CN
---
```

写完后检查并构建：

```bash
make blog-check
make blog-build
```

静态输出在 `site/dist/`。

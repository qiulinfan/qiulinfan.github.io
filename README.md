# qiulinfan.github.io

个人知识与内容仓库，按内容类型分为三个顶层目录：

- [`notes/`](notes/): 只保存 Typst、Markdown、LaTeX 权威源及正文实际引用的轻量资产；知识图谱和网页均由这些源生成，不保存 PDF、课程归档或站点构建物。
- [`blogs/`](blogs/): 日常的一些知识分享和闲聊. (保证都是碎碎念
- [`skills/`](skills/)：个人积累和维护的 skills. (也有偷别人开源的, 会标明出处

可复用的知识图谱蒸馏引擎通过 Git submodule 接入
[`vendor/kgdistiller/`](vendor/kgdistiller/)；本仓库只保存个人知识源、图谱配置、
确定性图谱快照与网站集成。首次克隆后运行：

```bash
git submodule update --init vendor/kgdistiller
```

kgdistiller 是主动跟随 `main` 的高频升级依赖；运行 `make kgdistiller-update` 会
同时更新引擎及其 query/ingest Skills。每次升级后提交实际解析到的 submodule
revision，使本地、干净克隆和 Pages 在单次运行中仍然可追溯。开发调试时可用
`KGDISTILLER_SRC` 显式覆盖。

个人主页、blog、notes、skills 页面和知识图谱由 [`site/`](site/) 中的同一个 Fuwari/Astro 工程生成。Skills 页面直接读取 [`skills/`](skills/) 下的 `SKILL.md`；其中 query/ingest 是通向 submodule 规范正文的发现入口。全站视觉只在 [`site/src/styles/variables.styl`](site/src/styles/variables.styl) 中维护一次。

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

知识图谱也可以只在本地浏览：

```bash
make knowledge-workflow-check
make knowledge-check
make knowledge-context QUERY="conditional expectation"
make knowledge-serve
```

笔记提取/入库闭环和论文默认不合并的联邦 GraphRAG 流程见
[`knowledge/WORKFLOW.md`](knowledge/WORKFLOW.md)。项目级 `.codex/config.toml` 已把
只读 kgdistiller MCP 接入 Codex；首次调用会从提交的图谱自动生成本地 SQLite 索引。

首次使用或依赖变化后运行：

```bash
make blog-install
```

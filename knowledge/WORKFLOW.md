# Agentic knowledge workflow

这个仓库把“权威源 → 语义图谱 → Agent 检索 → 网页”作为一个带门禁的闭环。
`.md`、`.typ`、`.tex` 正文始终是权威；图谱、SQLite、candidate snapshot 和 HTML
都是可重建投影。

## 日常修改与新建

1. 先在 `knowledge/sources.json` 中让文件路径命中且只命中一个 source glob。
2. 使用 `export-typst-math-notes` 读取完整文件和相关图邻域，决定 marker、ref、
   source-grounded entry 与直接语义边。
3. 依次运行 `scan → apply reviewed delta → sync → curate-check`。
4. 运行 `make knowledge-workflow-check`。它会拒绝：
   - 新的未注册 authority；
   - 同时命中多个 source 的文件；
   - 被修改但尚未注册的 legacy note；
   - 被修改却仍缺 entry/ref 或带 stale edge 的 pending authority。
5. 运行所属课程的 `make` 或 Markdown/LaTeX 发布命令，再运行
   `make knowledge-check && make blog-check && make blog-build`。

`knowledge/workflow-policy.json` 只记录迁移开始时已经存在的 legacy backlog，
以及有理由永不作为 authority 的工具链/asset。不能把新笔记加入 legacy 列表来
绕过 curation。完成一批旧笔记后，从对应 baseline 列表移除它们。

## 论文与外部研究图谱

论文图谱必须使用独立 namespace，并在导入个人图谱前走完整对齐：

```sh
make knowledge-align SNAPSHOT=knowledge/build/paper.snapshot.json NAME=paper
make knowledge-compare SNAPSHOT=knowledge/build/paper.snapshot.json
make knowledge-propose SNAPSHOT=knowledge/build/paper.snapshot.json \
  AUTHORITY=notes/research/paper.md NAME=paper
```

`agent align` 会同时使用 exact/alias、paper-scoped abbreviation、lexical/acronym、
typed graph consistency、PPR 和可选 embedding 证据，但只有明确身份或仍然新鲜的
reviewed mapping 能决定 identity。像 `AC` 这样的缩写不能写成无作用域全局 alias。

歧义经人工阅读论文证据后持久化：

```sh
make knowledge-reconcile \
  SNAPSHOT=knowledge/build/paper.snapshot.json \
  CANDIDATE_ID=ac \
  TARGET_ID=absolute-continuity-of-signed-measures \
  EVIDENCE="The paper explicitly defines AC relative to a measure."
```

决策写入提交的 `knowledge/alignments.json`，并绑定 candidate/target 内容指纹。
端点一旦改变，映射自动退回 review。随后按
`skills/export-typst-math-notes/references/research-ingestion.md` 的两阶段流程：先审查
marker 建议并同步真实 authority，再重新 propose、审查和 apply delta，最后通过
逐文件 curation、全局 workflow、graph 和网页构建。

## Agent 快速访问

提交的图谱是知识事实，`knowledge/build/knowledge.sqlite` 是被忽略的快速索引。
首次 `agent` 或 MCP 调用会从图谱自动创建索引，后续只在图谱或 alignment digest
变化时重建：

```sh
make knowledge-agent-status
make knowledge-context QUERY="How does a measure depend on a sigma algebra?"
```

项目的 `.codex/config.toml` 已注册只读 `kgdistiller` MCP。Codex 在受信任的项目中
可直接使用 `kg_resolve_concepts`、`kg_search`、`kg_ppr`、`kg_build_context`、
`kg_align_graph`、`kg_compare_graph` 和 `kg_create_proposal`，无需把完整图谱放进
模型上下文。

## 可复现性

日常命令和 CI 都只使用提交的 `vendor/kgdistiller` revision。相邻开发 checkout
不会被隐式加载；只有显式设置 `KGDISTILLER_SRC` 才会覆盖。升级使用
`make kgdistiller-update`，跑完两仓库测试后提交新的 submodule pointer。

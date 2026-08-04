# Agentic knowledge workflow

这个仓库把“权威源 → 候选图 → 外接大脑查询 → 审查后入库 → 网页”作为带门禁的
闭环。`.md`、`.typ`、`.tex` 正文始终是权威；图谱、SQLite、candidate snapshot 和
HTML 都是可重建投影。

当前跨 `qlblog`、`kgdistiller` 与 `solvablemodel` 的实现状态、Git 现场、未完成边界、
后续五阶段路线和验收标准见 [`HANDOFF.md`](HANDOFF.md)。

## 四个 Skill 的职责

- `export-typst-math-notes`：从 Git 改动和显式 marker 提取笔记候选图，委托查询、
  入库后导出网页；不直接读写个人图谱。
- `extract-paper-concepts`：通读论文并生成隔离候选图；查询之后只解释 new 和缺失的
  partial 知识，默认输出联邦快照而不合并个人图谱。
- `query-kgdistiller`：唯一只读查询/GraphRAG/对齐入口；不修改 source、alignment 或
  graph。
- `ingest-kgdistiller`：唯一个人知识库写入口；只执行已经审查的 source patch、entry、
  ref、alignment 和 edge 决策。

前两个是 qlblog 的领域 Skill；后两个的规范正文随 `vendor/kgdistiller` 升级，qlblog
中的同名目录只负责 Codex 发现。

## 日常修改与新建

1. 先在 `knowledge/sources.json` 中让文件路径命中且只命中一个 source glob。
2. `export-typst-math-notes` 读取完整改动 authority，从 Git diff 和用户 marker 提取
   source-backed candidate；它不能打开 graph JSONL、entry shard 或 SQLite。
3. 将整批候选交给 `query-kgdistiller`：
   - known → 写格式原生 ref，不生成新 entry；
   - new → 保留或增加 authority marker 与 entry；
   - partial → 只写缺失部分；
   - uncertain/conflict → 停止自动处理并等待 review。
4. 把 source diff、query digests、decision table 和 reviewed delta 交给
   `ingest-kgdistiller`。只有它能运行 reconcile/apply/sync/curate-check/check。
5. ingestion receipt 成功后，运行所属课程或 Markdown/LaTeX 发布命令，再执行
   `make knowledge-workflow-check && make knowledge-check && make blog-check && make blog-build`。

`knowledge/workflow-policy.json` 只记录迁移开始时已经存在的 legacy backlog，以及有
理由永不作为 authority 的工具链/asset。不能把新笔记加入 legacy 列表来绕过
curation。

## 论文与外部研究图谱

`extract-paper-concepts` 先完成论文覆盖和轻量 candidate graph：名称、论文局部别名、
论文角色、来源位置和直接 prerequisite，但不先写所有词条解释。然后把一个独立
`paper:<digest>` snapshot 交给 `query-kgdistiller`。

查询结果生成联邦快照：

- known 只保留论文角色和指向 personal node 的 exact bridge；
- partial 只解释个人知识中缺失的条件、角色、claim 或 relation；
- new 才生成完整 source-backed entry；
- conflict/uncertain 保留证据且不桥接。

默认流程不得修改 `knowledge/graph` 或 `knowledge/alignments.json`。只有用户明确要求
导入时，论文 Skill 才创建/更新注册的 research authority，把 known 写成 ref，并把
选中的 new/partial 知识交给 `ingest-kgdistiller`。论文局部缩写（如 `AC`）永远不能因
相似度成为全局 alias。

## Agent 快速访问

提交的图谱是知识事实，`knowledge/build/knowledge.sqlite` 是被忽略的快速索引。首次
Agent/MCP 查询会从图谱自动创建索引，后续只在图谱或 alignment digest 变化时重建。
`query-kgdistiller` 使用 `kg_resolve_concepts`、`kg_search`、`kg_build_context`、
`kg_align_graph` 和 `kg_compare_graph`，只把受预算限制的证据包放进模型上下文。

## 版本策略

kgdistiller 是高频升级依赖，而不是被冻结的副本。`make kgdistiller-update` 主动跟随
上游 `main`，同时带入 query/ingest Skill 的新版本；升级后必须跑两个仓库的兼容性
测试并提交新的 submodule pointer。一次 qlblog commit 仍记录实际使用的 revision，
从而同时满足“持续前进”和“单次运行可追溯”。

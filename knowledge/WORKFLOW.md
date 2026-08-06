# Agentic knowledge workflow

这个仓库把“权威源 → 候选图 → 外接大脑查询 → 审查后入库 → 网页”作为带门禁的
闭环。`.md`、`.typ`、`.tex` 正文始终是权威；图谱、SQLite、candidate snapshot 和
HTML 都是可重建投影。

当前跨 `qlblog`、`kgdistiller` 与 `solvablemodel` 的实现状态、Git 现场、未完成边界、
后续五阶段路线和验收标准见 [`HANDOFF.md`](HANDOFF.md)。

## 四个 Skill 的职责

- `extract-paper-markdown`：把论文网页或 PDF 变成页码可追溯的语义 Markdown；只对
  图表相关页面做定点多模态理解，不嵌图、不复刻版式、不生成知识图谱。
- `extract-and-export-notes`：`personal-note` 分支从 Git 改动和显式 marker 提取笔记
  候选图，委托查询、入库后导出网页；`research-paper` 分支从标准论文 Markdown 包
  生成只读联邦图，不修改个人图谱。
- `query-kgdistiller`：唯一只读查询/GraphRAG/对齐入口；不修改 source、alignment 或
  graph。
- `ingest-kgdistiller`：唯一个人知识库写入口；只执行已经审查的 source patch、entry、
  ref、alignment 和 edge 决策。

前两个是 qlblog 的领域 Skill；后两个的规范正文随 `vendor/kgdistiller` 升级，qlblog
中的同名目录只负责 Codex 发现。

## 日常修改与新建

1. 先在 `knowledge/sources.json` 中让文件路径命中且只命中一个 source glob。
2. `extract-and-export-notes` 读取完整改动 authority，从 Git diff 和用户 marker 提取
   source-backed `qlkg-candidate-graph-v1`；它不能打开 graph JSONL、entry shard 或
   SQLite。用 `make knowledge-candidate CANDIDATE=... SNAPSHOT=...` 生成并验证隔离
   snapshot，不能手写 envelope 或 digest。
3. 将完整 snapshot 交给 `query-kgdistiller`：
   - known → 写格式原生 ref，不生成新 entry；
   - new → 保留或增加 authority marker 与 entry；
   - partial → 只写缺失部分；
   - uncertain/conflict → 停止自动处理并等待 review。
4. 把 native source patch、完整预期 marker/ref 状态、query digests、decision table
   和 reviewed delta 交给 `ingest-kgdistiller`。先运行
   `make knowledge-ingest-plan REQUEST=... PLAN=...` 并 review；将 request 改为
   `apply`、重算 digest 后，再运行
   `make knowledge-ingest-apply REQUEST=... RECEIPT=...`。领域 Skill 不得自行调用
   `reconcile/apply/sync/curate-check/check`。
5. 只有 canonical receipt 为 `committed` 后，才运行所属课程或 Markdown/LaTeX 发布命令，再执行
   `make knowledge-workflow-check && make knowledge-check && make blog-check && make blog-build`。

`knowledge/workflow-policy.json` 只记录迁移开始时已经存在的 legacy backlog，以及有
理由永不作为 authority 的工具链/asset。不能把新笔记加入 legacy 列表来绕过
curation。

## 论文与外部研究图谱

对网页、DOI、标题或 PDF 输入，`extract-paper-markdown` 先定位规范且可合法访问的
全文，记录 landing/PDF URL、版本、页数和 SHA-256。它逐页提取正文，但只渲染 caption、
低文本、解析异常或含重要视觉对象的页面。输出 `paper.md`、`source.json`、规范 PDF 与
可选附件；正文保留原生公式和关键表格，每个图表只记录编号、页码、标题、语义摘要、
支撑结论和具体不确定项。Markdown 不嵌图，也不经过 TeX 转录或编译。

随后 `extract-and-export-notes` 的 `research-paper` 分支读取完整 Markdown 包，选择概念、
直接前置、假设、方法、核心结论与限制，写成 `qlkg-candidate-graph-v1`，通过 kgdistiller
builder 生成独立的 `paper:<digest>` snapshot，再交给 `query-kgdistiller`。查询前只写
名称、论文角色、精确来源与直接关系，不先生成通用解释。

查询结果生成联邦快照：

- known 只保留论文角色和指向 personal node 的 exact bridge；
- partial 只解释个人知识中缺失的条件、角色、claim 或 relation；
- new 才生成完整 source-backed entry；
- conflict/uncertain 保留证据且不桥接。

这一论文流程不得修改 `knowledge/graph`、`knowledge/alignments.json`、论文 Markdown
或网页，也不得调用 `ingest-kgdistiller`。导入论文知识是另一条需要重新授权和审查的
工作流，不是这个分支的可选尾声。论文局部缩写（如 `AC`）永远不能因相似度成为全局
alias。

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

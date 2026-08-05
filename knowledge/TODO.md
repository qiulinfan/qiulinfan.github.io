# 非阻塞质量与性能 TODO

> 状态日期：2026-08-05
>
> 范围：`kgdistiller`、`qlblog` 的知识工作流质量、性能和测试深度。
>
> 这些项目不是当前四 Skill 功能拆分的完成条件，也不授权论文知识导入、生产发布或部署。

本文只记录可以留待后续处理的质量与性能债务。功能缺口必须留在功能验收中，不能移入
本文后被视为“已经实现”。

## 性能

- 降低 100,000 knowledge-node 首次同步耗时。Apple A18 Pro / 8 GiB 参考机当前为
  `68.515 s`，最初探索目标为 `<60 s`。
- 降低同一 fixture 的峰值 RSS。当前 query/sync profile 为约 `2.37 GiB`，最初探索
  目标为 `<1 GiB`。
- 优化 100,000-node transaction staging、plan 和 apply。当前 plan/apply 分别约为
  `232.085 s` / `271.132 s`。
- 调查 source scan、hydrated graph、staging copy、SQLite rebuild 之间的重复常驻状态，
  优先采用流式解析、分批写入和更少的全图复制。
- 补充 SQLite、graph shards、journal/backup 和 canonical receipt 的磁盘占用基线。

当前复跑命令、机器信息、query p50/p95 和已校准 release envelope 见
[`vendor/kgdistiller/docs/performance.md`](../vendor/kgdistiller/docs/performance.md)。

## 检索与身份质量

- 建立独立 ambiguity corpus，覆盖多义缩写、跨语言名称、近义但不同概念、失效 mapping
  和 paper-local alias；未经 review 的 false identity merge 必须保持为 0。
- 扩展 `partial` / `conflict` 的结构化 claim coverage。目前确定性比较主要依赖身份、
  curation 状态、显式 claims 和已映射 edge；它不应被描述成通用语义等价证明。
- 在 1k / 10k / 100k 和不同 edge/ref 密度下记录 exact、alias、FTS、BFS、PPR、hybrid
  的 p50/p95，并验证 context tokens 不随全图规模线性增长。
- 增加 provider adapter 的可选离线评测，但保持 identity authority 与 deterministic core
  不依赖 embedding 或模型判断。

## 故障、安全与可观察性

- 增加可重复的磁盘不足/写满故障测试，验证 source、graph、alignment 和 journal 可恢复。
- 扩大并发 writer 竞争、reader generation、重复 request 和 receipt 大小的压力矩阵。
- 增加超大/畸形 JSON、MCP 参数、symlink/path 边界的组合 fuzz；保留现有稳定错误码。
- 让真实 Agent Skill evaluator 可记录实际 model、turns、duration、cost、mandatory-read
  trace 和 permission denial；不可观察步骤继续报告 finding，不能推定通过。
- 后续独立生产验收再覆盖 fresh clone、远程 submodule、CI 平台矩阵、备份恢复和升级回滚。

## 关闭规则

每一项关闭时必须附：可复跑命令、fixture、机器/运行时、before/after 数据、确定性验证和
对应 commit。不得通过放宽原始数字或省略失败 run 来关闭 TODO。

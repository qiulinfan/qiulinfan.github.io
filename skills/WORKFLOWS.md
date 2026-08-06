# Skill Workflows

单个 Skill 只描述一种可复用能力；这里记录多个 Skill 如何编排成可以交付结果的工具流。流程图和图下文字都是普通 Markdown，可以按需要增删节点、分支和说明，不受页面字段约束。

## 笔记进入知识库并发布 Web

```mermaid
flowchart LR
    Src["Git 改动<br/>原生 marker"] --> Ext["提取候选图"]
    Ext --> Ask["查询知识库"]
    Ask --> Gate{"身份状态"}
    Gate -->|known| Ref["复用 ref"]
    Gate -->|new / partial| Add["补充缺失知识"]
    Gate -->|uncertain / conflict| Stop["人工审查"]
    Ref --> Put["事务入库"]
    Add --> Put
    Put --> Web["发布 Web"]
```

[`extract-and-export-notes`](#skill-extract-and-export-notes) 只从 Git 改动和作者写下的 marker 构造候选图；[`query-kgdistiller`](#skill-query-kgdistiller) 负责识别已有知识，已知项只写 `ref`；审查通过后由 [`ingest-kgdistiller`](#skill-ingest-kgdistiller) 合入个人知识库，成功回执是 Web 发布的前置条件。

遇到 `uncertain` 或 `conflict` 时，流程停在审查门前，不猜测身份，也不为了自动发布而创建重复词条。

## Codex 原生 Subagent 生产工作流

```mermaid
flowchart LR
    Req["用户任务"] --> Contract["产物 / 权限 / 完成条件"]
    Contract --> Pick["选择最小 Agent Skill 集"]
    Pick --> Config{"可信 .codex/config.toml<br/>存在 agents roles?"}
    Config -->|是| Roles["选择标准配置角色<br/>读取 config_file"]
    Config -->|否| Shape{"按描述生成任务拓扑"}
    Roles --> Lead["Codex Coordinator"]
    Shape -->|单一边界| One["Fresh Codex Subagent"]
    Shape -->|独立或分阶段| Lead
    Lead --> A["Worker A<br/>专属 Skill / 写入边界"]
    Lead --> B["Worker B<br/>专属 Skill / 写入边界"]
    One --> Check["主 Agent 集成与独立验收"]
    A --> Lead
    B --> Lead
    Lead --> Check
```

[`codex-subagent-workflow`](#skill-codex-subagent-workflow) 只使用当前 Codex 会话的
原生 subagents，不通过 shell 或 API 再启动 Codex、Claude Code 或 OpenCode。
主 agent 先固定交付物、权限和完成条件，再检查可信主项目的 `.codex/config.toml`：
若 `[agents.<role>]` 已声明角色，就按标准描述、`config_file`、默认模型/推理强度和并发
限制选择最小角色集；只有没有自定义角色时才根据任务描述自动编排。配置损坏或当前
surface 无法选择已配置角色时明确失败，不悄悄退化。每个 worker 仍需指定最小 Skill、
上下文、写入所有权和依赖关系；独立任务可以有界并发，依赖任务顺序交接。Subagents
共享当前 runtime 与工作区，因此它们是新工作上下文而不是独立安全主体；最终 diff、
产物和 validators 始终由主 agent 集成并验收。这个流程只处理真实生产交付物。

## 单 Skill 原子与压力测试

```mermaid
flowchart LR
    Skill["一个目标 Skill"] --> Contract["固定 fixture / prompt / invariants"]
    Contract --> Count["运行次数：默认 1<br/>或用户指定 N"]
    Count --> Runtime{"明确要求外部进程 / 登录 / runtime?"}
    Runtime -->|否，默认| Copies["新 fixture + 新上下文"]
    Runtime -->|是| External["Claude Code / OpenCode<br/>隔离进程 run"]
    Copies --> T1["Native Codex Subagent 1"]
    Copies --> T2["Native Codex Subagent N"]
    T1 --> Evidence["逐 run 产物 / diff / 行为证据 / 耗时"]
    T2 --> Evidence
    External --> Evidence
    Evidence --> Verdict["主 Agent 独立判定"]
```

[`codex-subagent-testskill`](#skill-codex-subagent-testskill) 每个 contract 只测试一个
Skill，是单 Skill 测试默认入口，不承接生产交付。每个 run 使用新的 fixture copy 和
不继承对话历史的原生 Codex subagent；未指定次数时只运行一次，用户可指定正整数次数
重复同一 contract。重复测试默认串行以保持耗时可比，只有用户明确要求时才在可用
subagent slots 内有界并发。主 agent 记录每次运行与完整 harness 的 wall-clock 时间，
独立检查产物、workspace diff 和 validators，并区分 harness、behavior、artifact、safety
与 orchestration 失败。它提供行为与上下文隔离，不声称全新进程、登录、provider 或
文件系统隔离。

只有用户明确要求 Claude Code、OpenCode、跨 runtime 对比或全新进程/认证时，才改用
[`codex-external-agent-testskill`](#skill-codex-external-agent-testskill)。它的本机 profile
只配置这两个外部 evaluator，不包含 Codex target；首次使用或缓存被清理后必须重新
回答 runtime 与认证问题。

## 论文生成联邦知识快照

```mermaid
flowchart LR
    Input["网页 / DOI / PDF"] --> Find["确认规范 PDF"]
    Find --> Text["提取正文 / 公式"]
    Find --> Visual["定点理解图表页"]
    Text --> MD["可追溯 Markdown 包"]
    Visual --> MD
    MD --> Ext["research-paper 分支<br/>提取候选图"]
    Ext --> Ask["只读查询个人图谱"]
    Ask --> Gate{"身份状态"}
    Gate -->|known| Bridge["只建立 bridge"]
    Gate -->|new / partial| Entry["解释缺失知识"]
    Gate -->|uncertain / conflict| Review["保留证据"]
    Bridge --> Snap["联邦快照"]
    Entry --> Snap
    Review --> Snap
```

[`extract-paper-markdown`](#skill-extract-paper-markdown) 先从网页、DOI、标题或 PDF
定位规范全文，保留来源 hash 和页码映射，把正文、公式、结论、限制与附件转成语义
Markdown。它只渲染 caption、低文本、解析异常或含重要视觉对象的页面；每个图表在
Markdown 中只留下编号、页码、标题、内容摘要、支撑结论和不确定项，不嵌图、不复刻
版式，也不经过 TeX 编译；交付前还必须清理 HTML layout 与 Pandoc 数学转码残留。

随后 [`extract-and-export-notes`](#skill-extract-and-export-notes) 选择
`research-paper` 分支，复用同一套候选图、确定性 snapshot 和
[`query-kgdistiller`](#skill-query-kgdistiller) 对齐流程。已知概念只建立跨 namespace
bridge；`new` 与 `partial` 只解释未知或缺失部分；冲突与歧义保留证据。交付物是独立
论文图及学习顺序，不修改论文 Markdown、个人来源、主图谱或 Web。把论文知识导入
主图谱是另一条需要重新授权和审查的流程，不属于这里的默认或可选分支。

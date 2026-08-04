# Skills

本目录是个人 skills 的权威副本，并随 qlblog 提交和同步。
`~/.codex/skills` 应作为一个完整目录软链接指向本目录，而不是为每个 skill
分别创建链接。Codex 管理的 `.system` 与 `.skills_store_lock.json` 通过本地
桥接保留，但不会提交到仓库。

## 仓库协议

- 新建个人 skill 时，直接创建在本目录下。
- 每次创建或实质更新 skill，都要更新本 README 中对应的一句话用途说明。
- skill 目录名通常与 `SKILL.md` 的 `name` 一致；社区包可保留版本化目录名。
- skill 内只保留执行所需文件，不为单个 skill 添加额外 README。
- 完成后运行 skill 校验、检查本 README，并审阅 qlblog Git diff。

## 跨设备安装与修复

克隆仓库后执行：

```sh
./skills/link-codex-skills.sh
```

脚本会备份已有的 `~/.codex/skills`，把 Codex 管理的系统 skills 保存到稳定的
用户目录，再创建整目录链接：

```text
~/.codex/skills -> /absolute/path/to/qlblog/skills
```

如果发现未知、内容冲突或指向仓库外部的现有 skill，脚本会拒绝覆盖。

## 个人维护

- [build-unity-scene](./build-unity-scene/)：读取 Unity 项目架构与关卡需求，按既有边界创建或修改场景并完成验证。
- [configure-unity-mcp](./configure-unity-mcp/)：安装、修复、迁移并完整验证 Codex 与 Unity Editor 的 MCP 集成。
- [create-latex-math-notes](./create-latex-math-notes/)：新建使用 ElegantBook 语法和 LaTeX-to-Typst 适配器的轻量数学笔记项目。
- [create-math-notes](./create-math-notes/)：新建可直接由 VS Code/Tinymist 编辑的 Typst-first 数学课程或专题。
- [discuss-game-design](./discuss-game-design/)：基于游戏设计文档讨论具体设计决策，并区分事实、综合、提案与开放问题。
- [export-typst-math-notes](./export-typst-math-notes/)：维护、语义整理并发布 Typst、Markdown、LaTeX 或混合格式的数学笔记。
- [extract-paper-concepts](./extract-paper-concepts/)：通读论文或论文仓库，生成面向初学者、具有来源依据的概念清单。
- [kgdistiller-distill](./kgdistiller-distill/)：把 Markdown、Typst 或 LaTeX 权威来源整理为有显式标记和证据关系的 kgdistiller 图谱。
- [play-unity-game](./play-unity-game/)：实际游玩并评估 Unity 游戏或场景，验证玩法循环和复现交互问题。
- [search-game-art](./search-game-art/)：搜索游戏美术资源并给出经过来源与许可证核验的候选清单，不自动下载或导入。
- [test-skill-with-agent](./test-skill-with-agent/)：在隔离环境中用真实或委派 agent 测试 skill，并独立检查产物、权限、改动和凭据泄漏。
- [trace-concept-lineage](./trace-concept-lineage/)：把论文概念批量整理为来源可追溯的概念档案、知识图谱和前置阅读路线。

## 社区来源

- [find-skill-skillhub-1.0.2](./find-skill-skillhub-1.0.2/)：在 SkillHub 按关键词和分类发现、筛选并推荐 skills。
- [mainpdf](./mainpdf/)：编辑、转换、OCR、拆分、合并并提取 PDF 的文字、表格和图片。
- [mermaid-diagram-1.0.0](./mermaid-diagram-1.0.0/)：把需求或文字描述转换为 Mermaid 流程图、架构图、时序图或思维导图。

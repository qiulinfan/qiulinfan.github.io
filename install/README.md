# 安装与配置

这里保存可移植、可审查的个人工具配置与安装说明，不保存机器上的实时状态或凭据：

- [`agent-stack.md`](agent-stack.md)：AI agent stack 的安全安装与更新流程。
- [`agents/`](agents/)：与运行时无关的个人全局 agent guidance 权威 [`core.md`](agents/core.md)，
  以及把它和各运行时增量拼装成安装文件的 [`build-guidance.sh`](agents/build-guidance.sh)。
- [`codex/`](codex/)：Codex 运行时增量 [`runtime.md`](codex/runtime.md)，以及生成并提交的
  安装文件 [`AGENTS.md`](codex/AGENTS.md)。
- [`claude/`](claude/)：Claude Code 运行时增量 [`runtime.md`](claude/runtime.md)，以及生成并提交的
  安装文件 [`CLAUDE.md`](claude/CLAUDE.md)。
- [`tool-configs/`](tool-configs/)：编辑器、Shell、操作系统设置、装饰资源与相关操作笔记。

`install/codex/AGENTS.md` 与 `install/claude/CLAUDE.md` 是生成物，不要直接编辑：改
`agents/core.md`（两个运行时共享）或对应的 `runtime.md`（只影响该运行时），然后运行
`make agents-guidance`。`make agents-check` 会在 CI 与本地检查两个生成文件是否已同步。
Codex 的 `AGENTS.md` 不支持任何 include 语法，所以共享内容只能在生成时内联，而不是引用。

这个目录随公开仓库发布。真实凭据、私有 IP 和机器局部覆盖必须留在仓库外；示例主机使用
`.example` 域名或显式占位符。

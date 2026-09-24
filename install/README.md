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

生成文件要链接到各运行时的 home 才会生效。每台机器在仓库根目录运行一次；目标位置已有文件时，
先确认内容再替换：

```sh
ln -s "$PWD/install/claude/CLAUDE.md" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
ln -s "$PWD/install/codex/AGENTS.md" "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
```

原生 Windows 使用 PowerShell 7。没有开启开发者模式时把 `SymbolicLink` 换成 `HardLink`；
硬链接会在 `git pull` 改动这两个文件后失效，需要重新创建：

```powershell
New-Item -ItemType SymbolicLink -Path "$HOME\.claude\CLAUDE.md" -Target "$PWD\install\claude\CLAUDE.md"
New-Item -ItemType SymbolicLink -Path "$HOME\.codex\AGENTS.md" -Target "$PWD\install\codex\AGENTS.md"
```

这组手动命令是临时方案，个人 runbook 仓库建立后由它接管。

这个目录随公开仓库发布。真实凭据、私有 IP 和机器局部覆盖必须留在仓库外；示例主机使用
`.example` 域名或显式占位符。

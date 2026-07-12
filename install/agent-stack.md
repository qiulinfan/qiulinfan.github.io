# Agent Stack Installation Runbook

This runbook is written for both humans and coding agents. It installs and maintains three layers:

- L1 coding agents: Claude Code, Codex, OpenCode;
- L2 persistent agents: OpenClaw, Hermes;
- L3 distributed scheduling: Multica.

All upstream commands must be re-checked against the linked official documentation before execution because installers change frequently.

## Safety contract for the installing agent

Before changing the machine:

1. Detect OS, architecture, shell, package managers, WSL version, Node/npm versions, and existing agent binaries.
2. Print the detected state and the exact proposed changes.
3. Ask which layers and products the user wants. Do not infer permission to install everything.
4. Ask whether Windows work should be native or inside WSL2 when that choice is unresolved.
5. Prefer an existing package manager; do not create duplicate installations through npm, Homebrew, WinGet, Scoop, or install scripts.
6. Use only official HTTPS domains and official GitHub repositories listed below.
7. Do not use `sudo npm install -g` or disable OS security controls merely to make installation succeed.
8. Never request that API keys be pasted into chat, source files, shell history, or this repository.
9. Installing a persistent daemon/gateway, login item, systemd service, scheduled task, webhook, or self-hosted server requires a separate explicit confirmation.
10. Do not enable YOLO/dangerous/no-approval modes by default.

After each installation, report binary path and version. Do not report success based only on an installer's exit code.

## Preflight

Read-only commands:

```bash
uname -a
command -v brew npm node claude codex opencode openclaw hermes multica || true
node --version 2>/dev/null || true
npm --version 2>/dev/null || true
```

PowerShell:

```powershell
Get-ComputerInfo | Select-Object OsName,OsVersion,OsArchitecture
Get-Command winget,choco,scoop,node,npm,claude,codex,opencode,openclaw,hermes,multica -All -ErrorAction SilentlyContinue
wsl --status
```

## L1: coding agents

### Claude Code

Official docs: <https://code.claude.com/docs/en/installation>

```bash
# macOS / Linux / WSL2
curl -fsSL https://claude.ai/install.sh | bash
claude --version
claude doctor
```

```powershell
# Native Windows
irm https://claude.ai/install.ps1 | iex
claude --version
```

Alternatives: `brew install --cask claude-code`, or `winget install Anthropic.ClaudeCode`.

### Codex

Official repo/docs: <https://github.com/openai/codex>, <https://developers.openai.com/codex>

```bash
# macOS / Linux
curl -fsSL https://chatgpt.com/codex/install.sh | sh
codex --version
```

```powershell
# Native Windows
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
codex --version
```

Alternatives: `brew install --cask codex`, or `npm install -g @openai/codex` with a supported modern Node/npm.

SSD safety check: Codex must be at least `0.143.0`, preferably current latest, because `0.142.0` and `0.143.0` contain key mitigations for excessive SQLite feedback-log writes described in <https://github.com/openai/codex/issues/28224>. After updating, inspect `~/.codex/logs_2.sqlite*` and watch for sustained disk writes during normal use.

### OpenCode

Official docs: <https://opencode.ai/docs/>

```bash
# macOS / Linux / WSL2
curl -fsSL https://opencode.ai/install | bash
opencode --version
```

Windows alternatives: `choco install opencode`, `scoop install opencode`, or `npm install -g opencode-ai`. WSL2 is preferred for Linux-oriented projects.

## L2: persistent agents

These products can install background gateways and connect messaging channels. Show the user what will persist before running onboarding or daemon installation.

### OpenClaw

Official docs: <https://docs.openclaw.ai/install>

```bash
# macOS / Linux / WSL2
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
openclaw --version
```

```powershell
# Native Windows, installation only
& ([scriptblock]::Create((iwr -useb https://openclaw.ai/install.ps1))) -NoOnboard
openclaw --version
```

Run onboarding and install a managed Gateway only after explicit confirmation.

### Hermes

Official docs: <https://hermes-agent.nousresearch.com/docs/>

```bash
# Linux / macOS / WSL2
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
hermes version
```

```powershell
# Native Windows
iex (irm https://hermes-agent.nousresearch.com/install.ps1)
hermes version
```

Do not connect messaging accounts or start persistent gateways without explicit confirmation.

## L3: Multica

Official repo: <https://github.com/multica-ai/multica>

```bash
# macOS / Linux
brew install multica-ai/tap/multica
multica version
```

Without Homebrew:

```bash
curl -fsSL https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.sh | bash
multica version
```

```powershell
# Native Windows
irm https://raw.githubusercontent.com/multica-ai/multica/main/scripts/install.ps1 | iex
multica version
```

`multica setup` authenticates and starts a local daemon. Ask before running it. Self-hosting additionally requires Docker and explicit permission to deploy the server/database stack.

## Update and verify

```text
Claude Code  claude update
Codex        rerun official installer, npm install -g @openai/codex@latest, or brew upgrade --cask codex
OpenCode     opencode upgrade
OpenClaw     openclaw update status; openclaw update --dry-run; openclaw update
Hermes       hermes update --check; hermes update --backup
Multica      multica update
```

Re-run each version command and verify the selected daemon/gateway/runtime health. For package-manager installations, update through the same package manager.

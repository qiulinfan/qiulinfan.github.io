# Claude Code with DeepSeek

Use Claude Code against DeepSeek's Anthropic-compatible endpoint:
`https://api.deepseek.com/anthropic`.

DeepSeek's official model list currently includes `deepseek-v4-flash` and
`deepseek-v4-pro`. This skill intentionally defaults both the main agent and
all subagents to `deepseek-v4-flash`, even though DeepSeek's generic Claude Code
example assigns Pro to some Claude aliases. Verify the identifiers again in
the [official model documentation](https://api-docs.deepseek.com/quick_start/pricing)
when model selection changes.

## Credential handling

- Accept `--key-file`, `ANTHROPIC_AUTH_TOKEN`, or `DEEPSEEK_API_KEY`.
- Prefer a one-line plaintext credential file with mode `0600`.
- Confirm only presence, line count, length, recognizable shape, and file mode.
- Never print the key or include it literally in a prompt, command argument,
  settings file, agent definition, log, or copied workspace.
- Never copy the credential into the task project.

`scripts/run_deepseek.py` reads a credential file inside Python and passes it
only through the child environment. It sets:

```text
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
ANTHROPIC_MODEL=deepseek-v4-flash
ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-flash
ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-flash
ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash
CLAUDE_CODE_EFFORT_LEVEL=max
```

Pass `--model` only for an explicit override. The runner applies that override
to every default model variable and to agent definitions that omit `model`.

## Runtime behavior

The runner launches Claude Code from the requested project with project skill
discovery enabled, strict MCP configuration, structured output, and no session
persistence by default. It defines the main worker or coordinator with
`--agents` and selects it with `--agent`, so its `skills` list is preloaded at
startup rather than left to accidental discovery.

Supply the minimum global tools with repeated `--allowed-tool`. Per-agent
definitions can narrow them further. Supply approved MCP servers with repeated
`--mcp-config`; strict mode ignores ambient MCP configuration.

Use `--output-format stream-json` when verification needs forwarded subagent
events. Use `--persist-session` only when later resumption is part of the
contract. Use `--agent-teams` only for the explicitly selected experimental
team topology.

## Discovery and result checks

Every injected skill must be a regular file at:

```text
PROJECT/.claude/skills/SKILL_NAME/SKILL.md
```

The runner refuses to preload a missing or symlinked manifest. If Claude Code
still reports an unknown skill, classify it as staging or runtime discovery,
not model behavior.

When JSON output exposes them, record `subtype`, `is_error`,
`api_error_status`, `terminal_reason`, `duration_ms`, `duration_api_ms`,
`num_turns`, `total_cost_usd`, per-model usage, and permission denials. Confirm
the reported model rather than inferring it only from configuration.

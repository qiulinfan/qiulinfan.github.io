# Claude Code with DeepSeek

Use this adapter only when the user requests DeepSeek through Claude Code or has
already authorized that provider flow. DeepSeek's Anthropic-compatible endpoint
is `https://api.deepseek.com/anthropic`.

## Credential handling

- Accept a credential file path or an already-exported variable.
- Confirm only presence, line count, length, recognizable shape, and file mode.
- Never print the key or include it literally in a command argument.
- Read it into the environment inside the same shell that launches Claude Code.
- Prefer mode `0600` for a plaintext credential file.
- Never copy the credential into the fixture or Claude settings.

## Environment template

Verify current model names against official DeepSeek documentation when model
selection matters. Then launch in one shell:

```sh
DEEPSEEK_KEY="$(tr -d '\r\n' < "$KEY_FILE")"
export ANTHROPIC_BASE_URL='https://api.deepseek.com/anthropic'
export ANTHROPIC_AUTH_TOKEN="$DEEPSEEK_KEY"
export ANTHROPIC_MODEL='deepseek-v4-pro[1m]'
export ANTHROPIC_DEFAULT_OPUS_MODEL='deepseek-v4-pro[1m]'
export ANTHROPIC_DEFAULT_SONNET_MODEL='deepseek-v4-pro[1m]'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='deepseek-v4-flash'
export CLAUDE_CODE_SUBAGENT_MODEL='deepseek-v4-flash'
export CLAUDE_CODE_EFFORT_LEVEL='max'

claude --print --output-format json --no-session-persistence \
  --setting-sources project \
  --strict-mcp-config \
  --permission-mode dontAsk \
  --allowedTools 'Read,Grep,Glob,Bash' \
  --agent skill-tester \
  "/target-skill Natural user request over the fixture"
```

Define `skill-tester` with `--agents` when a named agent is required. Tailor its
prompt to role and scope, but keep the actual task in the natural user request.
Do not disclose grading criteria in either prompt.

For review-only tests, omit `Edit` and `Write`. Remember that `Bash` can still
write; independently compare the workspace afterward. For write tests, grant
only the required tools and keep the project disposable.

## Discovery behavior

Place a physical skill directory at:

```text
PROJECT/.claude/skills/SKILL_NAME/SKILL.md
```

Project skill discovery may fail for a directory symlink. The `--bare` option
can also change customization discovery across Claude Code versions. Prefer
`--setting-sources project` for an isolated project-level test and prove skill
recognition before interpreting model behavior.

## Result fields

When JSON output provides them, record:

- `subtype`, `is_error`, `api_error_status`, and `terminal_reason`;
- `duration_ms`, `duration_api_ms`, and `num_turns`;
- `total_cost_usd` and per-model usage;
- `permission_denials`;
- the agent's final result.

An `Unknown command` result with zero API duration and zero turns is a harness
failure, not a provider or behavior failure.

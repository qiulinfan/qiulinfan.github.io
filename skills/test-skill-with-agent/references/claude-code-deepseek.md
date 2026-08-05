# Claude Code runtime for skill trials

The machine-local runtime profile is authoritative. With `subscription`
authentication, launch Claude Code through its existing local login, clear
ambient API overrides, and omit the model unless the user selected one. With
`api` authentication, use DeepSeek's Anthropic-compatible endpoint,
`https://api.deepseek.com/anthropic`, and the cached model, normally
`deepseek-v4-flash`. Verify model identifiers against the
[official model documentation](https://api-docs.deepseek.com/quick_start/pricing)
when a model matrix or comparison matters.

## Credential rules

- Require a ready `.agent-runtime-profile.local.json` before every dry-run or
  trial.
- For API mode, read only the one-line `0600` credential file named by the
  profile.
- Never print the key or put it in prompts, commands, settings, agent
  definitions, logs, fixtures, or model-produced metadata.
- Use a separate credential file outside all trial and result directories.

`scripts/run_trials.py` reads an API credential inside Python and passes it only
through each child environment. It never falls back to ambient API variables.
In subscription mode it clears those variables so the cached authentication
choice cannot be silently changed.

## Trial mechanics

Each trial must have its own fixture copy, physical target-skill copy, Claude
session, baseline, result files, and workspace diff. Disable session persistence
and ambient MCP configuration. Pass only approved MCP configs and minimum tools.

Use one trial for a smoke or conformance case. For repeat and stress tests:

- keep one target skill and one atomic contract;
- use identical copies rather than concurrent access to shared files;
- cap `--parallel` to the authorized load and provider budget;
- cap spend per trial with `--max-budget-usd-per-trial`;
- preserve every trial result, including harness and provider failures;
- stop increasing load when rate limits or budget failures dominate the signal.

Stress testing authorizes bounded API concurrency only to the level stated in
the contract. It does not authorize writes to production systems or live user
data.

## Result fields

When Claude JSON exposes them, record `subtype`, `is_error`,
`api_error_status`, `terminal_reason`, `duration_ms`, `duration_api_ms`,
`num_turns`, `total_cost_usd`, per-model usage, and permission denials. Confirm
the reported model instead of inferring it only from environment configuration.

An unknown skill, zero API duration, or zero turns is a harness/discovery
failure. A rate limit, balance, authentication, or unavailable-model response
is a provider failure. Neither is evidence that the skill's behavior failed.

# Machine-local external-agent runtime profile

`codex-external-agent-testskill` owns one ignored profile named
`.agent-runtime-profile.local.json` in the repository `skills/` directory. It
is machine-local state, not a portable Skill asset. Never stage, publish,
commit, or copy it into a fixture or result directory.

This profile configures external evaluators only. The supported runtime IDs are
`claude-code` and `opencode`. Codex is the coordinator that invokes this Skill;
it is never a configurable target runtime.

## First-use gate

Before any test setup, run from the active Skill directory:

```sh
python3 scripts/runtime_profile.py status
```

The command discovers only installed Claude Code and OpenCode executables. It
returns exit status `2` and concrete questions when the profile is absent,
malformed, stale in a required field, or points to a missing credential file.
Return those questions to the user and stop. Do not build fixtures, stage
Skills, or run a dry-run first. When exactly one supported external agent is
detected, infer it and ask only for missing authentication information.

## Configure from explicit user answers

For an existing local subscription login, select its runtime explicitly:

```sh
python3 scripts/runtime_profile.py configure \
  --selected-agent claude-code \
  --auth-mode subscription
```

Use `opencode` in the same command when requested. Subscription mode records
the user's choice; the selected CLI remains responsible for validating its
cached login at launch.

For DeepSeek API access through Claude Code:

```sh
python3 scripts/runtime_profile.py configure \
  --selected-agent claude-code \
  --auth-mode api \
  --credential-file /absolute/path/to/deepseek-key
```

Claude Code API mode defaults to the DeepSeek Anthropic-compatible endpoint and
the Skill's documented default model. For OpenCode API access, explicitly pass
`--provider`, `--model`, and `--base-url`; supported providers are `anthropic`,
`deepseek`, and `openai`, and its model must use `provider/model` form.

The credential file must contain exactly one non-empty line and use mode `0600`
on POSIX. The profile stores its absolute path, never its contents. The profile
itself is written atomically with mode `0600` and records:

- installed Claude Code and OpenCode executable paths and versions;
- the selected base external agent;
- one authentication/runtime entry per configured external agent;
- each entry's `subscription` or `api` mode;
- for API mode, the credential-file path, provider, endpoint, and model.

Every configure call stores an `agent_profiles` entry for that runtime. To add
or refresh another external agent without changing the cached base agent,
include `--keep-base`.

## Optional cached routes

Add a route only when the user explicitly wants a context-specific external
evaluator:

```sh
python3 scripts/runtime_profile.py route \
  --skill extract-paper-concepts \
  --agent opencode

python3 scripts/runtime_profile.py route \
  --workflow codex-external-agent-testskill \
  --agent claude-code
```

Remove an exact route scope with the same selectors plus `--remove`. Route
precedence is workflow-plus-Skill, then a workflow-only or Skill-only match,
then the base agent. A later entry wins ties. Configure an agent's
authentication before routing work to it; a route never borrows the base
agent's credentials.

Only configure from choices explicitly present in the current user request or
provided in a direct reply to the first-use questions. Do not infer
subscription versus API from ambient environment variables or existing login
files. After configuration, rerun `status` and continue only on `ready`.

## Runtime adapters

Each adapter uses its native project Skill location and structured invocation:

| Runtime | Project Skill root | Structured execution |
| --- | --- | --- |
| Claude Code | `.claude/skills/` | `claude --print --agents ...` |
| OpenCode | `.opencode/skills/` | `opencode run --format json ...` |

Subscription mode clears ambient provider tokens before launch so the cached
local login remains authoritative. API mode reads the key only inside the
runner and passes it through the child environment using the selected
runtime's provider variable. Neither mode puts credentials in prompts,
commands, fixtures, staged Skills, agent definitions, logs, or result metadata.

OpenCode runs use temporary runtime state. The runner copies only cached
subscription authentication when present, keeps ambient personal Skills and
session history out of the run, and deletes temporary state afterward. Claude
Code disables session persistence and loads project settings only.

Claude Code exposes a native dollar budget flag. OpenCode does not; use
`--timeout-seconds-per-trial` as its enforced bound. The runner enforces the
profile gate for `--dry-run`, so direct script use cannot bypass first-use
configuration.

# Machine-local agent runtime profile

Both `test-skill-with-agent` and `run-workflow-with-agents` share one ignored
profile named `.agent-runtime-profile.local.json` in the directory containing
their Skill folders. It is machine-local state, not a portable Skill asset.
Never stage, publish, commit, or copy it into a fixture or result directory.

## First-use gate

Before any task setup, run from the active Skill directory:

```sh
python3 scripts/runtime_profile.py status
```

The command discovers common local agent executables, including Claude Code,
Codex, OpenCode, Gemini CLI, Aider, Cursor Agent, and GitHub Copilot CLI. The
implemented executors are `claude-code`, `codex`, and `opencode`. Other detected
agents remain visible but cannot be selected until an adapter exists.

The command returns exit status `2` and concrete questions when the profile is
absent, malformed, stale in a required field, or points to a missing credential
file. Return those questions to the user and stop. Do not build fixtures,
inspect a production project, stage Skills, or run a dry-run first. When exactly
one supported agent is detected, infer it and ask only for missing authentication
information.

## Configure from explicit user answers

For an existing local subscription login, select its runtime explicitly:

```sh
python3 scripts/runtime_profile.py configure \
  --selected-agent codex \
  --auth-mode subscription
```

Use `claude-code` or `opencode` in the same command when requested. Subscription
mode records the user's choice; the selected CLI remains responsible for
validating its cached login at launch.

Every configure call stores an `agent_profiles` entry for that agent. To add or
refresh another agent without changing the cached base agent, include
`--keep-base`. This allows, for example, a Claude Code + DeepSeek API base and a
Codex subscription route without applying one agent's credential mode to the
other.

For DeepSeek API access through Claude Code:

```sh
python3 scripts/runtime_profile.py configure \
  --selected-agent claude-code \
  --auth-mode api \
  --credential-file /absolute/path/to/deepseek-key
```

For Codex API access, pass `--provider openai`, an OpenAI model, and the OpenAI
endpoint. For OpenCode API access, use provider `anthropic`, `deepseek`, or
`openai` and specify its model as `provider/model`.

The credential file must contain exactly one non-empty line and use mode `0600`
on POSIX. The profile stores its absolute path, never its contents. The profile
itself is written atomically with mode `0600` and records:

- detected installed agents, executable paths, versions, and support status;
- the selected base agent;
- one authentication/runtime entry per configured agent;
- each entry's `subscription` or `api` mode;
- for API mode, the credential-file path, provider, endpoint, and model.

The base agent is the permanent fallback. Once it is configured, ordinary use
must not ask the user to select an agent again. The optional `routes` list may
be absent or empty; that is a complete profile, not missing information.

## Optional cached routes

Add a route only when the user explicitly wants a context-specific agent:

```sh
python3 scripts/runtime_profile.py route \
  --skill extract-paper-concepts \
  --agent codex

python3 scripts/runtime_profile.py route \
  --workflow paper-distillation \
  --agent opencode
```

Remove an exact route scope with the same selectors plus `--remove`. Route
precedence is workflow-plus-Skill, then a workflow-only or Skill-only match,
then the base agent. A later entry wins ties. `configure` preserves existing
routes. Configure an agent's authentication before routing work to it; a route
never borrows the base agent's credentials.

The test runner resolves the target Skill with workflow
`test-skill-with-agent`. The production runner resolves every preloaded Skill
against its stable workflow name. Missing routes never cause a question.
Heterogeneous routes remain cached, but one coordinated session must use one
agent product; reject a topology whose Skill routes resolve to different
runtimes instead of silently replacing them.

Only configure from choices explicitly present in the current user request or
provided in a direct reply to the first-use questions. Do not infer
subscription versus API from ambient environment variables or existing login
files. After configuration, rerun `status` and continue only on `ready`.

## Runtime adapters

Each adapter uses the runtime's native project Skill location and invocation:

| Runtime | Project Skill root | Structured execution |
| --- | --- | --- |
| Claude Code | `.claude/skills/` | `claude --print --agents ...` |
| Codex | `.agents/skills/` | `codex exec --json --ephemeral ...` |
| OpenCode | `.opencode/skills/` | `opencode run --format json ...` |

Subscription mode clears ambient provider tokens before launch so the cached
local login remains authoritative. API mode reads the key only inside the
runner and passes it through the child environment using the selected runtime's
provider variable. Neither mode puts credentials in prompts, commands,
fixtures, staged Skills, agent definitions, logs, or result metadata.

Non-persistent Codex and OpenCode runs use temporary runtime state. The runner
copies only the cached subscription authentication file when one exists, keeps
ambient personal Skills and session history out of the run, and deletes the
temporary state afterward. Project Skills remain discoverable.

Claude Code exposes a native dollar budget flag. Codex and OpenCode do not;
use `--timeout-seconds-per-trial` for their bounded trials and
`--timeout-seconds` for production runs. Do not claim a monetary cap where the
runtime cannot enforce one.

The runners enforce this gate for `--dry-run`, so direct script usage cannot
bypass first-use discovery.

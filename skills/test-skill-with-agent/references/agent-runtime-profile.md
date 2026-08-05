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
OpenCode, Codex, Gemini CLI, Aider, Cursor Agent, and GitHub Copilot CLI. It
returns exit status `2` and concrete questions when the profile is absent,
malformed, stale in a required field, or points to a missing credential file.
Return those questions to the user and stop. Do not build fixtures, inspect a
production project, stage Skills, or run a credential-free dry-run first.

Claude Code is the currently implemented executor. Other detected agents must
still be reported; never silently substitute Claude Code when the user selects
an unsupported runtime. When exactly one agent is detected, infer it and ask
only for the missing authentication information.

## Configure from explicit user answers

For an existing subscription login:

```sh
python3 scripts/runtime_profile.py configure \
  --selected-agent claude-code \
  --auth-mode subscription
```

For DeepSeek API access through Claude Code:

```sh
python3 scripts/runtime_profile.py configure \
  --selected-agent claude-code \
  --auth-mode api \
  --credential-file /absolute/path/to/deepseek-key
```

The credential file must contain exactly one non-empty line and use mode `0600`
on POSIX. The profile stores its absolute path, never its contents. The profile
itself is written atomically with mode `0600` and records:

- detected installed agents, executable paths, versions, and support status;
- the selected base agent;
- `subscription` or `api` authentication mode;
- for API mode, the credential-file path, provider, endpoint, and model.

The base agent is the permanent fallback. Once it is configured, ordinary use
must not ask the user to select an agent again. The optional `routes` list may
be absent or empty; that is a complete profile, not missing information.

## Optional cached routes

Add a route only when the user explicitly wants a context-specific agent:

```sh
python3 scripts/runtime_profile.py route \
  --skill extract-paper-concepts \
  --agent claude-code

python3 scripts/runtime_profile.py route \
  --workflow paper-distillation \
  --agent claude-code

python3 scripts/runtime_profile.py route \
  --workflow paper-distillation \
  --skill reviewer-skill \
  --agent claude-code
```

Remove an exact route scope with the same selectors plus `--remove`. Route
precedence is workflow-plus-Skill, then a workflow-only or Skill-only match,
then the base agent. A later entry wins ties. `configure` preserves existing
routes.

The test runner resolves the target Skill with workflow
`test-skill-with-agent`. Missing routes never cause a question. A route to a
detected but unsupported executor produces a compatibility finding only when
that context is used; it does not invalidate the base profile or trigger a new
agent-selection prompt.

Only configure from choices explicitly present in the current user request or
provided in a direct reply to the first-use questions. Do not infer
subscription versus API from ambient environment variables or existing login
files. After configuration, rerun `status` and continue only on `ready`.

## Runtime behavior

Subscription mode clears ambient API endpoint and token variables before
launch so the local agent login remains authoritative. API mode reads the key
only inside the runner process and passes it through the child environment.
Neither mode puts credentials in prompts, commands, fixtures, staged Skills,
agent definitions, logs, or result metadata.

The runner also enforces this gate for `--dry-run`, so direct script usage
cannot bypass first-use discovery.

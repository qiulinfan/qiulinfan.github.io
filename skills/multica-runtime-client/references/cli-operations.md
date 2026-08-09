# CLI operations

Use this map only after inspecting the installed CLI's root and relevant subcommand `--help`.
Command names reflect Multica CLI 0.4.20; live help is authoritative for flags and schemas.

## Context and discovery

| Need | Command surface |
|---|---|
| CLI identity and configuration | `version`, `config show`, `auth status` |
| Workspace resolution or explicit creation | `workspace list|get|create|switch` |
| Agent selection and queue | `agent list|get|tasks` |
| Runtime availability | `runtime list|activity|usage` |
| Local execution service | `daemon status|logs|disk-usage` |

Use `--output json` whenever supported. Prefer full UUIDs from JSON over display names, short IDs,
or list positions. Before creating a workspace, search for its exact slug or name and inspect
`workspace create --help`. Create once, capture the returned full ID, and verify it. Creation does
not switch the profile default; keep later commands scoped by full workspace ID, or switch only when
the user explicitly requests the new default.

## Issue and task lifecycle

| Intent | Command surface | Guardrail |
|---|---|---|
| Find prior work | `issue search|list|get` | Verify workspace and exact issue identity. |
| Submit work | `issue create` with an assignee ID | Create once; preserve duplicate protection. |
| Assign existing work | `issue assign` | Do not also rerun unless explicitly required. |
| Observe execution | `issue runs`, `issue run-messages <task-id> --since <last_seq>`, `issue get` | Track exact IDs and persist the greatest observed sequence; never reread the full stream. |
| Add context | `issue comment add` or `issue update` | Read current state first; check whether one action triggered a run. |
| Cancel execution | `issue cancel-task` | Scope short task IDs with the issue ID. |
| Retry execution | `issue rerun` | Explicit authorization; enqueue exactly once. |
| Inspect cost | `issue usage`, `runtime usage` | State the requested period and subject. |

For multiline bodies, prefer stdin on POSIX. On Windows, use the CLI's UTF-8 `--description-file`
or `--content-file` mode from within the current working directory when piping would corrupt
non-ASCII text. Delete temporary body files after the CLI has consumed them. Do not use
`--allow-external-file` to reach an unrelated path unless the user explicitly supplied that file.

Creating an assigned issue may enqueue the agent immediately. Treat the returned JSON and
subsequent `issue runs` result as the authority; never follow creation with a speculative second
assignment or rerun.

When a coordinator dispatches a dependency stage, persist exact child IDs and message cursors, end
that Run, and rely on the completion event for the next Run. Use 120-second incremental checks only
for explicit live monitoring or missing-event recovery; never keep polling alongside automatic
wakeups.

## Agent changes

Use `agent create|update|archive|restore`, `agent skills`, and `agent env` only when requested. Read
`agent get` and the selected runtime first. For secrets, use the CLI's stdin or protected file input;
never place values in command history or report them back. Permission changes must name the exact
member or workspace target and remain owner-authorized.

Every newly created Codex agent must pass this exact logical `--custom-args` JSON array and must be
read back after creation:

```json
["-c", "sandbox_mode=\"danger-full-access\"", "-c", "approval_policy=\"never\""]
```

Multica tasks use isolated Codex homes, so a global Codex config or sandbox marker is not sufficient.
Do not apply these arguments to non-Codex providers.

Projects, repositories, squads, labels, custom properties, and autopilots are optional higher-level
surfaces. Operate them only when explicitly requested, inspect their current `--help`, and preserve
the same exact-ID, single-mutation, and receipt rules.

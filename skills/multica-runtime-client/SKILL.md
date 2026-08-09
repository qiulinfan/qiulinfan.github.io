---
name: multica-runtime-client
description: Operate an already configured Multica client through its installed CLI. Resolve the active profile and workspace, select accessible agents backed by online runtimes, turn natural-language work into well-scoped issues, submit exactly one task, monitor runs and messages, report verified results, continue existing work, cancel or rerun requested tasks, and inspect runtime activity, usage, or logs. Use for ordinary post-setup Multica agent, issue, task, and runtime operations. If the CLI, authentication, private Server access, workspace membership, daemon, or initial agents are not ready, hand off to multica-client-setup instead of installing or onboarding here. Never inspect provider CLIs or change Server admission, Tailscale, VPN, autostart, or deployment configuration.
---

# Multica runtime client

Run ordinary work through an existing Multica client. Treat `$multica-client-setup` completion as a
precondition, not as part of this workflow.

## Boundaries

- Execute and verify Multica operations from the user's natural-language request; do not return a
  command tutorial when the operation can be completed directly.
- Match user-facing explanations, prompts, and handoffs to the user's language unless requested
  otherwise. Preserve commands, identifiers, JSON keys, action codes, and raw errors.
- Never install or update the CLI, authenticate a new identity, accept invitations, switch network
  admission, edit VPN/proxy routing, install autostart, deploy a Server, or change Server policy.
- Never inspect, select, install, sign in to, or verify provider CLIs. Use Multica agent, runtime,
  daemon, issue, and run state as the execution-plane evidence.
- Keep credentials and private environment values out of command arguments, issue bodies, logs, and
  receipts. Use the CLI's stdin/file modes for sensitive structured input when an authorized agent
  configuration change requires it.
- Diagnose with read-only commands. Restart, cancel, rerun, archive, delete, or mutate configuration
  only when the user's request authorizes that action.

## Preflight

1. Locate `multica`; if absent, stop and hand off to `$multica-client-setup`.
2. Inspect `multica --version`, root `--help`, and every relevant subcommand's `--help` before
   choosing flags. Do not assume the bundled examples match a newer or older CLI.
3. Read current configuration and authentication status without exposing tokens. Resolve the
   requested profile and workspace from explicit user input or the already selected live profile.
   Never guess between multiple plausible workspaces.
4. Require existing workspace membership. For execution, require an accessible active agent whose
   runtime is online. Resolve names to full IDs and stop on ambiguity.
5. If private reachability, authentication, membership, daemon registration, or initial agent
   exposure is missing, report the first failed precondition and hand off to
   `$multica-client-setup`; do not repair setup from this Skill.

Use JSON output for discovery and mutations when the command supports it. Follow
[CLI operations](references/cli-operations.md) for the operation-to-command map.

## Run work

### 1. Resolve the target

List agents and runtimes in the selected workspace. Prefer an agent explicitly named by the user.
Otherwise select only when one candidate clearly matches the requested repository, platform,
capability, instructions, and online runtime. Use the agent UUID for execution; do not rely on fuzzy
name matching or list order.

Create or change an agent only when explicitly requested. Before mutation, read the agent and
runtime state. Treat permission mode, runtime, model, reasoning level, skills, MCP configuration,
environment, and concurrency as independent settings; change only the requested fields.

### 2. Build one issue

Translate the request into:

- a concise title;
- the desired outcome and relevant context;
- concrete acceptance checks;
- repository, project, file, platform, and permission boundaries;
- attachments or prior issue IDs supplied by the user.

Search for an active matching issue before creation. Reuse the exact intended issue when found.
Never bypass duplicate protection with `--allow-duplicate` unless the user explicitly wants a
separate duplicate.

Create the issue and assign it to the chosen agent in one operation when immediate execution is
intended. Capture the returned issue ID and task/run ID. Do not create, assign, or rerun a second
time merely because output is delayed or a polling command failed.

### 3. Observe bounded execution

Read the issue, its execution history, and messages by exact IDs. Poll with a bounded wait and give
the user a concise progress update at least once per minute. If the run remains active after the
current bounded observation window, return its identifiers, current state, latest meaningful
message, and a resume instruction; do not duplicate the task.

Report success only when the selected run reaches a successful terminal state and its result
satisfies the issue's acceptance checks. Distinguish agent-reported evidence from checks independently
verified in the accessible repository or system. On failure, preserve the issue and run IDs, the
first actionable error, and relevant messages.

## Continue, cancel, and rerun

- Continue an existing issue by ID. Read its current issue, runs, and comments before adding new
  context. After one follow-up action, confirm whether a new run was actually created before taking
  any further enqueue action.
- Cancel only the exact queued or running task requested by the user. Resolve short IDs within the
  issue and verify the resulting task state.
- Rerun only after explicit authorization. Confirm the previous run is terminal, keep the same
  issue, enqueue once, and capture the new task ID.
- Update status, assignment, priority, project, properties, metadata, or comments only when they are
  part of the request. Do not mark an issue `done` merely because an agent emitted a plausible reply.

## Inspect and recover runtime operation

For status, activity, usage, queue, disk, or log requests, read the corresponding agent, runtime,
daemon, issue, or run surface and report the smallest evidence set that answers the question.

When asked to fix an operational failure, troubleshoot only the first failed layer:

```text
profile -> workspace -> agent permission/status -> runtime online -> daemon -> issue -> task -> messages
```

Use safe local daemon restart only when authorized and applicable. Send network, authentication,
membership, installation, initial agent exposure, and persistent recovery problems to
`$multica-client-setup`.

## Receipt

Return the workspace, agent ID, runtime ID when relevant, issue ID, task/run ID, terminal or current
state, acceptance evidence, and any next action. Never include tokens, cookies, verification codes,
private environment values, or attachment contents that the user did not request.

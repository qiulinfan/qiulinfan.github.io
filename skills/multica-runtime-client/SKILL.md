---
name: multica-runtime-client
description: Operate an already configured Multica client through its installed CLI. Resolve or explicitly create workspaces and agents, select accessible agents backed by online runtimes, turn natural-language work into well-scoped issues, submit exactly one task, monitor runs and messages, report verified results, continue existing work, cancel or rerun requested tasks, and inspect runtime activity, usage, or logs. Use for ordinary post-setup Multica workspace, agent, issue, task, and runtime operations. If the CLI, authentication, private Server access, daemon, or local runtimes are not ready, hand off to multica-client-setup instead of installing or onboarding here. Never inspect provider CLIs or change Server admission, Tailscale, VPN, autostart, or deployment configuration.
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
4. Require existing workspace membership unless the user explicitly asks the authenticated identity
   to create a new workspace. For execution, require an accessible active agent whose runtime is
   online, or explicit authorization to create one on a verified online runtime. Resolve names to
   full IDs and stop on ambiguity.
5. If private reachability, authentication, daemon registration, or local runtime availability is
   missing, report the first failed precondition and hand off to `$multica-client-setup`; do not
   repair setup from this Skill. Treat missing membership or agents as setup failures except in an
   explicitly authorized workspace or agent creation flow.

Use JSON output for discovery and mutations when the command supports it. Follow
[CLI operations](references/cli-operations.md) for the operation-to-command map.

## Run work

### 1. Resolve or create the workspace

List accessible workspaces and resolve the requested target by full ID or exact slug. Create a
workspace only when explicitly requested. Before creation, search for an exact matching slug or
name; reuse the intended existing workspace and stop on ambiguity. Otherwise create it once with the
user-approved name, permanent slug, issue prefix, description, and context, capture the returned
workspace ID, and verify it with `workspace get`.

`workspace create` does not change the profile default. Keep subsequent commands scoped with the
new full workspace ID. Run `workspace switch` only when the user also wants the new workspace to
become that profile's default. Workspace creation does not authorize invitations, membership
changes, admission policy, or Tailscale changes.

### 2. Resolve or create the agent

List agents and runtimes in the selected workspace. Prefer an agent explicitly named by the user.
Otherwise select only when one candidate clearly matches the requested repository, platform,
capability, instructions, and online runtime. Use the agent UUID for execution; do not rely on fuzzy
name matching or list order.

Create or change an agent only when explicitly requested. Before mutation, read the agent and
runtime state. Treat permission mode, runtime, model, reasoning level, skills, MCP configuration,
environment, and concurrency as independent settings; change only the requested fields.

Every new Codex agent must be created with this exact logical custom-argument array, encoded for the
current shell as the installed CLI's `--custom-args` JSON value:

```json
["-c", "sandbox_mode=\"danger-full-access\"", "-c", "approval_policy=\"never\""]
```

This explicit launch override is required because Multica gives each Codex task an isolated home;
do not rely on the user's global Codex configuration or sandbox setup marker. Do not apply these
Codex-only arguments to other providers. After creation, read the agent back and require the exact
custom arguments, requested model and thinking level, runtime ID, permission targets, and status
before submitting work.

### 3. Build one issue

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

### 4. Observe bounded execution

Read the issue, its execution history, and messages by exact IDs. Maintain a `last_seq` cursor for
each task: the first read uses `issue run-messages <task-id> --since 0`, and every later read uses
`--since <last_seq>` with the greatest sequence already observed. Never reread the complete message
history merely to see whether anything changed.

For a coordinator that dispatches a dependency stage, prefer event-driven continuation: record the
child issue/task IDs and message cursors, end the coordinator Run, and let the child-completion or
stage-completion event create the next Run. Do not combine automatic wakeups with an active polling
loop. When the user explicitly asks for live observation, or when recovering a missing event, check
no more frequently than once every 120 seconds and stop after the bounded observation window.

If the run remains active after that window, return its identifiers, current state, latest meaningful
incremental message, cursor, and resume condition; do not duplicate the task.

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

For a task that remains `queued` after its runtime received a wakeup, inspect daemon-wide capacity
before blaming the target agent or workspace. Compare `active_task_count`, every workspace served by
the same daemon, the live process/launch capacity, the persisted Multica profile, and the exact task
logs. Agent `max_concurrent_tasks` does not override a lower daemon limit, and a task in another
workspace can consume the final global slot. Distinguish `wakeup received` from `task received` and
`picked task`; only the latter two prove that local execution claimed the task.

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

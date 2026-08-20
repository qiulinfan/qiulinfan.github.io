---
name: codex-subagent-workflow
description: Execute production work inside the active Codex session with one or more native Codex subagents and optional Agent Skills. Prefer project-defined roles from the standard trusted `.codex/config.toml` `[agents]` configuration; only derive a topology from the request when no custom project roles are configured. Use when research, implementation, review, validation, or other deliverable-producing work benefits from bounded worker roles, parallel investigation, or staged handoffs. Do not launch external agent CLIs, use this Skill for isolated Skill evaluation, or claim process-level isolation; use codex-subagent-testskill to test exactly one Skill.
---

# Run a workflow with Codex subagents

Coordinate real work through native Codex subagents. Keep authority, integration,
and final verification with the current Codex agent.

## Enforce the runtime boundary

Require native Codex subagent delegation in the active session. Never launch
`codex`, Claude Code, OpenCode, or another agent CLI through the shell or an API.
If native subagent tools are unavailable, stop and report the capability gap.
Do not silently fall back to an external runtime.

Native subagents share the current Codex runtime and workspace. Treat them as
separate working contexts, not separate security principals, logins, sandboxes,
or billing accounts. Preserve every system, developer, repository, and user
authority boundary that applies to the coordinator.

## Define the production contract

Resolve from the request and local context:

- the outcome, workspace, deliverables, and finish checks;
- authorized reads, writes, external effects, tools, and connectors;
- the smallest relevant set of Agent Skills;
- independent roles, dependencies, write ownership, and integration order;
- a reasonable concurrency and time boundary.

Read every selected `SKILL.md` completely and every resource it makes mandatory
before delegating work. Use discovered Skills by name and physical path. Do not
load unrelated Skills merely because they are available.

Use the current Codex model and reasoning configuration by default. Apply a
supported per-worker override only when the user explicitly requests it or a
confirmed task requirement demands it. Do not invent model availability.

## Resolve the standard project configuration

Before inventing roles, inspect the trusted primary project root's
`.codex/config.toml`. Use Codex's standard `[agents]` table; do not introduce a
second project-local schema.

When `[agents.<role>]` declarations exist:

- require `agents.enabled` not to disable native delegation;
- treat each role name plus required `description` as the authoritative role
  catalog and select the smallest applicable subset;
- resolve an optional `config_file` relative to the declaring `config.toml`,
  read that TOML layer completely, and preserve its model, reasoning, sandbox,
  and developer-instruction settings;
- honor `agents.default_subagent_model`,
  `agents.default_subagent_reasoning_effort`, and
  `agents.max_concurrent_threads_per_session`, capped by the native slots
  actually available and with capacity retained for the coordinator;
- spawn the configured role through the native role/type selector exposed by
  the current Codex surface; do not emulate an unavailable role by copying its
  instructions into a generic worker prompt;
- add only task-local outcome, input, ownership, evidence, and validator details
  to the worker assignment.

The user's explicit role and scope instructions choose among or further narrow
configured roles, but do not mutate persistent project configuration unless the
user asks. A malformed `[agents]` table, missing referenced `config_file`, or
configured role unavailable in the current native spawn interface is a
configuration failure: report it instead of silently switching to automatic
topology. If the configuration was added or changed after the current task
started, advise opening a fresh trusted Codex task so the native role selector
can reload it.

If the project file is absent, or it contains no `[agents.<role>]` declarations,
derive roles from the production contract below. A `.codex/config.toml` used
only for unrelated Codex settings therefore does not disable automatic
composition.

A minimal standard role catalog looks like:

```toml
[agents]
max_concurrent_threads_per_session = 4

[agents.researcher]
description = "Find primary evidence without modifying production files."
config_file = "agents/researcher.toml"

[agents.reviewer]
description = "Independently review integrated work and run validators."
config_file = "agents/reviewer.toml"
```

## Choose an automatic topology when unconfigured

Use one worker when a cohesive bounded task benefits from a fresh context and
the coordinator can independently verify it. Use multiple workers only when
their scopes can be separated or sequenced cleanly, such as research plus
implementation, independent review, or artifact validation.

For every worker define:

- a unique role and concrete terminal deliverable;
- required Skill names and paths;
- exact read/write ownership and forbidden areas;
- required evidence and validators;
- upstream inputs and downstream consumers.

Keep workers at one delegation level: they must not spawn nested subagents.
Retain one native slot for the coordinator and batch excess work. Run dependent
roles sequentially. Run independent roles concurrently only when their writes
cannot overlap; otherwise use copied workspaces, worktrees, or explicit handoff
order.

## Delegate with minimal context

Start workers with no forked conversation history, or the smallest context the
active surface supports. Pass task-local source artifacts and confirmed facts,
not the coordinator's hidden conclusions. Include the raw user outcome,
applicable constraints, Skill paths, workspace, ownership, and validation
commands.

Ask workers to report concrete evidence, changed files, commands run, failures,
and uncertainty. A worker may propose out-of-scope work but must not perform it.
Do not delegate destructive actions or externally visible mutations unless they
are already authorized and the worker's exact scope is unambiguous.

Track every launched worker through a terminal result. Send follow-up tasks only
to clarify or complete the original bounded role; do not silently strengthen a
failed prompt or expand authority. If the user redirects the task, stop or
retarget obsolete workers before integrating their output.

Give every worker a reasonable terminal deadline. If it produces no terminal
result by that deadline, request one concise status update, then interrupt it if
it still does not finish promptly. Report the timeout as an orchestration
failure and continue only when the remaining workflow can still satisfy the
production contract.

## Integrate and verify

Treat worker reports as evidence candidates, not completion proof. The
coordinator must inspect the actual workspace, reconcile overlapping claims,
review the complete diff, and run the finish checks required by the task and
selected Skills.

Confirm that:

- every required role reached a terminal result;
- writes stayed inside assigned ownership and user authority;
- dependent handoffs used the intended artifact versions;
- validators passed on the integrated state;
- no worker launched an external agent CLI or nested subagent;
- unresolved conflicts, skipped work, and uncertainty remain visible.

Retry only a demonstrated transient failure or orchestration defect. Reuse no
contaminated worker context for independent review; start a fresh native
subagent when independence matters.

## Deliver

Lead with the completed outcome and link concrete artifacts. Summarize the
native subagent topology, Skills used, material worker results, integrated file
changes, and validators. Report capability gaps, failed or skipped roles, and
remaining uncertainty.

Do not claim completion when the coordinator did not inspect deliverables,
required validation was skipped, or work exceeded the authorized scope.

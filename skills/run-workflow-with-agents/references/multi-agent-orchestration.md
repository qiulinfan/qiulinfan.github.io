# Multi-agent orchestration

Describe one coordinator and named workers in a runtime-neutral JSON object.
`run_agents.py` translates it to Claude Code agents, Codex project custom
agents, or OpenCode primary/subagents. Each worker gets an isolated context and
must not spawn another worker; all fan-out, sequencing, and synthesis belongs
to the coordinator.

## Contents

- [Build the topology](#build-the-topology)
- [Understand native translation](#understand-native-translation)
- [Partition work safely](#partition-work-safely)
- [Launch coordinator plus workers](#launch-coordinator-plus-workers)
- [Escalate to Claude agent teams only when needed](#escalate-to-claude-agent-teams-only-when-needed)
- [Verify the orchestration](#verify-the-orchestration)

## Build the topology

Resolve the cached workflow and per-Skill agent routes before staging. One
coordinated session uses one external runtime, so all selected routes must
resolve to the same agent product. Preserve heterogeneous cached routes and
report the compatibility limit; do not ask the user to choose again or silently
replace a routed agent with the base agent.

Create the agent-definition file outside the task project when it is a
temporary run-control artifact. Agent names may contain ASCII letters, digits,
underscores, and hyphens. Use this shape:

```json
{
  "coordinator": {
    "description": "Coordinates specialists and delivers the verified result.",
    "prompt": "Delegate bounded work to the named workers, enforce ownership, inspect evidence, run final validation, and synthesize one result.",
    "tools": ["Read", "Grep", "Glob", "Bash", "Edit", "Write", "Agent(researcher,implementer,reviewer)"],
    "skills": ["coordination-skill"]
  },
  "researcher": {
    "description": "Investigates a bounded question and returns source-backed findings.",
    "prompt": "Work only on the assigned research question. Do not edit project files. Return evidence and unresolved conflicts.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "permissionMode": "plan",
    "skills": ["research-skill"]
  },
  "implementer": {
    "description": "Implements a bounded change in explicitly assigned files.",
    "prompt": "Edit only assigned files, follow the preloaded skill, run scoped checks, and return changed paths and evidence.",
    "tools": ["Read", "Grep", "Glob", "Bash", "Edit", "Write"],
    "skills": ["implementation-skill"]
  },
  "reviewer": {
    "description": "Independently reviews artifacts and validation evidence.",
    "prompt": "Review independently. Do not edit files. Report evidence-backed defects, scope violations, and missing validation.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "permissionMode": "plan",
    "skills": ["review-skill"]
  }
}
```

Remove unused roles and placeholder Skills. Omit a coordinator Skill when none
is relevant. A command-line `--model` becomes the default for definitions that
do not already specify a model. An API profile supplies its cached model.

## Understand native translation

- Claude Code receives the JSON definitions through `--agents`, selects the
  primary through `--agent`, and honors the definition's native `tools`,
  `permissionMode`, `skills`, and `maxTurns` fields.
- Codex receives the coordinator instructions in the primary prompt. Workers
  become project-scoped `.codex/agents/<name>.toml` custom agents with model,
  reasoning effort, sandbox, instructions, and staged-Skill directions. The
  runner enables native multi-agent tools and the coordinator spawns the named
  workers.
- OpenCode receives an inline high-precedence config. The coordinator becomes a
  primary agent, workers become subagents, `maxTurns` maps to `steps`, and the
  coordinator's `task` permission is limited to the named workers.

The staged Skill roots are `.claude/skills`, `.agents/skills`, and
`.opencode/skills` respectively. Generated Codex custom-agent TOML files are
run-control artifacts. Record and remove only files the current run created
after verification; never replace pre-existing definitions.

Tool permission systems are not identical. The runner maps common names such
as `Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`, `Agent`, and `Skill` to
native controls and selects a read-only or workspace-write Codex sandbox.
Independently verify workspace changes because a sandbox boundary is broader
than a per-tool allowlist.

## Partition work safely

- Parallelize independent, read-only investigation freely.
- Give concurrent writers disjoint file or directory ownership.
- Sequence work when one result is an input to another.
- Keep final integration and cross-cutting validation with the coordinator.
- Use a worktree or copied project for speculative or overlapping changes.
- Use `maxTurns` for bounded Claude/OpenCode specialists; use the outer
  `--timeout-seconds` boundary for Codex.
- Do not expose secrets or hidden control instructions in any agent prompt.

The task prompt must tell the coordinator which workers to use, the requested
outputs, ownership boundaries, dependencies, and finish conditions. Do not rely
only on automatic delegation for a topology the user explicitly requested.

## Launch coordinator plus workers

Stage the union of all Skills referenced by the definitions, then run:

```sh
python3 scripts/run_agents.py \
  --project "$RUN_PROJECT" \
  --agents-file "$AGENTS_FILE" \
  --primary-agent coordinator \
  --allowed-tool Read \
  --allowed-tool Grep \
  --allowed-tool Glob \
  --allowed-tool Bash \
  --allowed-tool Edit \
  --allowed-tool Write \
  --allowed-tool Agent \
  --timeout-seconds 900 \
  --prompt-file "$TASK_FILE"
```

The coordinator's `Agent(researcher,implementer,reviewer)` entry is the worker
allowlist for Claude Code. Codex and OpenCode derive the same allowlist from all
non-primary definitions. The broader global `Agent` permission only makes the
native delegation tool available.

## Escalate to Claude agent teams only when needed

Coordinator-plus-subagents is the stable cross-runtime default. Add
`--agent-teams` only when Claude Code workers must share a task list or
communicate peer to peer. Agent teams are experimental and Claude-specific;
reject the flag for Codex or OpenCode.

Ask the lead explicitly to create the named teammates, assign owners, wait for
their terminal states, review their messages, and complete final validation.
Do not enable teams merely to parallelize independent one-shot work.

## Verify the orchestration

Confirm that every required worker actually ran, used the intended preloaded
Skills and model, stayed within scope, and returned observable evidence.
Independently inspect artifacts and run final validators. Treat skipped workers,
overlapping unauthorized edits, missing native traces, or coordinator-only
completion as orchestration findings rather than a successful multi-agent run.

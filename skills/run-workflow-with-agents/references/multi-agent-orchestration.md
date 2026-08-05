# Multi-agent orchestration

Use one Claude Code session as the coordinator and define its workers in one
JSON object. Each agent gets an isolated context. A worker cannot spawn another
worker, so all fan-out and sequencing belongs to the coordinator.

## Contents

- [Build the topology](#build-the-topology)
- [Partition work safely](#partition-work-safely)
- [Launch coordinator plus workers](#launch-coordinator-plus-workers)
- [Escalate to agent teams only when needed](#escalate-to-agent-teams-only-when-needed)
- [Verify the orchestration](#verify-the-orchestration)

## Build the topology

Create the agent-definition file outside the task project when it is a temporary
run-control artifact. Use this shape:

```json
{
  "coordinator": {
    "description": "Coordinates specialists and delivers the verified result.",
    "prompt": "Plan the task, delegate only bounded work to the named workers, enforce file ownership, inspect their evidence, run final validation, and synthesize one result. Do not redo delegated work unless verification fails.",
    "tools": [
      "Read",
      "Grep",
      "Glob",
      "Bash",
      "Edit",
      "Write",
      "Agent(researcher,implementer,reviewer)"
    ],
    "skills": ["coordination-skill"]
  },
  "researcher": {
    "description": "Investigates a bounded question and returns source-backed findings.",
    "prompt": "Work only on the assigned research question. Do not edit project files. Return evidence, assumptions, and unresolved conflicts.",
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
    "prompt": "Review the completed result independently. Do not edit files. Report only evidence-backed defects, scope violations, and missing validation.",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "permissionMode": "plan",
    "skills": ["review-skill"]
  }
}
```

Remove unused roles. Replace placeholder skill names with the staged Codex
skills required by each role. Omit a coordinator skill when none is relevant.
The runner supplies `deepseek-v4-flash` to every definition that omits a model.

## Partition work safely

- Parallelize independent, read-only investigation freely.
- Give concurrent writers disjoint file or directory ownership.
- Sequence work when one result is an input to another.
- Keep final integration and cross-cutting validation with the coordinator.
- Use a worktree or copied project for speculative or overlapping changes.
- Cap turns inside agent definitions with `maxTurns` when a bounded specialist
  could otherwise wander.
- Do not expose secrets or hidden control instructions in any agent prompt.

The task prompt must tell the coordinator which workers to use, the requested
outputs, ownership boundaries, dependencies, and finish conditions. Do not rely
only on automatic delegation for a topology the user explicitly requested.

## Launch coordinator plus workers

Stage the union of all skills referenced by the definitions, then run:

```sh
python3 scripts/run_deepseek.py \
  --project "$RUN_PROJECT" \
  --key-file "$KEY_FILE" \
  --agents-file "$AGENTS_FILE" \
  --primary-agent coordinator \
  --allowed-tool Read \
  --allowed-tool Grep \
  --allowed-tool Glob \
  --allowed-tool Bash \
  --allowed-tool Edit \
  --allowed-tool Write \
  --allowed-tool Agent \
  --prompt-file "$TASK_FILE"
```

The coordinator's `Agent(researcher,implementer,reviewer)` entry is the
authoritative worker allowlist. The broader global `Agent` permission merely
makes the tool available.

## Escalate to agent teams only when needed

Coordinator-plus-subagents is the stable default. Add `--agent-teams` only when
workers must share a task list or communicate peer to peer. Agent teams are an
experimental Claude Code capability; record that fact in the run report and
partition writes because teammates share one project rather than isolated
worktrees.

Ask the lead explicitly to create the named teammates, assign owners, wait for
their terminal states, review their messages, and complete final validation.
Do not enable teams merely to parallelize independent one-shot work.

## Verify the orchestration

Confirm that every required worker actually ran, used the intended preloaded
skills and model, stayed within its scope, and returned observable evidence.
Independently inspect artifacts and run final validators. Treat skipped workers,
overlapping unauthorized edits, missing traces, or coordinator-only completion
as orchestration findings rather than a successful multi-agent run.

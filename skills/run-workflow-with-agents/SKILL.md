---
name: run-workflow-with-agents
description: Execute production workflows with one or more external agents, defaulting to Claude Code backed by DeepSeek V4 Flash. Use when Codex should complete real work by injecting one or more Codex skills into a single worker or a coordinated multi-agent topology, including implementation, research, review, validation, and other deliverable-producing workflows. Do not use for isolated testing or stress-testing of one skill; use test-skill-with-agent instead.
---

# Run a production workflow with agents

Complete real work through one agent or a coordinated group. Default every main
agent and worker to `deepseek-v4-flash`. Treat the external run as production:
preserve user data, enforce authority boundaries, validate artifacts, and return
the requested deliverable rather than an evaluation score.

## Define the workflow contract

Resolve from the request and local context:

- the intended outcome, task workspace, required artifacts, and finish checks;
- one or more skills required by the workflow;
- authorized reads, writes, external effects, tools, and MCP dependencies;
- a single-worker or coordinator-plus-workers topology;
- credential source and a reasonable spend/time boundary.

Use Codex's discovered skills as the default source. Accept an explicit skill
directory or additional skill root only when the user provides one. If no skill
is named, choose the smallest set whose descriptions clearly cover the task.
Do not inject unrelated skills.

Override `deepseek-v4-flash` only when the user explicitly selects another
model or the workflow already requires one. Do not convert a production request
into a benchmark or test matrix.

## Read and stage the skills

Read each selected `SKILL.md` completely and every resource it makes mandatory.
Check runtime compatibility before launch: a staged skill transfers instructions
and bundled files, not Codex-only tools. Supply an equivalent Claude Code tool
or approved MCP configuration for every mandatory dependency; stop and report
an incompatibility when no equivalent exists.

Stage one or more skills as physical project files:

```sh
python3 scripts/stage_skills.py \
  --project "$RUN_PROJECT" \
  --skill first-skill \
  --skill second-skill
```

Names resolve from workspace, personal, system, and installed-plugin Codex skill
roots. Explicit paths and `--skill-root` take precedence. The script fails on
ambiguous names, malformed manifests, existing destinations, and missing skills.

Inspect the project status before staging. Treat newly staged `.claude/skills`
directories as run-control artifacts, not deliverables, unless the user asks to
keep them. Record their exact paths and remove only those newly created paths
after the run and verification; never overwrite or remove a pre-existing skill.

## Choose the topology

Use one worker for a cohesive task that benefits from one context. Preload all
selected skills into it with repeated `--skill` arguments to
`scripts/run_deepseek.py`.

Use multiple agents when research, implementation, review, or validation can be
bounded independently. Always define one coordinator and named workers. Give
each worker only its required skills and tools; assign disjoint write ownership
or sequence dependent edits. Workers return results to the coordinator and
cannot spawn nested workers.

For multi-agent work, read and follow
[`references/multi-agent-orchestration.md`](references/multi-agent-orchestration.md).
Prefer coordinator-plus-subagents. Enable experimental agent teams only when
workers truly need a shared task list or peer-to-peer communication.

## Run through DeepSeek

Read and follow
[`references/claude-code-deepseek.md`](references/claude-code-deepseek.md).
The runner keeps credentials out of shell arguments, applies V4 Flash to the
main agent and every worker by default, validates preloaded skills, and invokes
Claude Code without a shell.

For a single worker:

```sh
python3 scripts/run_deepseek.py \
  --project "$RUN_PROJECT" \
  --key-file "$KEY_FILE" \
  --skill first-skill \
  --skill second-skill \
  --allowed-tool Read \
  --allowed-tool Grep \
  --allowed-tool Glob \
  --allowed-tool Bash \
  --prompt-file "$TASK_FILE"
```

Grant `Edit` and `Write` only for authorized write tasks. Pass approved MCP
configuration explicitly. Use `--max-budget-usd` when a bounded unattended run
benefits from a cap. Use `--dry-run` to inspect the credential-free command
before an expensive or high-impact launch.

Do not silently retry a failed workflow with a stronger prompt. Retry only a
transient provider error or a demonstrated harness defect, and record every
attempt.

## Verify and deliver

Independently inspect the actual artifacts and workspace after the run. Execute
the deterministic validators required by every injected skill and by the task.
Confirm that changes and external effects stayed inside the contract. The
external agent's self-report is not sufficient evidence of completion.

Report:

- the completed outcome and concrete artifacts;
- injected skills, topology, runtime, and actual model usage;
- changed files and validators run;
- provider, permission, orchestration, or compatibility limitations;
- remaining uncertainty or follow-up work.

Do not claim completion when a required worker was skipped, artifacts were not
inspected, validators did not run, or production scope was exceeded.

---
name: run-workflow-with-agents
description: Execute production workflows with one or more Claude Code, Codex, or OpenCode agents selected from a shared machine-local runtime profile. Gate first use on discovering installed agents, choosing the runtime, and recording subscription or API-file authentication before any staging, dry-run, or production work. Use when Codex should complete real work by injecting one or more Agent Skills into a single worker or coordinated multi-agent topology, including implementation, research, review, validation, and other deliverable-producing workflows. Do not use for isolated testing or stress-testing of one skill; use test-skill-with-agent instead.
---

# Run a production workflow with agents

Complete real work through one agent or a coordinated group. Treat the external run as production:
preserve user data, enforce authority boundaries, validate artifacts, and return
the requested deliverable rather than an evaluation score.

## Resolve the machine runtime before all workflow work

Read and follow
[`references/agent-runtime-profile.md`](references/agent-runtime-profile.md).
Run the profile `status` command before defining the workflow contract, reading
task Skills, inspecting or staging the project, building agent definitions, or
calling a provider. This gate applies to `--dry-run` too.

If the shared local profile is absent or incomplete and the user's current
prompt does not supply the missing choices, return only the detected-agent
summary and the profile's unanswered questions, then stop. When exactly one
agent is detected, select it without asking which agent to use.

If the prompt explicitly supplies the selected agent, subscription/API mode,
and, for API mode, an absolute credential-file path, run `configure` first and
then require a clean `status`. Store only the credential path, never the key.
Use the resolved agent's cached authentication/runtime entry for the complete
topology; never borrow credentials from the base agent. Do not replace it with
an ambient credential or a different executable.
Treat `selected_agent` as the cached base agent and never ask again while that
entry remains valid. Optional cached routes may override it by workflow, Skill,
or workflow-plus-Skill; when no route matches, use the base agent without
interaction. Pass a stable `--workflow` name when applying a named route.
When the user configures an additional routed agent without changing the base,
use `configure --keep-base` as described in the profile reference.

## Define the workflow contract

Resolve from the request and local context:

- the intended outcome, task workspace, required artifacts, and finish checks;
- one or more skills required by the workflow;
- authorized reads, writes, external effects, tools, and MCP dependencies;
- a single-worker or coordinator-plus-workers topology;
- a reasonable spend/time boundary.

Use Codex's discovered skills as the default source. Accept an explicit skill
directory or additional skill root only when the user provides one. If no skill
is named, choose the smallest set whose descriptions clearly cover the task.
Do not inject unrelated skills.

Override the cached runtime's model only when the user explicitly selects
another model or the workflow already requires one. Do not convert a production
request into a benchmark or test matrix.

## Read and stage the skills

Read each selected `SKILL.md` completely and every resource it makes mandatory.
Check runtime compatibility before launch: a staged skill transfers instructions
and bundled files, not product-specific tools. Supply an equivalent tool or
approved MCP configuration for every mandatory dependency in the selected
runtime; stop and report an incompatibility when no equivalent exists.

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

Inspect the project status before staging. Treat newly staged `.claude/skills`,
`.agents/skills`, or `.opencode/skills` directories as run-control artifacts,
not deliverables, unless the user asks to keep them. Record their exact paths
and remove only those newly created paths after the run and verification; never
overwrite or remove a pre-existing skill.

## Choose the topology

Use one worker for a cohesive task that benefits from one context. Preload all
selected skills into it with repeated `--skill` arguments to
`scripts/run_agents.py`.

Use multiple agents when research, implementation, review, or validation can be
bounded independently. Always define one coordinator and named workers. Give
each worker only its required skills and tools; assign disjoint write ownership
or sequence dependent edits. The runner translates that common JSON topology
to Claude `--agents`, Codex project custom agents, or OpenCode primary/subagents.
Workers return results to the coordinator and must not spawn nested workers.

Resolve cached agent routes for every worker Skill before staging. The current
coordinated runner uses one external runtime per session; if cached routes
select different agent products for different workers, stop with a compatibility
finding. Do not ask the user to choose again or silently collapse the routes.

For multi-agent work, read and follow
[`references/multi-agent-orchestration.md`](references/multi-agent-orchestration.md).
Prefer coordinator-plus-subagents. `--agent-teams` is a Claude Code-only
experimental escalation and must not be passed to Codex or OpenCode.

## Run through the cached runtime

Read and follow
[`references/claude-code-deepseek.md`](references/claude-code-deepseek.md) when
the profile selects Claude Code with the DeepSeek API. The runner keeps
credentials out of shell arguments, validates preloaded skills, and invokes
the cached executable without a shell. Subscription mode uses the agent's
existing local login and runtime-default model unless the user overrides it.

For a single worker:

```sh
python3 scripts/run_agents.py \
  --project "$RUN_PROJECT" \
  --skill first-skill \
  --skill second-skill \
  --allowed-tool Read \
  --allowed-tool Grep \
  --allowed-tool Glob \
  --allowed-tool Bash \
  --prompt-file "$TASK_FILE"
```

The runner reads the shared profile by default; pass `--runtime-profile` only
for an explicitly selected alternate local profile. Grant `Edit` and `Write`
only for authorized write tasks. Pass approved MCP configuration through the
selected runtime's project state; the runner's `--mcp-config` flag accepts
Claude Code config only. Use `--max-budget-usd` only with Claude Code. Use
`--timeout-seconds` for a runtime-neutral wall-clock boundary and `--dry-run`
to inspect the credential-free command before an expensive or high-impact launch.

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

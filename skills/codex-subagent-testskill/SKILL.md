---
name: codex-subagent-testskill
description: Default path for evaluating exactly one Agent Skill with fresh native Codex subagents inside the current Codex session. Run the contract once by default, or repeat it an explicit user-specified number of times for stability and stress testing, while recording per-run and total wall-clock time. Use for Skill discovery smoke tests, behavioral conformance, negative and safety cases, regression checks, repeated stability trials, and bounded concurrent trials when process-level runtime isolation is not required. Do not use for production deliverables or multi-Skill workflows; use codex-subagent-workflow for production work. Use codex-external-agent-testskill only when the user explicitly requests Claude Code, OpenCode, cross-runtime comparison, or fresh-process authentication.
---

# Test one Skill with Codex subagents

Test exactly one target Skill per contract. Use native Codex subagents as fresh
behavioral evaluators, then verify their observable work independently.

## Enforce the runtime boundary

Require native Codex subagent delegation in the active session. Never launch
`codex`, Claude Code, OpenCode, or another agent CLI through the shell or an API.
If native subagent tools are unavailable, stop and report that this Skill cannot
run in the current surface. Do not silently substitute an external runtime.

Treat this as the default for every single-Skill test unless the request names
Claude Code or OpenCode or requires external process/authentication isolation.

Treat each subagent as context-isolated but not process-, account-, or
filesystem-isolated. Native subagents share the current Codex runtime and may
share the workspace. If the contract specifically requires a clean process,
fresh login, provider comparison, or project-level discovery unaffected by the
current Codex installation, use `codex-external-agent-testskill` only with the
user's explicit external-runtime request.

## Define one atomic contract

Resolve:

- one target Skill name and physical `SKILL.md` path;
- one natural end-user task and a minimal fixture;
- smoke, conformance, negative/safety, regression, repeat, or bounded stress;
- mandatory artifacts, allowed output paths, invariants, and validators;
- run count and maximum concurrency within available native subagent slots.

Treat a run as one independent execution of the fixed target task and fixture.
Use `run_count = 1` unless the user gives a positive integer. Honor an explicit
count exactly. If it cannot be executed, stop before starting and explain the
constraint; never silently reduce or increase it. `run_count` repeats one case;
distinct smoke, negative, or safety cases are separate contracts and must be
enumerated explicitly. Default to one case and one run, even when the request
only says “stress test.” Default to sequential runs (`max_concurrency = 1`) so
durations remain comparable. Use bounded concurrency only when the user requests
it, and retain one native subagent slot for the coordinator.

Reject production work and contracts whose behavior depends on multiple target
Skills. A dependency that the target Skill itself mandates may be available to
the acting subagent, but it is fixture context rather than a second subject
under test.

Read the target `SKILL.md` completely and every resource it makes mandatory to
construct the harness. Do not put expected answers, suspected defects, previous
findings, hidden grading criteria, or intended fixes in run prompts.

## Isolate run context

Use a fresh fixture copy and a fresh native subagent for every run. Keep the
target Skill source, baselines, and result summaries outside writable run
directories. Do not modify the target Skill during a run.

Start each evaluator with no forked conversation history, or the smallest
context the active surface supports. Give it only:

- the target Skill name and absolute path;
- the raw end-user task;
- the fixture path and authorized output boundary;
- required validators and relevant tool limitations.

Tell the evaluator to load and follow the target Skill, stay within the fixture,
avoid nested delegation, validate its work, and return concrete artifacts and
evidence. Do not tell it that a particular behavior is expected to fail.

For repeated runs, keep the prompt, fixture, model, reasoning effort, and
validators identical unless the contract explicitly defines a matrix. Use the
current Codex model and reasoning configuration by default. Apply an available
override only when the user explicitly requests it. When explicit concurrency
exceeds available subagent slots, run bounded batches while retaining one slot
for the coordinator.

## Measure every run

Record coordinator-observed wall-clock time for every run. Capture an ISO 8601
start time immediately before dispatch and a finish time at terminal completion
or interruption, then calculate `duration_seconds`. This interval includes
native scheduling and tool time and is not provider telemetry. Also record:

- run index, terminal state, and whether it timed out;
- independent validation duration when measured separately;
- total harness elapsed time from contract setup through the final verdict.

For two or more completed repeated runs, report minimum, median, maximum, and
arithmetic mean duration, plus pass rate and distinct failure signatures. Keep
timeouts in the run table and exclude them from completed-run duration
statistics. Do not report percentiles for small samples or invent token, cost,
queue, or model telemetry that the native surface does not expose.

Set a reasonable terminal deadline for every evaluator. If it produces no
terminal result by that deadline, request one concise status update, then
interrupt it if it still does not finish promptly. Record the attempt as an
`orchestration` timeout with its elapsed duration; never wait indefinitely or
reinterpret silence as a behavioral result.

## Prove discovery before judging behavior

Require each evaluator to identify the loaded Skill and its physical manifest.
Treat a missing manifest, unavailable mandatory tool, skipped Skill load, agent
startup failure, or inability to create a fresh evaluator as a harness failure.
Do not reinterpret it as Skill behavior.

After repairing only a harness defect, restart with a fresh fixture and fresh
subagent. Never strengthen the task prompt between attempts to manufacture a
pass.

## Verify independently

For every run, inspect actual artifacts and run deterministic validators from
the target Skill and contract. Compare the fixture against its baseline and
confirm all writes stayed within the authorized boundary. A subagent's final
prose is not sufficient proof.

Classify findings as:

- `harness`: discovery, tool, fixture, or subagent-launch failure;
- `behavior`: mandatory Skill instruction was observably violated;
- `artifact`: output is missing, invalid, or inconsistent with evidence;
- `safety`: unauthorized write, secret exposure, or forbidden external effect;
- `orchestration`: run contamination, skipped evaluator, nested delegation, or
  evaluator terminal timeout.

Do not automatically turn an orchestration timeout into a target behavior or
artifact failure. If the artifacts can still be audited safely, report their
conformance separately and use `pass with findings` unless timely terminal
delivery was itself an explicit contract requirement.

## Iterate without contaminating runs

When the user authorizes iteration, finish and record the current run before
editing the target Skill. Apply the smallest evidence-backed change, rebuild
fresh fixtures, and rerun the original contract. Keep pre-fix and post-fix
results separate.

## Report the result

Lead with `pass`, `pass with findings`, or `fail`. Include the target Skill and
manifest, case type, requested and executed run counts, maximum concurrency,
native Codex topology, model override if any, fixture authority, validators,
changed files, findings by classification, and the smallest recommended fix.
Include a per-run timing table, aggregate timing statistics when repeated, and
total harness elapsed time. Use the columns `run`, `started_at`, `finished_at`,
`duration_seconds`, `validation_seconds`, `terminal_state`, and `target_result`;
write `not measured` instead of inventing a missing validation duration. State
the behavioral-isolation limitation.

Never claim a pass when discovery failed, required validators were skipped, an
evaluator saw leaked conclusions, or only self-reported prose was inspected.

---
name: codex-subagent-testskill
description: Default path for evaluating exactly one Agent Skill with fresh native Codex subagents inside the current Codex session. Use for Skill discovery smoke tests, behavioral conformance, negative and safety cases, regression checks, repeated stability trials, and bounded concurrent trials when process-level runtime isolation is not required. Do not use for production deliverables or multi-Skill workflows; use codex-subagent-workflow for production work. Use codex-external-agent-testskill only when the user explicitly requests Claude Code, OpenCode, cross-runtime comparison, or fresh-process authentication.
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
- trial count and maximum concurrency within available native subagent slots.

Reject production work and contracts whose behavior depends on multiple target
Skills. A dependency that the target Skill itself mandates may be available to
the acting subagent, but it is fixture context rather than a second subject
under test.

Read the target `SKILL.md` completely and every resource it makes mandatory to
construct the harness. Do not put expected answers, suspected defects, previous
findings, hidden grading criteria, or intended fixes in trial prompts.

## Isolate trial context

Use a fresh fixture copy and a fresh native subagent for every trial. Keep the
target Skill source, baselines, and result summaries outside writable trial
directories. Do not modify the target Skill during a trial.

Start each evaluator with no forked conversation history, or the smallest
context the active surface supports. Give it only:

- the target Skill name and absolute path;
- the raw end-user task;
- the fixture path and authorized output boundary;
- required validators and relevant tool limitations.

Tell the evaluator to load and follow the target Skill, stay within the fixture,
avoid nested delegation, validate its work, and return concrete artifacts and
evidence. Do not tell it that a particular behavior is expected to fail.

For repeated trials, keep the prompt, fixture, model, reasoning effort, and
validators identical unless the contract explicitly defines a matrix. Use the
current Codex model and reasoning configuration by default. Apply an available
override only when the user explicitly requests it. Run trials in bounded
batches when the requested count exceeds available subagent slots, retaining
one slot for the coordinator.

Set a reasonable terminal deadline for every evaluator. If it produces no
terminal result by that deadline, request one concise status update, then
interrupt it if it still does not finish promptly. Record the attempt as an
`orchestration` timeout; never wait indefinitely or reinterpret silence as a
behavioral result.

## Prove discovery before judging behavior

Require each evaluator to identify the loaded Skill and its physical manifest.
Treat a missing manifest, unavailable mandatory tool, skipped Skill load, agent
startup failure, or inability to create a fresh evaluator as a harness failure.
Do not reinterpret it as Skill behavior.

After repairing only a harness defect, restart with a fresh fixture and fresh
subagent. Never strengthen the task prompt between attempts to manufacture a
pass.

## Verify independently

For every trial, inspect actual artifacts and run deterministic validators from
the target Skill and contract. Compare the fixture against its baseline and
confirm all writes stayed within the authorized boundary. A subagent's final
prose is not sufficient proof.

Classify findings as:

- `harness`: discovery, tool, fixture, or subagent-launch failure;
- `behavior`: mandatory Skill instruction was observably violated;
- `artifact`: output is missing, invalid, or inconsistent with evidence;
- `safety`: unauthorized write, secret exposure, or forbidden external effect;
- `orchestration`: trial contamination, skipped evaluator, or nested delegation.

For repeated trials, report pass rate and distinct failure signatures. Do not
claim process isolation, provider-cost metrics, or model telemetry that the
native subagent surface does not expose.

## Iterate without contaminating trials

When the user authorizes iteration, finish and record the current trial before
editing the target Skill. Apply the smallest evidence-backed change, rebuild
fresh fixtures, and rerun the original contract. Keep pre-fix and post-fix
results separate.

## Report the result

Lead with `pass`, `pass with findings`, or `fail`. Include the target Skill and
manifest, trial type and count, native Codex topology, model override if any,
fixture authority, validators, changed files, findings by classification, and
the smallest recommended fix. State the behavioral-isolation limitation.

Never claim a pass when discovery failed, required validators were skipped, an
evaluator saw leaked conclusions, or only self-reported prose was inspected.

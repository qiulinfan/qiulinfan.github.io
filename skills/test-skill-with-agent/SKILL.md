---
name: test-skill-with-agent
description: Atomically evaluate exactly one Agent Skill with isolated external-agent trials, defaulting to Claude Code backed by DeepSeek V4 Flash. Use for skill smoke tests, behavioral conformance, negative and safety cases, regression testing, repeated flakiness checks, or bounded concurrent stress tests. Do not use for production workflows or multi-skill deliverables; use run-workflow-with-agents instead.
---

# Test one skill with agents

Evaluate exactly one target skill per test contract. Use disposable fixtures,
independent trials, and observable evidence. Never treat the tested agent's
self-report as sufficient proof.

## Define the atomic contract

Resolve:

- one target skill directory or Codex skill name;
- a minimal fixture and natural user request;
- trial type: smoke, conformance, negative/safety, regression, repeat, or stress;
- expected invariants, mandatory artifacts, allowed output paths, and validators;
- trial count, maximum parallelism, credential source, and per-trial budget.

Reject a contract that requires multiple target skills or a production
deliverable. Test one skill in isolation so failures remain attributable.
Default every trial to `deepseek-v4-flash`; override only when the user requests
a model comparison or a specific provider configuration.

Read the complete target `SKILL.md` and every resource it makes mandatory before
building the fixture. Treat this as harness setup. Do not include expected
answers, suspected bugs, prior findings, or hidden grading criteria in the
agent prompt.

## Isolate every trial

Use a fresh physical copy of the fixture for every trial. Keep source skills,
credentials, result logs, and baselines outside trial projects. Stage only the
single target skill:

```sh
python3 scripts/stage_skill.py \
  --project "$TRIAL_PROJECT" \
  --skill target-skill
```

The skill name resolves from Codex's workspace, personal, system, and installed
plugin roots; pass an explicit directory or `--skill-root` for another source.
Never reuse a writable project, session, or staged skill between trials.

Snapshot each fixture after staging and before execution:

```sh
python3 scripts/workspace_guard.py snapshot "$TRIAL_PROJECT" \
  --output "$GUARD_FILE"
```

For review-only tests, omit edit tools. Remember that `Bash` can still write;
the workspace comparison is the independent enforcement layer.

## Prove discovery before behavior

Run the smallest invocation that proves the runtime recognizes the target
skill. Verify that `SKILL.md` is a regular project skill file and that the
runtime launched from the intended fixture. An unknown skill, disabled skill,
or zero-turn result is a `harness` failure, not model behavior.

After fixing only a harness defect, restart with a fresh trial and record the
failed attempt and any incurred API usage.

## Run single or stress trials

Read and follow
[`references/claude-code-deepseek.md`](references/claude-code-deepseek.md).
Use `scripts/run_trials.py` to run one or many isolated copies with the same
atomic contract. It stages one skill per copy, applies V4 Flash by default,
keeps credentials out of command arguments, records structured results and
workspace diffs, and supports bounded concurrency.

```sh
python3 scripts/run_trials.py \
  --skill target-skill \
  --fixture "$FIXTURE_TEMPLATE" \
  --output "$RESULT_ROOT" \
  --key-file "$KEY_FILE" \
  --prompt-file "$TASK_FILE" \
  --trials 1 \
  --parallel 1 \
  --allowed-tool Read \
  --allowed-tool Grep \
  --allowed-tool Glob \
  --allowed-tool Bash
```

For repeat or stress testing, increase `--trials` and set conservative
`--parallel` and `--max-budget-usd-per-trial`. Keep prompts, fixtures, tools,
model, and validators identical unless the contract explicitly defines a
matrix. Distinguish provider saturation and rate limits from skill failures.
Do not silently strengthen prompts between trials.

## Verify independently

For every trial:

1. Parse runtime status, actual model usage, turns, duration, cost, API errors,
   permission denials, and terminal reason when available.
2. Inspect actual artifacts and run deterministic validators required by the
   target skill.
3. Compare the workspace with its baseline and check credential occurrences.
4. Compare observable behavior against mandatory target-skill instructions.

Treat an unobservable mandatory step as a finding, not a pass. Classify findings
as `harness`, `provider`, `behavior`, `artifact`, or `safety`.

For repeated trials, aggregate pass rate, failure signatures, latency and cost
distribution, model usage, and provider errors. Do not call provider instability
a behavioral regression, and do not hide flaky skill behavior inside an
aggregate success rate.

## Report the result

Lead with `pass`, `pass with findings`, or `fail`. Include the exact target
skill, fixture authority, trial type and count, concurrency, runtime, actual
models, attempts, cost, deterministic evidence, changed files, credential
occurrence count, findings by classification, and the smallest recommended fix.

Never claim a pass when discovery failed, validators or safety checks were
skipped, or only the agent's final prose was inspected.

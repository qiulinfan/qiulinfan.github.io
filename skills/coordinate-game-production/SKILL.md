---
name: coordinate-game-production
description: Coordinate a game idea or production issue across design, Unity programming, sourced-art, and independent playtest workers, then integrate and accept the verified result. Use when a producer agent must classify work as a level, feature, system, or mixed change; create bounded child issues; enforce ownership and dependencies; require reviewable play evidence for player-facing work; and close the production loop without doing every specialty itself.
---

# Coordinate Game Production

Act as the production bus. Own routing, dependency order, integration decisions, and final acceptance; keep specialist execution with the specialist agents.

## Establish the parent contract

Read the complete parent issue and the project's authoritative design, architecture, and asset records. Record:

- the player or creator outcome;
- confirmed constraints and explicit non-goals;
- the target project, scene, module, and platform when known;
- observable acceptance evidence;
- unresolved decisions that would materially change scope.

Ask only for decisions that cannot be recovered from project evidence and would make implementation branches meaningfully different.

Read enough architecture to understand repository boundaries, authoritative generators, integration surfaces, and acceptance risks. Do not duplicate a specialist's exhaustive source review: consume the planner's design brief and the programmer's architecture evidence, then inspect only the additional files needed for routing or final integration. Preserve rigorous planning when the issue is open-ended; when the parent is specific, carry its exact constraints and non-goals into the planner issue so the planner can stay equally rigorous within the narrower search space.

## Classify the work

Choose one primary route:

| Route | Use when | Required loop |
| --- | --- | --- |
| Design discovery | The behavior or rules are not implementable yet | Design brief only, then re-triage |
| Level | The request changes spatial layout, encounter flow, pacing, or a playable scenario | `iterate-unity-level` |
| Feature | The request adds a player-facing capability or interaction | `deliver-unity-feature` |
| System/module | The request adds reusable state, data, services, tools, or infrastructure | `deliver-unity-feature` |
| Mixed | A feature/system and one or more levels depend on each other | Feature contract first, then level integration |

Do not disguise a module as a level merely because it needs a Unity test scene.

## Build the dependency graph

Use these ownership boundaries:

- The planner owns design briefs, rules, states, content requirements, and testable acceptance criteria. It does not implement.
- The art worker only discovers, verifies, acquires, audits, and imports external resources. It does not invent gameplay code or autonomously model and texture assets.
- The programmer owns code, scene wiring, prefabs, tests, technical validation, and fixes.
- The playtester owns read-only player-like acceptance, defect reproduction, Windows window recording, evidence validation, and Drive delivery. It does not modify the project or repair defects.
- The producer owns scope, sequencing, conflict resolution, integration review, and final closure.

Dispatch the planner first when behavior is underspecified. Start art discovery only after visual roles, required actions, and technical constraints are stable enough to search. Let independent art and programming work run in parallel only when their write surfaces do not overlap.

## Fix the shared worktree contract

Every child that can write must name one canonical absolute target worktree and absolute output paths. For Dreamweaver, use `C:\Users\rynne\Desktop\dreamweaver`; never treat a Multica task's isolated `work_dir` as the production checkout. A child may use its isolated directory only for temporary files that will not become delivery artifacts.

Require each writing child to:

1. resolve and print the canonical worktree before mutation;
2. perform the first intended write through an absolute path and use absolute target paths for every later mutation;
3. immediately verify that exact path and run a path-scoped status check from the canonical root;
4. stop and report `WRONG_WORKTREE` if the file is absent there or appears only in the isolated run directory;
5. use the canonical root for every later Git command and handoff.

Preserve the repository's configured remote and authentication transport. Dreamweaver is a private repository with working SSH credentials; do not rewrite its remote to HTTPS.

## Dispatch bounded child issues

Before creating work, inspect live Multica state, resolve exact agent and runtime IDs, and search for an existing active child with the same parent and deliverable. Create each child exactly once.

Every child issue must include:

1. Parent issue identifier and route.
2. One owned deliverable.
3. Authoritative inputs and target paths.
4. In-scope and out-of-scope work.
5. Write boundaries and dependency blockers.
6. Acceptance checks and required evidence.
7. Handoff recipient and expected artifact format.
8. Canonical absolute worktree plus the first-write verification command.
9. Source-control policy inherited from the parent.

Assign by exact agent ID, not a display-name guess. Do not retry or duplicate a failed dispatch without first determining whether the original issue or run exists.

A bounded issue means one owned deliverable and explicit boundaries, not a short prompt. Planner and programmer issues may be long when detailed rules, architecture constraints, edge cases, or acceptance checks reduce ambiguity.

Create only the currently ready dependency stage; do not pre-create or park future-stage children. Every staged child must publish its evidence and then set its own issue to `done` so Multica emits the stage-completion wakeup. In this protocol, child `done` means "specialist delivery is ready for producer review," not "the parent contract is accepted." The producer still inspects the actual artifact and may reopen or route a bounded fix when acceptance fails.

Unless the parent explicitly says `no push`, authorize the writing worker to commit only its owned changes, push its task branch through the repository's existing remote, and create or update a draft PR when the host and authenticated tooling support it. Preserve unrelated dirty changes. If the parent says `no push`, do not push or create a PR; report the local commit or diff instead.

## End each stage and wait for events

Treat stage completion as an event-driven handoff:

1. At the beginning of a producer Run, inspect the parent, relevant completion event, ready children, and repository status once.
2. Integrate any child that just completed, checking repository status once for that completion.
3. Create or enqueue only the children ready in the next dependency stage exactly once; require each child to publish evidence and mark itself `done` on delivery.
4. Record the child issue IDs, task IDs, and each observed message cursor in the parent checkpoint or handoff.
5. End the producer Run immediately after dispatch. Do not keep a shell loop, `Start-Sleep`, repeated `issue runs`, or repeated repository checks alive while children work.
6. Let the child-completion mention or stage-completion event create the next producer Run. On wake, deduplicate against recorded child IDs before taking action.

Normal stage coordination uses event wakeups, not polling. If an expected event is missing and the user or an operational recovery Run explicitly asks for observation, check at most once every 120 seconds. Read `issue run-messages` with `--since <last_seq>` and advance the stored cursor after every response; never reread the full message history. Check Git status only at producer Run start, immediately after a child completion, and during final acceptance.

## Integrate and accept

Review outputs against the parent contract rather than accepting child completion labels. Route findings back to the responsible owner:

- design ambiguity to the planner;
- licensing, provenance, missing animation, or import defects to art;
- code, scene, console, test, or gameplay defects to programming.

Require a clean verification run after fixes. For player-facing work, dispatch an independent playtester only after the programmer identifies the exact playable target and revision. Require a written verdict plus a validated Windows MP4 and receipt delivered through the approved evidence location. For stateful or resettable work, require a fresh second completion after reset or reload. Route gameplay defects to programming and recorder or delivery defects to the playtester. Close the parent only when the integrated project, evidence, licenses, and documentation agree.

Do not create an autopilot, scheduled poller, daemon, or recurring automation unless the user explicitly requests that persistent behavior.

## Language alignment

Match user-facing explanations, prompts, issue bodies, and handoffs to the user's language unless the user requests another language. Keep commands, identifiers, structured keys, action codes, and raw errors unchanged.

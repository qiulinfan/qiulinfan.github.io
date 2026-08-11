---
name: coordinate-game-production
description: Coordinate a game idea or production issue across design, Unity programming, and sourced-art workers, then review and accept the programmer's verified delivery. Use when a producer agent must classify work as a level, feature, system, or mixed change; create bounded child issues; enforce ownership and dependencies; require the programmer to provide reviewable play evidence for player-facing work; and close the production loop without a separate playtester stage.
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
- The programmer owns code, scene wiring, prefabs, tests, technical validation, player-path verification, delivery evidence, and fixes.
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

## Bind Unity work to the existing canonical Editor

For every child that uses Unity or Unity MCP, require the already-running Unity Editor whose project root exactly equals the canonical worktree. For Dreamweaver, that root is `C:\Users\rynne\Desktop\dreamweaver`. The Unity project root and the file-mutation root must be the same directory.

The producer and every Unity-capable child must enforce these rules:

1. Never launch Unity, Unity Hub, a second Editor, or an MCP server as a task fallback. Never open an isolated Multica `work_dir` as a Unity project.
2. Before the first Unity operation, enumerate MCP instances, resolve the intended instance, and verify its reported project root against the canonical path. Do not select an instance by display name alone.
3. Continue only when exactly one healthy matching instance is available. Stop with `UNITY_EDITOR_NOT_RUNNING`, `UNITY_MCP_UNAVAILABLE`, `UNITY_INSTANCE_AMBIGUOUS`, or `UNITY_PROJECT_MISMATCH` as appropriate; include observed instance IDs and roots without mutating the project.
4. Treat the canonical desktop Editor as the owner of its managed MCP server. If the bridge disappears, hand the failure to operational repair and wait for a new event. Do not repair it by starting an isolated Editor or independent long-lived server.
5. Re-check the matched instance after an Editor restart, domain reload, branch switch, or bridge reconnect before resuming mutations.

Carry this Editor-binding contract verbatim into programming, art-import, and scene-integration child issues. The programmer may launch a standalone player when the issue identifies that build; this does not authorize a second Unity Editor.

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
10. For Unity work, the existing-Editor binding, exact project-root check, and non-launch failure codes.

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

Require a clean verification run after fixes. The programmer is the final implementation and player-path verification worker: for player-facing work, it must use `play-unity-game` against the exact playable target and revision, report a written verdict, and provide concise reviewable evidence such as test results, clean Console state, screenshots, or structured observations. For stateful or resettable work, require a fresh second completion after reset or reload.

After the programmer marks its child `done`, the producer reviews the delivered revision, automated tests, gameplay evidence, reset evidence when applicable, licenses, and documentation. If the contract fails, route one bounded defect issue back to the responsible planner, art worker, or programmer. If it passes, close the parent directly. Do not dispatch a separate playtester, recording, or evidence-repair stage, and do not make MP4, receipt, or Drive delivery a default acceptance gate. If the parent explicitly requests a recording artifact, assign that artifact to the programmer without introducing a separate playtester role.

Do not create an autopilot, scheduled poller, daemon, or recurring automation unless the user explicitly requests that persistent behavior.

## Language alignment

Match user-facing explanations, prompts, issue bodies, and handoffs to the user's language unless the user requests another language. Keep commands, identifiers, structured keys, action codes, and raw errors unchanged.

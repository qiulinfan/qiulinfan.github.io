---
name: play-unity-game
description: Play and evaluate a Unity game or scene after implementation, using the Unity Editor and the closest available player-like input path. Use when Codex needs to actually play a Unity build or Editor scene, verify a gameplay loop, reproduce a gameplay bug, inspect feel and feedback, capture milestone evidence, check reset/replay and soft-lock behavior, or provide a read-only playtest report for design, art, or programming work. Do not use this skill to implement fixes or build scenes unless the user separately asks for changes.
---

# Play Unity Game

Treat playtesting as an independent verification pass. Play the current artifact, gather evidence, and report what happened without quietly fixing it.

## Establish the Test Target

1. Locate the Unity project from the current directory by finding `Assets/`, `Packages/`, and `ProjectSettings/`.
2. Check project instructions and the relevant design or acceptance documents.
3. Identify the intended scene or build, controls, expected loop, success condition, failure states, and reset path.
4. Inspect the worktree before testing. Preserve unrelated user changes.
5. If the target or completion condition cannot be inferred, report the exact missing information instead of inventing a pass criterion.

## Connect to Unity Safely

1. Check `mcpforunity://custom-tools` before using Unity tools.
2. Read `mcpforunity://instances`; select the intended instance when more than one is connected.
3. Read the exact editor-state resource URI exposed by the server.
4. Confirm that Unity is not compiling, changing play mode, or running tests.
5. Inspect the active scene, build settings, hierarchy summary, and current Console.
6. Do not modify source assets, scenes, settings, or scripts during a read-only playtest.

## Choose the Input Path

Use the closest available path to real player behavior:

1. Prefer a project-provided playtest tool or harness that sends normal gameplay commands.
2. Otherwise focus the Game View and use desktop keyboard/mouse control.
3. Otherwise use a documented input-injection tool that drives the configured Input System actions.
4. Only as a fallback, invoke public debug commands or state-path automation.

When using fallback automation, label the result **automated gameplay-path verification**, not a human-like playtest. Do not claim that movement, aiming, timing, discoverability, or feel was tested if normal input was unavailable.

Never use private-field mutation or reflection to manufacture a passing result. It may be used only for diagnosis after the real path has failed, and must be disclosed.

## Run the Session

Clear only ephemeral Console entries when a clean baseline is useful.

Test at least:

1. **Launch:** enter Play Mode or launch the requested build; confirm the expected scene and initial state.
2. **Orientation:** discover the goal and controls from the game, not hidden implementation knowledge.
3. **Primary loop:** complete the intended happy path using normal interactions.
4. **Rule or failure feedback:** attempt one plausible invalid action and observe whether the response is understandable.
5. **State transitions:** verify major intermediate states, not only the final screen.
6. **Recovery:** exercise restart, retry, undo, pause, or safe exit as applicable.
7. **Robustness:** look for soft locks, lost key items, blocked navigation, duplicate rewards, broken collision, and repeated-trigger bugs.
8. **Replay:** verify that reset or replay restores the intended initial state when the feature exists.

Capture evidence at meaningful milestones. Prefer inline screenshots; if files are required, place temporary captures under the project `Temp/` directory unless the user requests durable artifacts.

Monitor the Console during and after play. Distinguish project errors from Editor, package, capture-tool, or transport warnings.

## Evaluate by Discipline

### Design

- Is the goal discoverable?
- Can the player explain why an action succeeded or failed?
- Does the loop create the intended decision or realization?
- Are exit and true completion clearly different when required?

### Art

- Are important objects readable at play distance?
- Do composition, lighting, animation, and color support navigation and state changes?
- Are placeholders or missing assets visible?
- Does UI remain legible at the tested Game View size?

### Programming

- Are state transitions deterministic?
- Do collisions, triggers, input, reset, and scene loading work?
- Does the Console stay free of project errors?
- Can the player recover from failed experiments?

## Leave Unity in a Safe State

1. Stop Play Mode unless the user explicitly asks to leave it running.
2. Do not save runtime-only state back into the scene.
3. Remove only temporary evidence created by this session when it is no longer needed.
4. Leave source files unchanged.

## Report

Lead with `PASS`, `PASS WITH ISSUES`, `FAIL`, or `BLOCKED`.

Include:

- Unity version, target scene/build, and input path;
- scenarios actually tested;
- observed milestone sequence;
- issues ordered by severity, each with reproduction steps, expected result, actual result, and evidence;
- Console result;
- aspects not tested or only verified through automation;
- recommended owner: design, art, programming, or cross-discipline.

Do not implement fixes during this skill. Hand actionable findings back to the responsible agent.

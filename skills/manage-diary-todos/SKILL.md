---
name: manage-diary-todos
description: Maintain the user's cached Diary repository todo list and completion journal from any conversation. Use when the user asks to add, prioritize, postpone, edit, complete, reopen, or remove a Diary todo, or to record a verified completion. Do not use for persona distillation, external actions, email sending, or Git synchronization.
---

# Manage Diary Todos

Maintain the canonical Diary todo files without depending on the conversation's current working directory.

## Resolve the Diary repository

1. Read [references/paths.json](references/paths.json) completely.
2. Use `diaryRepoRoot` only after verifying that it is a Git root and contains every `requiredMarker`.
3. Resolve the cached relative paths beneath that root and reject any path that escapes it.
4. Before writing, read the repository `AGENTS.md`, cached config, protocol, state, and todo files completely. The repository protocol is authoritative when it is stricter than this Skill.

If the cached root is missing, moved, not a Git root, or lacks a marker, stop and ask the user for the new Diary repository root. Do not search arbitrary home directories. Update the cache only when the user supplies or confirms the replacement path.

## Scope and authorization

- A direct user request to change a Diary todo authorizes only the todo-bot files and monthly diary entry required for that change.
- Preserve unrelated text and existing worktree changes. Use the runtime's patch-oriented file editor; use `apply_patch` when that tool is available.
- Do not modify `Meta/人格记录.md`; it is a static snapshot unless the user separately invokes its repository-defined explicit distillation trigger.
- Never send, reply to, or forward email. Drafts may be prepared in other workflows, but final sending always belongs to the user.
- Do not perform external actions, course submissions, purchases, appointments, or Git synchronization through this Skill.
- Match user-visible explanations, prompts, and handoffs to the user's language unless the user requests another language. Keep commands, identifiers, structured keys, action codes, and raw errors unchanged.

## Update active todos

- Preserve the existing `T0` / `T1` / `T2` / `已完成` structure and the user's wording.
- Add an actionable item and a reliable deadline when one is known.
- Respect an explicit user priority. Otherwise follow the priority rules in the cached config and protocol.
- Normalize the task text and check for an existing equivalent item before adding one. Update the existing item when the fact is the same.
- For postponement or deadline changes, edit the existing item in place rather than creating a duplicate.
- Do not infer completion from disappearance, unread state, generic progress, or a guessed outcome.

## Record a completion

Only complete an item when the user explicitly says it is done, it is already checked, or the repository protocol recognizes an authoritative completion signal.

1. Move the original active item to `已完成` with `- [x]`; retain the original task text and append only newly supplied clarification when useful.
2. Build a stable fingerprint as SHA-256 of `sourceId + "\0" + normalizedOriginalTask`. Use the configured source ID when the item has one, otherwise `manual`. Normalize by removing the Markdown list marker or checkbox, trimming surrounding whitespace, and collapsing internal whitespace.
3. Check `state.json.journaledCompletions`. If the fingerprint already exists, do not journal it again.
4. Otherwise append a 1–3 sentence completion note to the local-date `YY-MM.md` under `## M/D`. Its first text must begin with `[机器人代记]` and contain only verifiable facts supplied by the user or authoritative source.
5. Add the fingerprint, source ID, normalized original task, local completion date, evidence type, and diary filename to `journaledCompletions`.

When reopening a formerly completed task, preserve the historical diary note and completion receipt; create the newly requested active work without rewriting history.

## Validate and report

After any edit:

1. Re-read every changed section and verify the todo, diary note, and state receipt agree.
2. Run the cached validator with `python3` or `python`; if neither is available, perform equivalent JSON, marker, relative-path, source-ID, and duplicate-fingerprint checks.
3. Run `git diff --check` in the Diary repository and inspect the scoped diff without staging it.
4. Report what changed, any remaining blockers, and validation results. Do not claim completion when evidence is missing.

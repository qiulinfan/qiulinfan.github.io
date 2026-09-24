# Personal agent guidance

This file is the runtime-neutral core of the personal global guidance maintained
in qlblog. Every supported coding-agent runtime installs it together with the
runtime-specific section appended below. To change it, edit
`install/agents/core.md` or `install/<runtime>/runtime.md` in qlblog and run
`make agents-guidance`; never edit the generated files.

## General engineering defaults

Apply these defaults only when the user's request and closer project guidance
do not specify otherwise:

- Choose the simplest coherent implementation that fully satisfies the current
  requirements. Avoid speculative abstractions, configuration layers, and
  indirection.
- Deliver non-trivial systems in working end-to-end slices. Add capabilities on
  top of a runnable baseline; do not replace verified behavior with unfinished
  complexity.
- Keep components cohesive and concerns separated, but do not create
  abstractions or layers without a concrete responsibility.
- Before adding a dependency or reimplementing common functionality, inspect
  the project's existing dependencies and consult their current documentation
  and types. Prefer established, well-maintained libraries when they reduce
  total complexity or improve reliability.
- For consequential or hard-to-reverse design decisions, inspect the
  repository's existing patterns and, when useful, established products or
  reference implementations before inventing a custom approach.
- Prefer durable architectural choices. When a temporary stopgap is necessary,
  make the trade-off explicit, bound its scope, and record the condition for
  removing it.
- Do not add compatibility layers, fallbacks, or migrations by default. First
  determine whether users, persisted data, public interfaces, or deployment
  constraints require compatibility; never remove or break them without clear
  scope and authorization.

## Email sending boundary

- Never send, reply to, or forward an email on the user's behalf. When the user
  asks to communicate by email, prepare or update an unsent draft and tell the
  user to review and send it themselves. Final sending is always a user-only
  action, regardless of the recipient, urgency, or wording such as “handle,”
  “reply,” “report,” or “send.”

## Personal Skills

- Before creating, updating, moving, renaming, or removing a personal Skill,
  agent, or multi-Skill workflow, before installing or updating a third-party
  Skill, and whenever a Skill-authoring Skill such as `skill-creator` is used,
  load the `manage-skills` Skill and follow it.

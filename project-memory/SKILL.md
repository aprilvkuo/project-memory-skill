---
name: project-memory
description: Maintain durable project memory for Claude Code projects. Use when the user invokes /project-memory or asks to initialize project memory, restore context at session start, update memory from current work, summarize git diff into memory, or create a handoff for the next session.
---

# Project Memory

## Purpose

Use this skill to keep project context outside the chat transcript so new Claude Code sessions can resume quickly. Treat project memory as concise operational state, not a diary.

Supported actions:

- `init`: Create the memory file structure for the current project.
- `start`: Restore project context at the beginning of a session.
- `update`: Update durable memory from the current conversation, git diff, recent commits, and current file state.
- `handoff`: First perform the useful parts of `update`, then write a short next-session handoff.

If the user invokes `/project-memory` without an action, infer the action from their wording. If unclear, show the four actions and ask which one they want.

## Files

Use this project-local structure:

```text
CLAUDE.md
docs/project-memory/current-state.md
docs/project-memory/decisions.md
docs/project-memory/task-log.md
docs/project-memory/session-handoff.md
```

If the project already has equivalent memory files, preserve them and adapt to the existing structure instead of creating duplicates. If the project uses Git, do not overwrite unrelated user changes.

## Action: init

Create missing files only. Do not replace existing memory files without explicit user approval.

Create or update `CLAUDE.md` with a concise "Project Memory" section that says:

```markdown
## Project Memory

At session start, use `/project-memory start` to read:
- docs/project-memory/current-state.md
- docs/project-memory/decisions.md
- docs/project-memory/task-log.md
- docs/project-memory/session-handoff.md

Before ending substantial work, use `/project-memory handoff`.
Use `/project-memory update` after meaningful implementation, debugging, research, or planning progress.
Keep memory concise, factual, and useful for the next session.
```

Create `docs/project-memory/current-state.md`:

```markdown
# Current State

## Last Updated

Not updated yet.

## Project Goal

Unknown.

## Current Focus

Unknown.

## What Exists Now

- Unknown.

## Recent Changes

- None recorded yet.

## Open Issues

- None recorded yet.

## Next Steps

1. Clarify the current goal.

## Notes For Future Sessions

- Run `/project-memory start` before continuing work.
```

Create `docs/project-memory/decisions.md`:

```markdown
# Decisions

No decisions recorded yet.
```

Create `docs/project-memory/task-log.md`:

```markdown
# Task Log

No tasks recorded yet.
```

Create `docs/project-memory/session-handoff.md`:

```markdown
# Session Handoff

No handoff recorded yet.
```

After initialization, tell the user which files were created and suggest running `/project-memory update` once there is real project context.

## Action: start

Read the memory files that exist. Also inspect nearby project files when useful:

- `README.md`, `package.json`, `pyproject.toml`, `Cargo.toml`, or similar project entry files
- recent git commits with `git log --oneline -5` when the project is a git repo
- current working tree status with `git status --short` when available

Then respond with:

- current project state
- active focus
- open issues
- recommended next action
- any memory files that are missing or stale

Do not edit files during `start` unless the user explicitly asks.

## Action: update

Update durable memory after meaningful progress.

Gather context:

- Read existing project memory files.
- Check `git status --short` if available.
- Inspect `git diff --stat` and relevant diffs when available.
- Check recent commits with `git log --oneline -5` when useful.
- Use the current conversation for intent, decisions, and unresolved questions.

Update `current-state.md`:

- Set `Last Updated` to today's date.
- Keep `Project Goal` stable unless the user changed it.
- Update `Current Focus`.
- Summarize what exists now.
- Replace or compress `Recent Changes` to the most useful recent facts.
- Keep `Open Issues` current.
- Keep `Next Steps` short and actionable.
- Preserve important `Notes For Future Sessions`.

Update `decisions.md` only when a real decision was made or changed. Use this format:

```markdown
## YYYY-MM-DD: Short decision title

**Decision:** What was decided.
**Reason:** Why this choice was made.
**Tradeoff:** What this choice gives up or constrains.
```

Update `task-log.md` by prepending a short dated entry:

```markdown
## YYYY-MM-DD: Short task summary

- Completed: what changed.
- Verified: commands, checks, or review performed.
- Remaining: unresolved work or risks.
```

Do not write vague filler. Do not record transient chat, speculation, or private chain-of-thought. If there is not enough information to update a section, leave it concise and mark the uncertainty plainly.

## Action: handoff

Use this when the user is about to close the session, switch models, compact context, or continue later.

First perform the relevant context gathering from `update`. Update `current-state.md`, `decisions.md`, and `task-log.md` when there are meaningful changes.

Then overwrite `session-handoff.md` with a concise next-session handoff:

```markdown
# Session Handoff

## Start Here

1. Read CLAUDE.md.
2. Read docs/project-memory/current-state.md.
3. Read docs/project-memory/decisions.md.

## Current Focus

One or two sentences.

## Last Completed

- Most important completed item.

## Next Action

The single best next action.

## Watch Outs

- Important constraints, risks, or things not to refactor.

## Useful Files

- `path/to/file`: why it matters.
```

Keep handoff under about 300 words unless the project is genuinely complex.

## Quality Rules

- Prefer concise, stable facts over exhaustive history.
- Preserve user-authored content unless replacing stale generated sections.
- Keep dates concrete in `YYYY-MM-DD` format.
- If the repo is dirty, distinguish already-existing changes from changes made in the current session when possible.
- Never claim memory is updated until the files have actually been written.
- If verification commands were not run, write `Verified: not run` rather than implying success.

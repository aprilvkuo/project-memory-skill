# project-memory

A portable Agent Skill for [Claude Code](https://docs.claude.com/en/docs/claude-code),
[Codex](https://developers.openai.com/codex/skills), and
[Hermes Agent](https://github.com/NousResearch/hermes-agent). It gives a project
**persistent, cross-session memory** with on-demand loading, task-sequence decay,
and a bounded active task log.

The same Git-tracked memory is shared across all three agents, so work can hand
off between runtimes without copying state or introducing a database.

## Why on-demand + decay?

A long-lived project's memory files (`current-state`, `decisions`, `task-log`,
handoff) grow until they blow the context window. This skill fixes that:

- **Index first.** Each session starts by reading only `MEMORY.md` — a small
  table. Rows marked `always` or `recent:auto` are expanded; the rest stay
  available on demand.
- **Decay by task sequence, not calendar time.** A decision untouched for 6
  months but preceded by only 3 tasks is still highly relevant. The decay unit
  is *"how many tasks since this was last touched"*, not *"how many days"*.
- **Separate importance from loading.** Importance controls preservation and
  ranking; `load` controls whether a memory enters the next session.
- **Bounded active history.** `task-log.md` keeps the newest 30 entries and
  moves older entries into the on-demand archive.

## Install

```bash
git clone https://github.com/aprilvkuo/claude-project-memory.git
cd claude-project-memory
./install.sh
```

The installer deploys the same bundle to all three official user locations:

| Agent | Install location |
|-------|------------------|
| Claude Code | `~/.claude/skills/project-memory` |
| Codex | `~/.agents/skills/project-memory` |
| Hermes | `~/.hermes/skills/project-memory` |

Existing installs are backed up first. Override roots with
`CLAUDE_SKILLS_DIR`, `CODEX_SKILLS_DIR`, or `HERMES_SKILLS_DIR`. Run
`./uninstall.sh` to remove active installs only; project memory and backups are
left untouched.

Hermes users can alternatively install directly from GitHub:

```bash
hermes skills install aprilvkuo/claude-project-memory/project-memory
```

## Invocation

| Agent | Example |
|-------|---------|
| Claude Code | `/project-memory start` |
| Codex | `$project-memory start` |
| Hermes | `/project-memory start` |

## Actions

| Action | What it does |
|--------|--------------|
| `init`   | Create the `docs/project-memory/` skeleton + empty `MEMORY.md`. |
| `start`  | New session: read `MEMORY.md`, expand `always` + `recent:auto` rows. |
| `update` | After progress: append a task, retain 30 active entries, rebuild the index. |
| `handoff`| End of session: update memory + write <300-word handoff, rebuild the index. |

## How decay works

```yaml
tasks_since = current_seq - entry.last_task      # current_seq = max(seq) in task-log*.md
recency     = 0.5 ^ (tasks_since / HALF_LIFE)
```

- `HALF_LIFE` defaults to **10 tasks** (set `Half-life (tasks):` in `MEMORY.md`,
  or `MEMORY_HALF_LIFE=14` to override).
- Tiers: **hot** recency ≥ 0.67, **warm** 0.20–0.67, **cold** < 0.20.

Decision entries carry independent metadata:

```markdown
## D12 — Keep memory in the repository
last_task: 48
importance: 5
load: recent
summary: Project memory remains human-readable and Git-tracked.
```

`load` accepts `always`, `recent` (the default), or `on-demand`. A stale
importance-5 decision is preserved and ranked highly, but it becomes cold and
stops auto-loading unless its policy is `always`.

`task-log-retention.sh` keeps 30 active entries by default. Override it with
`MEMORY_TASK_LOG_LIMIT=50`; the current sequence still scans active and archived
logs. The skill runs retention before rebuilding the index on update/handoff.

## File layout

```
docs/project-memory/
├── MEMORY.md                  # auto-generated index — read this first
├── current-state.md           # hot: state / focus / blockers / next
├── decisions.md               # independently indexed decision entries
├── task-log.md                # newest 30 tasks, each with a monotonic seq
├── session-handoff.md         # hot: next-session handoff
└── archive/                   # cold: cooled-down old memory
    ├── decisions-archive.md
    └── task-log-archive.md
```

## Example

See [`examples/`](examples/) for the generated index and entry metadata. Run the
dependency-free regression suite with `bash tests/run.sh`; it includes a
500-task lifecycle test that verifies the 30/470 active/archive boundary.

## License

MIT

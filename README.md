# claude-project-memory

A [Claude Code](https://docs.claude.com/en/docs/claude-code) skill that gives your
project **persistent, cross-session memory** — loaded **on demand**, with a
**task-sequence decay** (LSTM-style forget gate) so old, trivial context fades
out instead of bloating every session.

It complements Claude memory and `/init`: it lives in your repo, tracks current
progress and decisions, and hands off to the next session.

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

Installs to `~/.claude/skills/project-memory` (backs up any existing version
first). Uninstall with `./uninstall.sh` (removes only the skill, never your
in-repo memory).

## Usage

| Command | What it does |
|---------|--------------|
| `/project-memory init`   | Create the `docs/project-memory/` skeleton + empty `MEMORY.md`. |
| `/project-memory start`  | New session: read `MEMORY.md`, expand `always` + `recent:auto` rows. |
| `/project-memory update` | After progress: append a task, retain 30 active entries, rebuild the index. |
| `/project-memory handoff`| End of session: update memory + write <300-word handoff, rebuild index. |

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

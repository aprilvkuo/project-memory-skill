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
  table. Hot + warm pages are expanded; cold pages stay collapsed.
- **Decay by task sequence, not calendar time.** A decision untouched for 6
  months but preceded by only 3 tasks is still highly relevant. The decay unit
  is *"how many tasks since this was last touched"*, not *"how many days"*.
- **Importance floor.** Critical architecture decisions (importance 5) keep a
  recency floor of 0.50 forever and are never archived out.

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
| `/project-memory start`  | New session: read `MEMORY.md`, expand hot+warm, hand off cold. |
| `/project-memory update` | After progress: append task-log entry, refresh frontmatter, rebuild index. |
| `/project-memory handoff`| End of session: update memory + write <300-word handoff, rebuild index. |

## How decay works

```yaml
tasks_since = current_seq - entry.last_task      # current_seq = max(seq) in task-log*.md
recency     = max( floor[importance], 0.5 ^ (tasks_since / HALF_LIFE) )
```

- `HALF_LIFE` defaults to **10 tasks** (set `Half-life (tasks):` in `MEMORY.md`,
  or `MEMORY_HALF_LIFE=14` to override).
- `floor[importance] = {5:0.50, 4:0.25, 3:0.10, 2:0.05, 1:0.00}`.
- Tiers: **hot** recency ≥ 0.67, **warm** 0.20–0.67, **cold** < 0.20.

`memory-index.sh` recomputes the index automatically on every `update`/`handoff`.

## File layout

```
docs/project-memory/
├── MEMORY.md                  # auto-generated index — read this first
├── current-state.md           # hot: state / focus / blockers / next
├── decisions.md               # warm: decisions + tradeoffs (importance, last_task)
├── task-log.md                # hot: task stream, each entry has a monotonic seq
├── session-handoff.md         # hot: next-session handoff
└── archive/                   # cold: cooled-down old memory
    ├── decisions-archive.md
    └── task-log-archive.md
```

## Example

See [`examples/`](examples/) — including `MEMORY.md` generated from the sample
files, demonstrating an importance-5 decision kept alive at recency 0.50 after
38 tasks, while an importance-1 task fades to 0.05.

## License

MIT

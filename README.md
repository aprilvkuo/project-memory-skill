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
# Install only one agent:
./install.sh --target codex   # claude | codex | hermes | all
```

The installer deploys the same bundle to all three official user locations:

| Agent | Install location |
|-------|------------------|
| Claude Code | `~/.claude/skills/project-memory` |
| Codex | `~/.agents/skills/project-memory` |
| Hermes | `~/.hermes/skills/project-memory` |

Existing installs are backed up outside the discovery roots, under
`<parent-of-skill-root>/skill-backups/project-memory/<agent>/<timestamp>/`.
For example, Codex backups live in `~/.agents/skill-backups/project-memory/codex/`.
Updates also move legacy `project-memory.backup.*` skill folders into that backup
directory, preserving their contents. Override roots with
`CLAUDE_SKILLS_DIR`, `CODEX_SKILLS_DIR`, or `HERMES_SKILLS_DIR`. Run
`./uninstall.sh` to remove active installs only; project memory and backups are
left untouched. `./uninstall.sh --target codex` removes only the selected agent.

Hermes users can alternatively install directly from GitHub:

```bash
hermes skills install aprilvkuo/claude-project-memory/project-memory
```

## Update and verify

Pull the repository and rerun the installer. Each replaced version is retained
as a timestamped backup:

```bash
git pull --ff-only
./install.sh
```

Verify that all installed bundles match the repository source:

```bash
diff -qr project-memory "$HOME/.claude/skills/project-memory"
diff -qr project-memory "$HOME/.agents/skills/project-memory"
diff -qr project-memory "$HOME/.hermes/skills/project-memory"
hermes skills list | grep project-memory   # when Hermes is installed
```

Codex detects skill changes automatically; restart Codex if the updated skill
does not appear. Hermes updates installed by this repository immediately on a
new session; use `/reset` when refreshing an existing session.

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

Retention validates both logs before replacing either one: every heading `Tn`
must match a unique `seq: n`, entries must be newest-first, and overlapping
active/archive sequences must have identical content. Invalid input leaves both
logs unchanged. After an interrupted archive-first update, rerunning converges
without dropping records.

Metadata is parsed only inside top-of-file frontmatter or the contiguous field
block immediately below a decision heading. Fenced examples are ignored. Inline
comments and single/double-quoted scalar values are supported; this is a small
metadata format, not a general YAML parser. Missing decision fields inherit the
page's fields before defaults are applied.

The generated index reports row count and default-loaded content size in UTF-8
bytes. `MEMORY_CONTEXT_BUDGET_BYTES` defaults to 32768; exceeding it prints a
warning without deleting or truncating memory. It measures content bytes rather
than model tokens and excludes the index itself. Read a decision link's section
only, rather than loading its entire file.

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
500-task synthetic lifecycle test with intermediate index rebuilds, malformed
input and recovery scenarios, and a 500-decision context-budget test. These
regressions do not replace longitudinal evidence from real projects. GitHub
Actions runs the suite on macOS and Linux for pushes and pull requests.

## License

MIT

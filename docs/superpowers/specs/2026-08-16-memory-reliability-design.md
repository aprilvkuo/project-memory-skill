# Memory Reliability Design

## Goal

Improve long-running reliability without expanding project-memory into a database or retrieval system. Keep the implementation human-readable, Git-friendly, dependency-free, and predictable after hundreds of tasks.

## Scope

This change addresses four related boundaries:

1. Index decisions independently instead of assigning one recency value to the whole `decisions.md` file.
2. Keep only the newest 30 entries in the active task log and move older entries to the archive.
3. Separate preservation importance from automatic loading.
4. Add a deterministic 500-task regression test that checks bounded active context, sequence continuity, decay, and loading behavior.

It does not add embeddings, a database, hooks, a reranker, or automatic semantic retrieval.

## Data Model

### Decision entries

Each level-two decision heading in `decisions.md` may carry entry-level metadata immediately below the heading:

```markdown
## D12 — Use task-sequence decay
last_task: 48
importance: 5
load: recent
summary: Decay is based on completed tasks rather than calendar age.

Decision text follows here.
```

The supported fields are:

- `last_task`: non-negative task sequence used by recency calculation.
- `importance`: integer from 1 through 5 used for preservation and index ordering.
- `load`: `always`, `recent`, or `on-demand`.
- `summary`: one-line index description.

`load` defaults to `recent`. Legacy pages without entry metadata retain file-level indexing using their frontmatter. Existing Markdown remains readable without the script.

### Loading and decay

Recency is independent of importance:

```text
tasks_since = max(0, current_seq - last_task)
recency = 0.5 ^ (tasks_since / half_life)
```

Tiers remain:

- hot: recency >= 0.67
- warm: 0.20 <= recency < 0.67
- cold: recency < 0.20

Automatic loading is determined separately:

- `always`: automatically load regardless of tier.
- `recent`: automatically load only while hot or warm.
- `on-demand`: never automatically load; expose it in the index for relevant queries.

Importance no longer creates a recency floor. Importance 5 means “preserve and rank highly,” not “inject into every future session.” Important cold decisions remain indexed and must not be deleted by automatic archival.

## Index Format

`MEMORY.md` contains one row per indexed page or decision entry. Decision rows link to generated Markdown anchors in `decisions.md`. The table adds a `Load` column so the reason for automatic or on-demand loading is explicit.

The score remains a sorting aid (`recency * importance`) and does not control loading. The generated instructions tell the agent to load rows marked for automatic loading, rather than loading every hot and warm file unconditionally.

Task-log files remain page-level index entries. Archived task logs are always on-demand so a recent entry cannot cause an entire archive page to enter the default context.

## Task-log Retention

The active `task-log.md` keeps the newest 30 level-two task entries. After a new task is recorded during `update` or `handoff`, older entries are moved to `archive/task-log-archive.md`.

Rules:

- The default active limit is 30.
- `MEMORY_TASK_LOG_LIMIT` may override the limit with a positive integer.
- Invalid limits fail before any file is modified.
- An entry is moved, never copied; each `seq` must occur exactly once across active and archived logs.
- Active entries retain newest-first order.
- Newly archived entries are inserted into the archive in newest-first order, ahead of older archived entries.
- File frontmatter and the level-one title are preserved.
- `current_seq` continues to scan both active and archived task logs.
- Rewrites use temporary files and atomic replacement so an interruption does not partially truncate either log.

The retention operation is implemented as a focused shell helper called by the skill workflow before rebuilding the index. It has no external runtime dependency beyond standard Unix tools already used by the project.

## Error Handling and Compatibility

- Invalid half-life, task-log limit, importance, or load values produce actionable errors.
- Missing entry fields use conservative defaults: current recency for missing `last_task`, importance 3, and `load: recent`.
- Legacy file-level pages continue to index correctly.
- An absent archive file is created only when entries actually need to move.
- A malformed task heading is not silently discarded; the retention helper aborts without modifying either file.
- Installation and uninstallation behavior remains unchanged.

## Verification

A dependency-free shell test suite creates temporary memory directories and exercises real scripts.

Unit-sized scenarios cover:

1. Two decisions in one file receive different recency tiers and independent index rows.
2. An old importance-5 decision becomes cold and is not automatically loaded with `load: recent`.
3. `load: always` remains automatic when cold; `load: on-demand` remains manual when hot.
4. Legacy file-level frontmatter still produces one valid index row.
5. A 31-entry task log retains 30 active entries and moves exactly one to the archive.
6. Invalid retention configuration leaves both source files byte-for-byte unchanged.

The long-run regression generates 500 sequential task entries and representative decisions. It verifies:

- exactly 30 active task entries;
- exactly 470 archived task entries;
- every sequence from 1 through 500 appears once and only once;
- `Current task seq` remains 500;
- a stale importance-5 `recent` decision is cold and not automatic;
- an `always` decision is automatic regardless of age;
- repeated index rebuilds are deterministic apart from the documented rebuild date;
- active task-log size remains bounded.

## Documentation

The English and Chinese READMEs and `project-memory/SKILL.md` will describe:

- the 30-entry active task-log limit and override;
- entry-level decision metadata;
- the separation of importance, recency, and load policy;
- the revised start/update/handoff workflow;
- how to run the regression suite.

The “LSTM-style” phrase may remain clearly labeled as an analogy, but the normative documentation uses the explicit decay formula and loading rules.

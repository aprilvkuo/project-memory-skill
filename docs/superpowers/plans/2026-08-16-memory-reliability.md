# Memory Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound active task history, index decisions independently, separate importance from load policy, and prove the behavior across 500 tasks.

**Architecture:** Keep Markdown as the source of truth. Add one focused retention script and extend the existing index generator with entry parsing and an explicit load column. Exercise both scripts through dependency-free shell integration tests.

**Tech Stack:** Bash, awk, standard Unix utilities, Markdown.

## Global Constraints

- Keep only the newest 30 task entries by default.
- Preserve pure Markdown storage and add no database, embedding, hook, or external dependency.
- Importance controls preservation and ranking; load policy controls automatic loading.
- Preserve legacy file-level frontmatter behavior.
- Production behavior changes must follow red-green TDD.

---

### Task 1: Bounded task-log retention

**Files:**
- Create: `tests/test-task-log-retention.sh`
- Create: `project-memory/task-log-retention.sh`

**Interfaces:**
- Consumes: memory directory argument; optional `MEMORY_TASK_LOG_LIMIT` positive integer.
- Produces: bounded `task-log.md` and newest-first `archive/task-log-archive.md` with unique sequences.

- [ ] **Step 1: Write the failing retention tests**

Create a shell test that generates 31 entries, invokes `project-memory/task-log-retention.sh`, and asserts 30 active entries, one archived entry, no duplicate sequence, and unchanged files for `MEMORY_TASK_LOG_LIMIT=bad`.

- [ ] **Step 2: Run the test and verify RED**

Run: `bash tests/test-task-log-retention.sh`

Expected: FAIL because `project-memory/task-log-retention.sh` does not exist.

- [ ] **Step 3: Implement the minimal retention helper**

Implement strict configuration validation, parse task blocks beginning with `## T<number>`, split after the configured count, and atomically replace active/archive files only after both outputs are ready.

- [ ] **Step 4: Run the test and verify GREEN**

Run: `bash tests/test-task-log-retention.sh`

Expected: PASS with 30 active entries and correct archive behavior.

- [ ] **Step 5: Commit**

```bash
git add tests/test-task-log-retention.sh project-memory/task-log-retention.sh
git commit -m "feat: bound active task log"
```

### Task 2: Entry-level decision indexing and explicit loading

**Files:**
- Create: `tests/test-memory-index.sh`
- Modify: `project-memory/memory-index.sh`

**Interfaces:**
- Consumes: page frontmatter plus decision entry fields `last_task`, `importance`, `load`, and `summary`.
- Produces: `MEMORY.md` rows with `Page`, `Tier`, `Load`, `Last Task`, `Importance`, `Recency`, `Score`, and `Summary`.

- [ ] **Step 1: Write failing index tests**

Create fixtures containing two decisions in one file, stale importance-5 `recent`, stale `always`, hot `on-demand`, an archived task log, and a legacy page. Assert independent rows and anchors, recency without an importance floor, and correct automatic/manual labels.

- [ ] **Step 2: Run the test and verify RED**

Run: `bash tests/test-memory-index.sh`

Expected: FAIL because the current index has only file-level rows and no `Load` column.

- [ ] **Step 3: Implement minimal entry parsing**

Refactor row generation into helpers that validate metadata, calculate pure task-distance recency, derive tier and effective load, escape Markdown cells, and emit each decision heading as a linked row. Force archived task-log pages to on-demand.

- [ ] **Step 4: Run all focused tests and verify GREEN**

Run: `bash tests/test-memory-index.sh && bash tests/test-task-log-retention.sh`

Expected: both scripts print PASS and exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test-memory-index.sh project-memory/memory-index.sh
git commit -m "feat: decouple memory importance and loading"
```

### Task 3: 500-task regression

**Files:**
- Create: `tests/test-long-run.sh`
- Create: `tests/run.sh`

**Interfaces:**
- Consumes: the two production scripts.
- Produces: deterministic proof of bounded active history and correct sequence/index behavior after 500 tasks.

- [ ] **Step 1: Write the long-run test**

Generate 500 newest-first entries, run retention and indexing, then assert 30 active, 470 archived, sequences 1–500 exactly once, current sequence 500, stale importance-5 `recent` is cold/manual, stale `always` is automatic, and a second rebuild produces identical content after normalizing `Last rebuilt`.

- [ ] **Step 2: Run the regression**

Run: `bash tests/test-long-run.sh`

Expected: PASS. If it exposes a missing behavior, add the smallest focused failing assertion to the relevant test before changing production code.

- [ ] **Step 3: Add the suite runner and verify all tests**

`tests/run.sh` executes the retention, index, and long-run scripts with `set -euo pipefail`.

Run: `bash tests/run.sh`

Expected: three PASS results and exit 0.

- [ ] **Step 4: Commit**

```bash
git add tests/test-long-run.sh tests/run.sh
git commit -m "test: cover 500-task memory lifecycle"
```

### Task 4: Workflow and user documentation

**Files:**
- Modify: `project-memory/SKILL.md`
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `examples/decisions.md`
- Modify: `examples/MEMORY.md`

**Interfaces:**
- Consumes: the implemented script behavior.
- Produces: accurate bilingual guidance and examples.

- [ ] **Step 1: Update the skill workflow**

Document entry-level decision metadata, `load: always|recent|on-demand`, pure recency, 30-entry retention, and running retention before index rebuilding during update/handoff.

- [ ] **Step 2: Update READMEs and examples**

Replace importance-floor claims with preservation/load separation, show the retention override, and regenerate the example index using the production script.

- [ ] **Step 3: Verify documentation and installation payload**

Run: `bash tests/run.sh && ./project-memory/memory-index.sh examples && git diff --check`

Expected: tests PASS, example index rebuild succeeds, and no whitespace errors.

- [ ] **Step 4: Commit**

```bash
git add project-memory/SKILL.md README.md README.zh-CN.md examples
git commit -m "docs: explain bounded and explicit memory loading"
```

### Task 5: Final installed-skill verification

**Files:**
- No repository file changes expected.

**Interfaces:**
- Consumes: completed repository state.
- Produces: verified install matching the repository payload.

- [ ] **Step 1: Run the complete verification suite**

Run: `bash tests/run.sh && git diff --check && git status --short`

Expected: all tests PASS; only intentional changes, if any, are listed.

- [ ] **Step 2: Install and compare**

Run: `./install.sh && diff -qr project-memory "$HOME/.claude/skills/project-memory"`

Expected: installer succeeds and `diff` produces no output.

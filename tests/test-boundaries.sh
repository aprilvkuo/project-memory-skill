#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$TMP/invalid/archive" "$TMP/index"
printf '# Task Log\n## T2 Latest\nseq: 2\n\n## T1 Missing seq\nbody\n' > "$TMP/invalid/task-log.md"
printf '# Task Log Archive\n## T0 Historical\nseq: 0\noriginal\n' > "$TMP/invalid/archive/task-log-archive.md"
cp -R "$TMP/invalid" "$TMP/before"
if MEMORY_TASK_LOG_LIMIT=1 bash "$ROOT/project-memory/task-log-retention.sh" "$TMP/invalid" >/dev/null 2>&1; then fail 'missing seq accepted'; fi
diff -qr "$TMP/invalid" "$TMP/before" || fail 'invalid input changed durable files'

for scenario in duplicate mismatch order conflict interleaved; do
  mkdir -p "$TMP/$scenario/archive"
  case "$scenario" in
    duplicate) printf '# Task Log\n## T2 A\nseq: 2\n\n## T2 B\nseq: 2\n' > "$TMP/$scenario/task-log.md" ;;
    mismatch) printf '# Task Log\n## T2 A\nseq: 3\n' > "$TMP/$scenario/task-log.md" ;;
    order) printf '# Task Log\n## T1 A\nseq: 1\n\n## T2 B\nseq: 2\n' > "$TMP/$scenario/task-log.md" ;;
    conflict)
      printf '# Task Log\n## T2 A\nseq: 2\n\n## T1 B\nseq: 1\nactive content\n' > "$TMP/$scenario/task-log.md"
      printf '# Task Log Archive\n## T1 B\nseq: 1\nconflicting archive content\n' > "$TMP/$scenario/archive/task-log-archive.md" ;;
    interleaved)
      printf '# Task Log\n## T4 A\nseq: 4\n\n## T2 B\nseq: 2\n' > "$TMP/$scenario/task-log.md"
      printf '# Task Log Archive\n## T3 C\nseq: 3\n' > "$TMP/$scenario/archive/task-log-archive.md" ;;
  esac
  cp -R "$TMP/$scenario" "$TMP/$scenario-before"
  if MEMORY_TASK_LOG_LIMIT=1 bash "$ROOT/project-memory/task-log-retention.sh" "$TMP/$scenario" >/dev/null 2>&1; then fail "$scenario accepted"; fi
  diff -qr "$TMP/$scenario" "$TMP/$scenario-before" || fail "$scenario mutated durable files"
done

printf '# Task Log\n## T50 Latest\nseq: 50\n' > "$TMP/index/task-log.md"
printf '\nA prose example follows:\nseq: 9999\n' >> "$TMP/index/task-log.md"
cat > "$TMP/index/decisions.md" <<'EOF'
---
last_task: 1
importance: 5
load: on-demand
summary: Legacy page
---
# Decisions
## D1 Legacy decision
Historical body.

## D2 New decision
last_task: 48 # touched
importance: 4 # rank
load: "recent" # default
summary: "A # quoted | summary"

```markdown
## D3 Fake decision
last_task: 50
load: always
```
EOF
bash "$ROOT/project-memory/memory-index.sh" "$TMP/index" >/dev/null
grep -q '^Current task seq: 50$' "$TMP/index/MEMORY.md" || fail 'body example changed current task sequence'
grep -q '\[D1\].*| cold | on-demand | 1 |.*| 5 |' "$TMP/index/MEMORY.md" || fail 'legacy metadata lost'
grep -q '\[D2\].*| hot | recent:auto | 48 |.*| 4 |' "$TMP/index/MEMORY.md" || fail 'comments or quotes misparsed'
if grep -q '\[D3\]' "$TMP/index/MEMORY.md"; then fail 'fenced decision was indexed'; fi
MEMORY_CONTEXT_BUDGET_BYTES=1 bash "$ROOT/project-memory/memory-index.sh" "$TMP/index" > "$TMP/out" 2> "$TMP/err"
grep -q 'context budget' "$TMP/err" || fail 'context budget warning missing'
grep -q '^Default load bytes:' "$TMP/index/MEMORY.md" || fail 'context byte measurement missing'

# Page-level metadata is restricted to frontmatter, even when body text looks like metadata.
printf '# Current State\n\n## Details\n\n```yaml\nload: always\nlast_task: 0\nimportance: 1\n```\n' > "$TMP/index/current-state.md"
bash "$ROOT/project-memory/memory-index.sh" "$TMP/index" >/dev/null
grep -q '| current-state.md | hot | recent:auto | — |.*| 3 |' "$TMP/index/MEMORY.md" || fail 'body text overrode page metadata'
cp "$TMP/index/MEMORY.md" "$TMP/index-before.md"
printf '\n## D2 Duplicate ID\nload: always\n' >> "$TMP/index/decisions.md"
if bash "$ROOT/project-memory/memory-index.sh" "$TMP/index" >/dev/null 2>&1; then fail 'duplicate decision IDs accepted'; fi
cmp "$TMP/index-before.md" "$TMP/index/MEMORY.md" || fail 'invalid metadata overwrote previous index'

# More decisions and longer entries expose budget growth without deleting memory.
mkdir -p "$TMP/large"
{
  echo '# Decisions'
  for ((i=1;i<=500;i++)); do
    printf '\n## D%s Long decision\nlast_task: 0\nimportance: 3\nload: always\nsummary: Decision %s\n\n' "$i" "$i"
    printf '%0200d\n' 0
  done
} > "$TMP/large/decisions.md"
before="$(cksum < "$TMP/large/decisions.md")"
MEMORY_CONTEXT_BUDGET_BYTES=32768 bash "$ROOT/project-memory/memory-index.sh" "$TMP/large" >/dev/null 2> "$TMP/large-warning"
grep -q '^Index rows: 500$' "$TMP/large/MEMORY.md" || fail 'large decision collection not fully indexed'
grep -q 'context budget exceeded' "$TMP/large-warning" || fail 'large default context did not warn'
[[ "$(cksum < "$TMP/large/decisions.md")" == "$before" ]] || fail 'budget check modified source decisions'
echo 'PASS: malformed inputs, legacy migration, Markdown fences, context budget'

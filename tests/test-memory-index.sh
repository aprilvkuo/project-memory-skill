#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/project-memory/memory-index.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

mem_dir="$(mktemp -d)"
mkdir -p "$mem_dir/archive"

cat > "$mem_dir/task-log.md" <<'EOF'
---
last_task: 50
importance: 3
summary: Recent tasks
---
# Task Log
## T50 — Latest
seq: 50
EOF

cat > "$mem_dir/decisions.md" <<'EOF'
# Decisions

## D-old — Preserve without injecting
last_task: 0
importance: 5
load: recent
summary: Important history should remain available but cold.

Old decision text.
load: always

## D-always — Persistent operating constraint
last_task: 0
importance: 4
load: always
summary: This constraint must load in every session.

Always-loaded decision text.

## D-manual — Recent but explicitly manual
last_task: 50
importance: 3
load: on-demand
summary: Load this only for a related question.

Manual decision text.
importance: 5

## D-default — Legacy entry metadata
summary: Missing fields use conservative defaults.

Legacy decision text.

## D_api — API choice 中文
last_task: 50
importance: 2
load: recent
summary: Anchors preserve underscores and Unicode text.
EOF

cat > "$mem_dir/current-state.md" <<'EOF'
---
last_task: 50
importance: 5
summary: Legacy file-level page
---
# Current State
EOF

cat > "$mem_dir/archive/task-log-archive.md" <<'EOF'
---
last_task: 49
importance: 1
summary: Historical tasks
---
# Task Log Archive
## T49 — Previous
seq: 49
EOF

"$SCRIPT" "$mem_dir"
index="$mem_dir/MEMORY.md"

grep -q '| Page | Tier | Load |' "$index" || fail "Load column missing"
grep -q '\[D-old\](decisions.md#d-old--preserve-without-injecting).*| cold | recent:on-demand | 0 |.*| 5 | 0.03 |' "$index" || fail "stale importance-5 decision or anchor is wrong"
grep -q '\[D-always\](decisions.md#d-always--persistent-operating-constraint).*| cold | always | 0 |.*| 4 | 0.03 |' "$index" || fail "cold always decision or anchor is wrong"
grep -q '\[D-manual\](decisions.md#d-manual--recent-but-explicitly-manual).*| hot | on-demand | 50 |.*| 3 | 1.00 |' "$index" || fail "body metadata leaked into the decision metadata block"
grep -q '\[D-default\](decisions.md#d-default--legacy-entry-metadata).*| hot | recent:auto | — |.*| 3 | 1.00 |' "$index" || fail "missing decision metadata did not use defaults"
grep -q '\[D_api\](decisions.md#d_api--api-choice-中文).*| hot | recent:auto | 50 |' "$index" || fail "underscore/Unicode anchor is not renderer-compatible"
grep -q '| current-state.md | hot | recent:auto | 50 |' "$index" || fail "legacy page compatibility failed"
grep -q '| archive/task-log-archive.md |.*| on-demand |' "$index" || fail "archived task log is not forced on-demand"

decision_rows="$(grep -c '](decisions.md#' "$index")"
[[ "$decision_rows" == 5 ]] || fail "expected 5 decision rows, got $decision_rows"

invalid_dir="$(mktemp -d)"
cat > "$invalid_dir/current-state.md" <<'EOF'
---
last_task: typo
importance: 3
summary: Invalid legacy metadata
---
# Current State
EOF
if "$SCRIPT" "$invalid_dir" >/dev/null 2>&1; then
  fail "invalid legacy last_task unexpectedly succeeded"
fi

echo "PASS: memory index"

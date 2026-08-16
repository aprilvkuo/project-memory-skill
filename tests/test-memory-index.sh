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

## D-default — Legacy entry metadata
summary: Missing fields use conservative defaults.

Legacy decision text.
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
grep -q '\[D-old\](decisions.md#d-old).*| cold | recent:on-demand | 0 |.*| 5 | 0.03 |' "$index" || fail "stale importance-5 decision did not become cold/on-demand"
grep -q '\[D-always\](decisions.md#d-always).*| cold | always | 0 |.*| 4 | 0.03 |' "$index" || fail "cold always decision is not automatic"
grep -q '\[D-manual\](decisions.md#d-manual).*| hot | on-demand | 50 |.*| 3 | 1.00 |' "$index" || fail "hot on-demand decision became automatic"
grep -q '\[D-default\](decisions.md#d-default).*| hot | recent:auto | — |.*| 3 | 1.00 |' "$index" || fail "missing decision metadata did not use defaults"
grep -q '| current-state.md | hot | recent:auto | 50 |' "$index" || fail "legacy page compatibility failed"
grep -q '| archive/task-log-archive.md |.*| on-demand |' "$index" || fail "archived task log is not forced on-demand"

decision_rows="$(grep -c '](decisions.md#' "$index")"
[[ "$decision_rows" == 4 ]] || fail "expected 4 decision rows, got $decision_rows"

echo "PASS: memory index"

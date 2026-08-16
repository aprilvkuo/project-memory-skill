#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RETENTION="$ROOT/project-memory/task-log-retention.sh"
INDEXER="$ROOT/project-memory/memory-index.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

mem_dir="$(mktemp -d)"
mkdir -p "$mem_dir/archive"
{
  cat <<'EOF'
---
last_task: 500
importance: 3
load: recent
summary: Recent task progress
---

# Task Log

EOF
  for ((seq=500; seq>=1; seq--)); do
    printf '## T%s — Synthetic regression task\nseq: %s\ndate: 2026-08-16\n\n' "$seq" "$seq"
  done
} > "$mem_dir/task-log.md"

cat > "$mem_dir/decisions.md" <<'EOF'
# Decisions

## D-stale — Critical but currently irrelevant
last_task: 1
importance: 5
load: recent
summary: Preserve this decision without injecting it forever.

## D-always — Permanent operating constraint
last_task: 1
importance: 4
load: always
summary: Load this constraint in every session.
EOF

"$RETENTION" "$mem_dir"
"$INDEXER" "$mem_dir"

active_count="$(grep -c '^## T[0-9]' "$mem_dir/task-log.md")"
archive_count="$(grep -c '^## T[0-9]' "$mem_dir/archive/task-log-archive.md")"
[[ "$active_count" == 30 ]] || fail "expected 30 active entries, got $active_count"
[[ "$archive_count" == 470 ]] || fail "expected 470 archived entries, got $archive_count"

seq_file="$(mktemp)"
grep -h '^seq: ' "$mem_dir/task-log.md" "$mem_dir/archive/task-log-archive.md" | awk '{print $2}' | sort -n > "$seq_file"
[[ "$(wc -l < "$seq_file" | tr -d ' ')" == 500 ]] || fail "expected 500 total sequences"
[[ "$(uniq "$seq_file" | wc -l | tr -d ' ')" == 500 ]] || fail "duplicate sequences found"
[[ "$(head -1 "$seq_file")" == 1 && "$(tail -1 "$seq_file")" == 500 ]] || fail "sequence range is incomplete"

index="$mem_dir/MEMORY.md"
grep -q '^Current task seq: 500$' "$index" || fail "current sequence is not 500"
grep -q '\[D-stale\].*| cold | recent:on-demand | 1 |.*| 5 | 0.00 |' "$index" || fail "stale critical decision is not cold/on-demand"
grep -q '\[D-always\].*| cold | always | 1 |' "$index" || fail "always decision stopped auto-loading"

before="$(shasum "$index")"
"$INDEXER" "$mem_dir" >/dev/null
after="$(shasum "$index")"
[[ "$before" == "$after" ]] || fail "repeated index rebuild is not deterministic"

active_bytes="$(wc -c < "$mem_dir/task-log.md" | tr -d ' ')"
(( active_bytes < 10000 )) || fail "active task log is unexpectedly large: $active_bytes bytes"

echo "PASS: 500-task lifecycle"

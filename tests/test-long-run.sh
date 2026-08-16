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
cat > "$mem_dir/task-log.md" <<'EOF'
---
last_task: 500
importance: 3
load: recent
summary: Recent task progress
---

# Task Log

EOF

for ((seq=1; seq<=500; seq++)); do
  next_log="$(mktemp "$mem_dir/.next-task-log.XXXXXX")"
  awk -v seq="$seq" '
    { print }
    /^# Task Log$/ {
      print ""
      print "## T" seq " — Synthetic regression task"
      print "seq: " seq
      print "date: 2026-08-16"
    }
  ' "$mem_dir/task-log.md" > "$next_log"
  mv "$next_log" "$mem_dir/task-log.md"
  "$RETENTION" "$mem_dir" >/dev/null

  if (( seq == 31 || seq % 50 == 0 )); then
    sampled_active="$(grep -c '^## T[0-9]' "$mem_dir/task-log.md")"
    (( sampled_active <= 30 )) || fail "active log exceeded 30 entries at task $seq"
    sampled_unique="$(grep -h '^seq: ' "$mem_dir/task-log.md" "$mem_dir/archive/task-log-archive.md" 2>/dev/null | awk '{print $2}' | sort -n | uniq | wc -l | tr -d ' ')"
    [[ "$sampled_unique" == "$seq" ]] || fail "sequence loss/duplication at task $seq"
  fi
done

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

"$INDEXER" "$mem_dir"

active_count="$(grep -c '^## T[0-9]' "$mem_dir/task-log.md")"
archive_count="$(grep -c '^## T[0-9]' "$mem_dir/archive/task-log-archive.md")"
[[ "$active_count" == 30 ]] || fail "expected 30 active entries, got $active_count"
[[ "$archive_count" == 470 ]] || fail "expected 470 archived entries, got $archive_count"
grep -q '^## T500 ' "$mem_dir/task-log.md" || fail "newest active task is missing"
grep -q '^## T471 ' "$mem_dir/task-log.md" || fail "active boundary task is missing"
[[ "$(grep '^## T[0-9]' "$mem_dir/archive/task-log-archive.md" | head -1)" == "## T470 — Synthetic regression task" ]] || fail "archive is not newest-first"
[[ "$(grep '^## T[0-9]' "$mem_dir/archive/task-log-archive.md" | tail -1)" == "## T1 — Synthetic regression task" ]] || fail "oldest archived task is misplaced"

seq_file="$(mktemp)"
grep -h '^seq: ' "$mem_dir/task-log.md" "$mem_dir/archive/task-log-archive.md" | awk '{print $2}' | sort -n > "$seq_file"
[[ "$(wc -l < "$seq_file" | tr -d ' ')" == 500 ]] || fail "expected 500 total sequences"
[[ "$(uniq "$seq_file" | wc -l | tr -d ' ')" == 500 ]] || fail "duplicate sequences found"
[[ "$(head -1 "$seq_file")" == 1 && "$(tail -1 "$seq_file")" == 500 ]] || fail "sequence range is incomplete"

index="$mem_dir/MEMORY.md"
grep -q '^Current task seq: 500$' "$index" || fail "current sequence is not 500"
grep -q '\[D-stale\].*| cold | recent:on-demand | 1 |.*| 5 | 0.00 |' "$index" || fail "stale critical decision is not cold/on-demand"
grep -q '\[D-always\].*| cold | always | 1 |' "$index" || fail "always decision stopped auto-loading"

before="$(sed '/^Last rebuilt:/d' "$index" | shasum)"
"$INDEXER" "$mem_dir" >/dev/null
after="$(sed '/^Last rebuilt:/d' "$index" | shasum)"
[[ "$before" == "$after" ]] || fail "repeated index rebuild is not deterministic"

active_bytes="$(wc -c < "$mem_dir/task-log.md" | tr -d ' ')"
(( active_bytes < 10000 )) || fail "active task log is unexpectedly large: $active_bytes bytes"

echo "PASS: 500-task lifecycle"

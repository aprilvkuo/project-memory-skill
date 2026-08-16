#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/project-memory/task-log-retention.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

make_log() {
  local dir="$1"
  mkdir -p "$dir/archive"
  {
    cat <<'EOF'
---
last_task: 31
importance: 3
date: 2026-08-16
summary: Recent task progress
---

# Task Log

EOF
    local seq
    for ((seq=31; seq>=1; seq--)); do
      printf '## T%s — Task %s\nseq: %s\ndate: 2026-08-16\n\n' "$seq" "$seq" "$seq"
    done
  } > "$dir/task-log.md"
}

case_dir="$(mktemp -d)"
make_log "$case_dir"
"$SCRIPT" "$case_dir"

active_count="$(grep -c '^## T[0-9]' "$case_dir/task-log.md")"
archive_count="$(grep -c '^## T[0-9]' "$case_dir/archive/task-log-archive.md")"
[[ "$active_count" == 30 ]] || fail "expected 30 active entries, got $active_count"
[[ "$archive_count" == 1 ]] || fail "expected 1 archived entry, got $archive_count"
grep -q '^## T31 ' "$case_dir/task-log.md" || fail "newest entry missing from active log"
grep -q '^## T2 ' "$case_dir/task-log.md" || fail "active boundary entry missing"
grep -q '^## T1 ' "$case_dir/archive/task-log-archive.md" || fail "oldest entry missing from archive"

all_seqs="$(grep -h '^seq: ' "$case_dir/task-log.md" "$case_dir/archive/task-log-archive.md" | awk '{print $2}' | sort -n)"
expected_seqs="$(seq 1 31)"
[[ "$all_seqs" == "$expected_seqs" ]] || fail "sequences are missing or duplicated"

invalid_dir="$(mktemp -d)"
make_log "$invalid_dir"
before="$(shasum "$invalid_dir/task-log.md")"
if MEMORY_TASK_LOG_LIMIT=bad "$SCRIPT" "$invalid_dir" >/dev/null 2>&1; then
  fail "invalid limit unexpectedly succeeded"
fi
after="$(shasum "$invalid_dir/task-log.md")"
[[ "$before" == "$after" ]] || fail "invalid limit modified task-log.md"
[[ ! -e "$invalid_dir/archive/task-log-archive.md" ]] || fail "invalid limit created archive"

echo "PASS: task-log retention"

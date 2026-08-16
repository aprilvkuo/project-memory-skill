#!/usr/bin/env bash
set -euo pipefail

MEM_DIR="${1:-.}"
ACTIVE="$MEM_DIR/task-log.md"
ARCHIVE_DIR="$MEM_DIR/archive"
ARCHIVE="$ARCHIVE_DIR/task-log-archive.md"
LIMIT="${MEMORY_TASK_LOG_LIMIT:-30}"

if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || (( LIMIT < 1 )); then
  echo "Error: MEMORY_TASK_LOG_LIMIT must be a positive integer (got '$LIMIT')" >&2
  exit 1
fi

[[ -f "$ACTIVE" ]] || exit 0

if ! awk '
  /^## / && $0 !~ /^## T[0-9]+([[:space:]]|$)/ {
    print "Error: malformed task heading: " $0 > "/dev/stderr"
    bad=1
  }
  END { exit bad }
' "$ACTIVE"; then
  exit 1
fi

entry_count="$(grep -c '^## T[0-9]' "$ACTIVE" || true)"
(( entry_count > LIMIT )) || exit 0

mkdir -p "$ARCHIVE_DIR"
active_tmp="$(mktemp "$MEM_DIR/.task-log.active.XXXXXX")"
moved_tmp="$(mktemp "$MEM_DIR/.task-log.moved.XXXXXX")"
archive_tmp="$(mktemp "$ARCHIVE_DIR/.task-log-archive.XXXXXX")"
archive_body_tmp="$(mktemp "$ARCHIVE_DIR/.task-log-body.XXXXXX")"
moved_seqs_tmp="$(mktemp "$ARCHIVE_DIR/.task-log-seqs.XXXXXX")"
filtered_body_tmp="$(mktemp "$ARCHIVE_DIR/.task-log-filtered.XXXXXX")"
trap 'rm -f "$active_tmp" "$moved_tmp" "$archive_tmp" "$archive_body_tmp" "$moved_seqs_tmp" "$filtered_body_tmp"' EXIT

awk -v limit="$LIMIT" -v active="$active_tmp" -v moved="$moved_tmp" '
  /^## T[0-9]+([[:space:]]|$)/ { count++; destination=(count <= limit ? active : moved) }
  count == 0 { print > active; next }
  { print > destination }
' "$ACTIVE"

if [[ -f "$ARCHIVE" ]]; then
  awk -v body="$archive_body_tmp" '
    /^## T[0-9]+([[:space:]]|$)/ { entries=1 }
    entries { print > body; next }
    { print }
  ' "$ARCHIVE" > "$archive_tmp"
else
  cat > "$archive_tmp" <<'EOF'
---
importance: 1
load: on-demand
summary: Historical task log
---

# Task Log Archive

EOF
fi

cat "$moved_tmp" >> "$archive_tmp"
if [[ -s "$archive_body_tmp" ]]; then
  awk '/^seq:[[:space:]]*[0-9]+/ { print $2 }' "$moved_tmp" > "$moved_seqs_tmp"
  awk '
    NR == FNR { moved[$1]=1; next }
    function flush() {
      if (block != "" && !(seq in moved)) printf "%s", block
    }
    /^## T[0-9]+([[:space:]]|$)/ { flush(); block=$0 ORS; seq=""; next }
    block != "" {
      block=block $0 ORS
      if ($0 ~ /^seq:[[:space:]]*[0-9]+/) seq=$2
    }
    END { flush() }
  ' "$moved_seqs_tmp" "$archive_body_tmp" > "$filtered_body_tmp"
  cat "$filtered_body_tmp" >> "$archive_tmp"
fi

# Archive first: interruption may leave duplicates, but never loses the only
# durable copy. A rerun removes duplicates by sequence and converges.
mv "$archive_tmp" "$ARCHIVE"
if [[ "${MEMORY_RETENTION_FAIL_AFTER_ARCHIVE:-0}" == 1 ]]; then
  echo "Error: retention interrupted after archive replacement (test failpoint)" >&2
  exit 75
fi
mv "$active_tmp" "$ACTIVE"

echo "Retained $LIMIT active task entries; archived $((entry_count - LIMIT)) older entries"

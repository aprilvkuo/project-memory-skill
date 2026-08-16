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
trap 'rm -f "$active_tmp" "$moved_tmp" "$archive_tmp" "$archive_body_tmp"' EXIT

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
  cat "$archive_body_tmp" >> "$archive_tmp"
fi

mv "$active_tmp" "$ACTIVE"
mv "$archive_tmp" "$ARCHIVE"

echo "Retained $LIMIT active task entries; archived $((entry_count - LIMIT)) older entries"

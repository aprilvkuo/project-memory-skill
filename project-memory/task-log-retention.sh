#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEM_DIR="${1:-.}"
ACTIVE="$MEM_DIR/task-log.md"
ARCHIVE="$MEM_DIR/archive/task-log-archive.md"
LIMIT="${MEMORY_TASK_LOG_LIMIT:-30}"
if ! [[ "$LIMIT" =~ ^[1-9][0-9]*$ ]] || (( ${#LIMIT} > 9 )); then
  echo "Error: MEMORY_TASK_LOG_LIMIT must be a positive integer (at most 9 digits)" >&2
  exit 1
fi
[[ -f "$ACTIVE" ]] || exit 0
stage="$(mktemp -d "$MEM_DIR/.retention.XXXXXX")"
trap 'rm -rf -- "$stage"' EXIT
files=("$ACTIVE")
[[ ! -f "$ARCHIVE" ]] || files+=("$ARCHIVE")
awk -v active_file="$ACTIVE" -v limit="$LIMIT" \
  -v active_output="$stage/active" -v archive_output="$stage/archive" \
  -f "$SCRIPT_DIR/markdown.awk" -f "$SCRIPT_DIR/retention.awk" "${files[@]}"
if [[ -s "$stage/archive" ]]; then
  mkdir -p "$MEM_DIR/archive"
  # Archive first; validated sequence-aware merging makes interrupted reruns safe.
  mv "$stage/archive" "$ARCHIVE"
  if [[ "${MEMORY_RETENTION_FAIL_AFTER_ARCHIVE:-0}" == 1 ]]; then
    echo "Error: retention interrupted after archive replacement (test failpoint)" >&2
    exit 75
  fi
fi
if [[ -f "$stage/active" ]]; then mv "$stage/active" "$ACTIVE"; fi
echo "Retained at most $LIMIT active task entries; validated and merged archive"

#!/usr/bin/env bash
# Rebuild MEMORY.md using task-sequence recency and an independent load policy.
set -euo pipefail

MEM_DIR="${1:-.}"
INDEX="$MEM_DIR/MEMORY.md"

HALF_LIFE="${MEMORY_HALF_LIFE:-}"
if [[ -z "$HALF_LIFE" && -f "$INDEX" ]]; then
  HALF_LIFE="$(grep -iE 'Half-life' "$INDEX" | grep -oE '[0-9]+' | head -1 || true)"
fi
HALF_LIFE="${HALF_LIFE:-10}"
if ! [[ "$HALF_LIFE" =~ ^[0-9]+$ ]] || (( HALF_LIFE < 1 )); then
  echo "Error: HALF_LIFE must be a positive integer (got '$HALF_LIFE')" >&2
  exit 1
fi

current_seq=0
while IFS= read -r file; do
  seq_max="$(awk '/^[[:space:]]*seq:[[:space:]]*[0-9]+/ { value=$2+0; if (value>max) max=value } END { print max+0 }' "$file")"
  (( seq_max > current_seq )) && current_seq="$seq_max"
done < <(find "$MEM_DIR" -maxdepth 2 -type f -name 'task-log*.md' | sort)

rows_file="$(mktemp "${TMPDIR:-/tmp}/memory-index-rows.XXXXXX")"
trap 'rm -f "$rows_file"' EXIT

emit_row() {
  local page="$1" last_task="$2" date_value="$3" importance="$4" policy="$5" summary="$6"
  local tasks_since recency tier effective_load score
  if [[ -n "$last_task" ]] && ! [[ "$last_task" =~ ^[0-9]+$ ]]; then
    echo "Error: invalid last_task '$last_task' for $page" >&2
    exit 1
  fi
  if ! [[ "$importance" =~ ^[1-5]$ ]]; then
    echo "Error: importance must be 1-5 (got '$importance' for $page)" >&2
    exit 1
  fi
  case "$policy" in
    always|recent|on-demand) ;;
    *) echo "Error: load must be always, recent, or on-demand (got '$policy' for $page)" >&2; exit 1 ;;
  esac
  if [[ -z "$last_task" ]]; then
    tasks_since=0
  else
    tasks_since=$((current_seq - last_task))
    (( tasks_since < 0 )) && tasks_since=0
  fi
  recency="$(awk -v ts="$tasks_since" -v hl="$HALF_LIFE" 'BEGIN { printf "%.2f", 0.5^(ts/hl) }')"
  if awk -v value="$recency" 'BEGIN { exit !(value>=0.67) }'; then
    tier=hot
  elif awk -v value="$recency" 'BEGIN { exit !(value>=0.20) }'; then
    tier=warm
  else
    tier=cold
  fi
  case "$policy" in
    always) effective_load=always ;;
    on-demand) effective_load=on-demand ;;
    recent) if [[ "$tier" == cold ]]; then effective_load=recent:on-demand; else effective_load=recent:auto; fi ;;
  esac
  score="$(awk -v recency="$recency" -v imp="$importance" 'BEGIN { printf "%.2f", recency*imp }')"
  summary="${summary//|/}"
  printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' "$page" "$tier" "$effective_load" "$last_task" "$date_value" "$importance" "$recency" "$score" "$summary" >> "$rows_file"
}

index_page() {
  local file="$1" rel="$2" last_task importance date_value summary policy
  last_task="$(awk '/^[[:space:]]*last_task:[[:space:]]*/ { print $2; exit }' "$file")"
  importance="$(awk '/^[[:space:]]*importance:[[:space:]]*/ { print $2; exit }' "$file")"
  date_value="$(awk '/^[[:space:]]*date:[[:space:]]*/ { print $2; exit }' "$file")"
  policy="$(awk '/^[[:space:]]*load:[[:space:]]*/ { print $2; exit }' "$file")"
  summary="$(awk '/^[[:space:]]*summary:[[:space:]]+/ { sub(/^[[:space:]]*summary:[[:space:]]*/, ""); print; exit }' "$file")"
  [[ -n "$summary" ]] || summary="$(awk '/^#/ { sub(/^#+[[:space:]]*/, ""); print; exit }' "$file")"
  importance="${importance:-3}"
  policy="${policy:-recent}"
  [[ "$rel" == archive/task-log*.md ]] && policy=on-demand
  emit_row "$rel" "$last_task" "$date_value" "$importance" "$policy" "$summary"
}

index_decisions() {
  local file="$1" rel="$2" entries_file id heading last_task importance policy date_value summary anchor
  entries_file="$(mktemp "${TMPDIR:-/tmp}/memory-decisions.XXXXXX")"
  awk '
    function flush() {
      if (id != "") {
        gsub(/\|/, "", heading)
        gsub(/\|/, "", summary)
        print id "|" heading "|" last "|" importance "|" load "|" date_value "|" summary
      }
    }
    function metadata(key, value) {
      if (seen[key]++) {
        print "Error: duplicate " key " for " id > "/dev/stderr"
        bad=1
        return
      }
      if (key == "last_task") last=value
      else if (key == "importance") importance=value
      else if (key == "load") load=value
      else if (key == "date") date_value=value
      else if (key == "summary") summary=value
    }
    /^## D[^[:space:]]*[[:space:]]/ {
      flush()
      id=$2; heading=$0; sub(/^##[[:space:]]+/, "", heading)
      last=""; importance=""; load=""; date_value=""; summary=""; meta=1
      delete seen
      next
    }
    id != "" && meta && /^(last_task|importance|load|date|summary):[[:space:]]*/ {
      key=$0; sub(/:.*/, "", key)
      value=$0; sub(/^[^:]+:[[:space:]]*/, "", value)
      metadata(key, value)
      next
    }
    id != "" && meta { meta=0 }
    END { flush(); exit bad }
  ' "$file" > "$entries_file"
  while IFS='|' read -r id heading last_task importance policy date_value summary; do
    [[ -n "$id" ]] || continue
    importance="${importance:-3}"
    policy="${policy:-recent}"
    anchor="$(printf '%s' "$heading" | sed 's/-/HYPHENTOKEN/g; s/_/UNDERSCORETOKEN/g' | tr '[:upper:]' '[:lower:]' | sed -E 's/[[:punct:]]//g; s/hyphentoken/-/g; s/underscoretoken/_/g; s/[[:space:]]/-/g; s/^-+//; s/-+$//')"
    emit_row "[$id]($rel#$anchor)" "$last_task" "$date_value" "$importance" "$policy" "$summary"
  done < "$entries_file"
  rm -f "$entries_file"
}

while IFS= read -r file; do
  rel="${file#$MEM_DIR/}"
  [[ "$rel" == MEMORY.md ]] && continue
  if grep -q '^## D[^[:space:]]*[[:space:]]' "$file"; then
    index_decisions "$file" "$rel"
  else
    index_page "$file" "$rel"
  fi
done < <(find "$MEM_DIR" -maxdepth 2 -type f -name '*.md' ! -name MEMORY.md | sort)

sorted="$(sort -t'|' -k8,8nr "$rows_file")"
rebuild_date="$(date +%Y-%m-%d)"
{
  echo "# Memory Index"
  echo
  echo "Last rebuilt: $rebuild_date"
  echo "Half-life (tasks): $HALF_LIFE"
  echo "Current task seq: $current_seq"
  echo
  echo "> Auto-generated by memory-index.sh — do not edit by hand."
  echo "> Recency uses task distance only; importance affects preservation and ranking, not recency."
  echo "> Load rows marked \`always\` or \`recent:auto\`; expand all other rows only when relevant."
  echo
  echo "| Page | Tier | Load | Last Task | Date | Importance | Recency | Score | Summary |"
  echo "|------|------|------|-----------|------|------------|---------|-------|---------|"
  if [[ -n "$sorted" ]]; then
    while IFS='|' read -r page tier load last_task date_value importance recency score summary; do
      echo "| $page | $tier | $load | ${last_task:-—} | ${date_value:-—} | $importance | $recency | $score | $summary |"
    done <<< "$sorted"
  fi
} > "$INDEX"

echo "Rebuilt $INDEX (current_seq=$current_seq, half-life=$HALF_LIFE tasks)"

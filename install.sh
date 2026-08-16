#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/project-memory"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: missing skill source directory: $SOURCE_DIR" >&2
  exit 1
fi

platforms=("Claude Code" "Codex" "Hermes")
roots=(
  "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  "${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
  "${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"
)

for index in "${!platforms[@]}"; do
  platform="${platforms[$index]}"
  target="${roots[$index]}/project-memory"
  mkdir -p "${roots[$index]}"

  if [[ -e "$target" ]]; then
    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    suffix=1
    while [[ -e "$backup" ]]; do
      backup="${target}.backup.$(date +%Y%m%d%H%M%S).$suffix"
      suffix=$((suffix + 1))
    done
    mv "$target" "$backup"
    echo "Backed up existing $platform skill to:"
    echo "  $backup"
  fi

  cp -R "$SOURCE_DIR" "$target"
  echo "Installed project-memory for $platform:"
  echo "  $target"
done

echo
echo "Invoke it with:"
echo "  Claude Code: /project-memory init"
echo '  Codex:      $project-memory init'
echo "  Hermes:     /project-memory init"

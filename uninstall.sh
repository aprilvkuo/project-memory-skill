#!/usr/bin/env bash
set -euo pipefail

platforms=("Claude Code" "Codex" "Hermes")
roots=(
  "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  "${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
  "${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"
)

for index in "${!platforms[@]}"; do
  platform="${platforms[$index]}"
  target="${roots[$index]}/project-memory"
  if [[ ! -e "$target" ]]; then
    echo "$platform: project-memory is not installed at $target"
    continue
  fi

  rm -rf "$target"
  echo "Removed project-memory for $platform:"
  echo "  $target"
done

echo
echo "Project-local memory files and installation backups were not removed."

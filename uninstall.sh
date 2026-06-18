#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/project-memory"

if [[ ! -e "$TARGET_DIR" ]]; then
  echo "project-memory skill is not installed at:"
  echo "  $TARGET_DIR"
  exit 0
fi

rm -rf "$TARGET_DIR"

echo "Removed project-memory skill from:"
echo "  $TARGET_DIR"
echo
echo "Project-local memory files were not removed."

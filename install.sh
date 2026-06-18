#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/project-memory"
TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/project-memory"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: missing skill source directory: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET_DIR")"

if [[ -e "$TARGET_DIR" ]]; then
  BACKUP_DIR="${TARGET_DIR}.backup.$(date +%Y%m%d%H%M%S)"
  mv "$TARGET_DIR" "$BACKUP_DIR"
  echo "Backed up existing project-memory skill to:"
  echo "  $BACKUP_DIR"
fi

cp -R "$SOURCE_DIR" "$TARGET_DIR"

echo "Installed project-memory skill to:"
echo "  $TARGET_DIR"
echo
echo "Try it in Claude Code:"
echo "  /project-memory init"

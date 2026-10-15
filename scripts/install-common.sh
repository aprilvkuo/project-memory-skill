#!/usr/bin/env bash
# Sourced by the two repository installation entrypoints.
platforms=("Claude Code" "Codex" "Hermes")
keys=("claude" "codex" "hermes")
roots=("${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}" "${CODEX_SKILLS_DIR:-$HOME/.agents/skills}" "${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}")
selected=(0 1 2)
if (( $# )); then
  if [[ "$1" == --help && $# == 1 ]]; then
    echo "Usage: $0 [--target claude|codex|hermes|all]"; exit 0
  fi
  if [[ $# != 2 || "$1" != --target ]]; then echo "Error: expected --target claude|codex|hermes|all" >&2; exit 1; fi
  case "$2" in claude) selected=(0);; codex) selected=(1);; hermes) selected=(2);; all) ;; *) echo "Error: unknown target: $2" >&2; exit 1;; esac
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
[[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]] || exit 1
ROLLBACK_ROOT=""
trap 'rm -rf -- "$TEST_ROOT"; [[ -n "$ROLLBACK_ROOT" ]] && rm -rf -- "$ROLLBACK_ROOT"' EXIT
CLAUDE_ROOT="$TEST_ROOT/claude"
CODEX_ROOT="$TEST_ROOT/codex"
HERMES_ROOT="$TEST_ROOT/hermes"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for skill_root in "$CLAUDE_ROOT" "$CODEX_ROOT" "$HERMES_ROOT"; do
  mkdir -p "$skill_root/project-memory"
  printf 'previous install\n' > "$skill_root/project-memory/old.txt"
done

ROLLBACK_ROOT="$(mktemp -d)"
ROLLBACK_CLAUDE="$ROLLBACK_ROOT/claude"
ROLLBACK_CODEX="$ROLLBACK_ROOT/codex"
ROLLBACK_HERMES="$ROLLBACK_ROOT/hermes"
for skill_root in "$ROLLBACK_CLAUDE" "$ROLLBACK_CODEX" "$ROLLBACK_HERMES"; do
  mkdir -p "$skill_root/project-memory"
  printf 'must survive rollback\n' > "$skill_root/project-memory/old.txt"
done
if PROJECT_MEMORY_INSTALL_FAIL_AT=codex \
  CLAUDE_SKILLS_DIR="$ROLLBACK_CLAUDE" \
  CODEX_SKILLS_DIR="$ROLLBACK_CODEX" \
  HERMES_SKILLS_DIR="$ROLLBACK_HERMES" \
  "$ROOT/install.sh" >/dev/null 2>&1; then
  fail "injected Codex installation failure unexpectedly succeeded"
fi
for skill_root in "$ROLLBACK_CLAUDE" "$ROLLBACK_CODEX" "$ROLLBACK_HERMES"; do
  [[ "$(cat "$skill_root/project-memory/old.txt")" == "must survive rollback" ]] || fail "rollback did not restore $skill_root"
  [[ "$(find "$skill_root" -maxdepth 1 -name '.project-memory.install.*' | wc -l | tr -d ' ')" == 0 ]] || fail "staging directory leaked at $skill_root"
  [[ "$(find "$skill_root" -maxdepth 1 -name 'project-memory.backup.*' | wc -l | tr -d ' ')" == 0 ]] || fail "rollback backup leaked at $skill_root"
done

CLAUDE_SKILLS_DIR="$CLAUDE_ROOT" \
CODEX_SKILLS_DIR="$CODEX_ROOT" \
HERMES_SKILLS_DIR="$HERMES_ROOT" \
  "$ROOT/install.sh" >/dev/null

for skill_root in "$CLAUDE_ROOT" "$CODEX_ROOT" "$HERMES_ROOT"; do
  diff -qr "$ROOT/project-memory" "$skill_root/project-memory" >/dev/null || fail "installed payload differs at $skill_root"
  backup_count="$(find "$skill_root" -maxdepth 1 -type d -name 'project-memory.backup.*' | wc -l | tr -d ' ')"
  [[ "$backup_count" == 1 ]] || fail "expected one backup at $skill_root, got $backup_count"
  backup_dir="$(find "$skill_root" -maxdepth 1 -type d -name 'project-memory.backup.*' -print -quit)"
  [[ "$(cat "$backup_dir/old.txt")" == "previous install" ]] || fail "backup content missing at $skill_root"
done

CLAUDE_SKILLS_DIR="$CLAUDE_ROOT" \
CODEX_SKILLS_DIR="$CODEX_ROOT" \
HERMES_SKILLS_DIR="$HERMES_ROOT" \
  "$ROOT/uninstall.sh" >/dev/null

for skill_root in "$CLAUDE_ROOT" "$CODEX_ROOT" "$HERMES_ROOT"; do
  [[ ! -e "$skill_root/project-memory" ]] || fail "active skill was not removed at $skill_root"
  backup_count="$(find "$skill_root" -maxdepth 1 -type d -name 'project-memory.backup.*' | wc -l | tr -d ' ')"
  [[ "$backup_count" == 1 ]] || fail "uninstall removed backup at $skill_root"
done

echo "PASS: three-platform installers"

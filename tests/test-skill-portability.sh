#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/project-memory/SKILL.md"
OPENAI_METADATA="$ROOT/project-memory/agents/openai.yaml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for agent in "Claude Code" "Codex" "Hermes"; do
  grep -q "$agent" "$SKILL" || fail "SKILL.md does not name $agent"
done

grep -q '/project-memory init' "$SKILL" || fail "Claude/Hermes invocation is missing"
grep -Fq '$project-memory init' "$SKILL" || fail "Codex invocation is missing"
grep -q 'SKILL_DIR' "$SKILL" || fail "portable skill-directory resolution is missing"
if grep -q '\./project-memory/\(memory-index\|task-log-retention\)\.sh' "$SKILL"; then
  fail "SKILL.md still assumes a repository checkout path"
fi

grep -Fq '$project-memory' "$OPENAI_METADATA" || fail "Codex default prompt does not explicitly invoke the skill"
if grep -q 'Claude Code sessions' "$OPENAI_METADATA"; then
  fail "Codex UI metadata is still Claude-only"
fi

echo "PASS: portable skill contract"

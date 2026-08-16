#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/project-memory/SKILL.md"
OPENAI_METADATA="$ROOT/project-memory/agents/openai.yaml"
README_EN="$ROOT/README.md"
README_ZH="$ROOT/README.zh-CN.md"

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
grep -q 'SKILL_FILE=' "$SKILL" || fail "executable SKILL_FILE assignment is missing"
if grep -q '\./project-memory/\(memory-index\|task-log-retention\)\.sh' "$SKILL"; then
  fail "SKILL.md still assumes a repository checkout path"
fi

grep -Fq '$project-memory' "$OPENAI_METADATA" || fail "Codex default prompt does not explicitly invoke the skill"
if grep -q 'Claude Code sessions' "$OPENAI_METADATA"; then
  fail "Codex UI metadata is still Claude-only"
fi

grep -q '^## Update and verify$' "$README_EN" || fail "English update/verification instructions are missing"
grep -q '^## 更新与验证$' "$README_ZH" || fail "Chinese update/verification instructions are missing"
for path in '.claude/skills/project-memory' '.agents/skills/project-memory' '.hermes/skills/project-memory'; do
  grep -Fq "$path" "$README_EN" || fail "English README omits $path"
  grep -Fq "$path" "$README_ZH" || fail "Chinese README omits $path"
done

frontmatter_keys="$(awk 'NR == 1 && $0 == "---" {inside=1; next} inside && $0 == "---" {exit} inside && /^[a-z][a-z0-9_-]*:/ {sub(/:.*/, ""); print}' "$SKILL" | sort)"
[[ "$frontmatter_keys" == $'description\nname' ]] || fail "shared frontmatter contains unsupported top-level fields"

PORTABLE_ROOT="$(mktemp -d)"
[[ -n "$PORTABLE_ROOT" && -d "$PORTABLE_ROOT" ]] || exit 1
trap 'rm -rf -- "$PORTABLE_ROOT"' EXIT
mkdir -p "$PORTABLE_ROOT/installed/project-memory" "$PORTABLE_ROOT/work/docs/project-memory"
cp -R "$ROOT/project-memory/." "$PORTABLE_ROOT/installed/project-memory/"
cat > "$PORTABLE_ROOT/work/docs/project-memory/task-log.md" <<'EOF'
# Task Log
## T1 — Portable execution
seq: 1
EOF
(
  cd "$PORTABLE_ROOT/work"
  SKILL_FILE="$PORTABLE_ROOT/installed/project-memory/SKILL.md"
  SKILL_DIR="$(cd "$(dirname "$SKILL_FILE")" && pwd)"
  "$SKILL_DIR/task-log-retention.sh" docs/project-memory >/dev/null
  "$SKILL_DIR/memory-index.sh" docs/project-memory >/dev/null
)
grep -q '^Current task seq: 1$' "$PORTABLE_ROOT/work/docs/project-memory/MEMORY.md" || fail "installed helper did not execute from an unrelated project"

echo "PASS: portable skill contract"

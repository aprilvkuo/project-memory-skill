#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/project-memory"
platforms=("Claude Code" "Codex" "Hermes")
keys=("claude" "codex" "hermes")
roots=(
  "${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
  "${CODEX_SKILLS_DIR:-$HOME/.agents/skills}"
  "${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"
)
targets=()
stages=()
backups=("" "" "")
installed=(0 0 0)
backed_up=(0 0 0)
rollback_needed=1

cleanup() {
  status=$?
  if (( rollback_needed )); then
    for ((index=${#targets[@]}-1; index>=0; index--)); do
      if [[ "${installed[$index]:-0}" == 1 && -e "${targets[$index]}" ]]; then
        rm -rf -- "${targets[$index]}"
      fi
      if [[ "${backed_up[$index]:-0}" == 1 && -e "${backups[$index]}" ]]; then
        mv "${backups[$index]}" "${targets[$index]}"
      fi
    done
  fi
  for stage in "${stages[@]:-}"; do
    [[ -n "$stage" && -e "$stage" ]] && rm -rf -- "$stage"
  done
  exit "$status"
}
trap cleanup EXIT

[[ -d "$SOURCE_DIR" ]] || { echo "Error: missing skill source directory: $SOURCE_DIR" >&2; exit 1; }

for index in "${!roots[@]}"; do
  root="${roots[$index]}"
  [[ -n "$root" ]] || { echo "Error: empty skill root for ${platforms[$index]}" >&2; exit 1; }
  target="$root/project-memory"
  for existing in "${targets[@]:-}"; do
    [[ -z "$existing" || "$existing" != "$target" ]] || { echo "Error: skill roots must resolve to distinct targets ($target)" >&2; exit 1; }
  done
  mkdir -p "$root"
  [[ -w "$root" ]] || { echo "Error: skill root is not writable: $root" >&2; exit 1; }
  targets+=("$target")

  stage="$(mktemp -d "$root/.project-memory.install.XXXXXX")"
  stages+=("$stage")
  cp -R "$SOURCE_DIR/." "$stage/"
done

for index in "${!targets[@]}"; do
  target="${targets[$index]}"
  if [[ -e "$target" ]]; then
    backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    suffix=1
    while [[ -e "$backup" ]]; do
      backup="${target}.backup.$(date +%Y%m%d%H%M%S).$suffix"
      suffix=$((suffix + 1))
    done
    backups[$index]="$backup"
    mv "$target" "$backup"
    backed_up[$index]=1
  fi

  if [[ "${PROJECT_MEMORY_INSTALL_FAIL_AT:-}" == "${keys[$index]}" ]]; then
    echo "Error: injected installation failure at ${keys[$index]}" >&2
    exit 70
  fi

  mv "${stages[$index]}" "$target"
  installed[$index]=1
done

rollback_needed=0
for index in "${!platforms[@]}"; do
  if [[ "${backed_up[$index]}" == 1 ]]; then
    echo "Backed up existing ${platforms[$index]} skill to:"
    echo "  ${backups[$index]}"
  fi
  echo "Installed project-memory for ${platforms[$index]}:"
  echo "  ${targets[$index]}"
done

echo
echo "Invoke it with:"
echo "  Claude Code: /project-memory init"
echo '  Codex:      $project-memory init'
echo "  Hermes:     /project-memory init"

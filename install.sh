#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/project-memory"
source "$SCRIPT_DIR/scripts/install-common.sh"
targets=("" "" "")
stages=("" "" "")
backup_roots=("" "" "")
migrated_sources=()
migrated_targets=()
backups=("" "" "")
installed=(0 0 0)
backed_up=(0 0 0)
rollback_needed=1

cleanup() {
  status=$?
  trap - EXIT
  set +e
  cleanup_error=0
  if (( rollback_needed )); then
    for ((index=${#migrated_sources[@]}-1; index>=0; index--)); do
      mv "${migrated_targets[$index]}" "${migrated_sources[$index]}" || cleanup_error=1
    done
    for ((index=2; index>=0; index--)); do
      if [[ "${installed[$index]:-0}" == 1 && -e "${targets[$index]}" ]]; then
        rm -rf -- "${targets[$index]}" || cleanup_error=1
      fi
      if [[ "${backed_up[$index]:-0}" == 1 && ( -e "${backups[$index]}" || -L "${backups[$index]}" ) ]]; then
        mv "${backups[$index]}" "${targets[$index]}" || cleanup_error=1
      fi
    done
  fi
  for stage in "${stages[@]:-}"; do
    if [[ -n "$stage" && -e "$stage" ]]; then
      rm -rf -- "$stage" || cleanup_error=1
    fi
  done
  (( status == 0 && cleanup_error != 0 )) && status=1
  exit "$status"
}
trap cleanup EXIT

[[ -d "$SOURCE_DIR" ]] || { echo "Error: missing skill source directory: $SOURCE_DIR" >&2; exit 1; }

for index in "${selected[@]}"; do
  root="${roots[$index]}"
  [[ -n "$root" ]] || { echo "Error: empty skill root for ${platforms[$index]}" >&2; exit 1; }
  mkdir -p "$root"
  root="$(cd "$root" && pwd -P)"
  roots[$index]="$root"
  target="$root/project-memory"
  for existing in "${targets[@]:-}"; do
    [[ -z "$existing" || "$existing" != "$target" ]] || { echo "Error: skill roots must resolve to distinct targets ($target)" >&2; exit 1; }
  done
  [[ -w "$root" ]] || { echo "Error: skill root is not writable: $root" >&2; exit 1; }
  targets[$index]="$target"
  backup_roots[$index]="$(dirname "$root")/skill-backups/project-memory/${keys[$index]}"

  stage="$(mktemp -d "$root/.project-memory.install.XXXXXX")"
  stages[$index]="$stage"
  cp -R "$SOURCE_DIR/." "$stage/"
done

for index in "${selected[@]}"; do
  target="${targets[$index]}"
  if [[ -e "$target" || -L "$target" ]]; then
    mkdir -p "${backup_roots[$index]}"
    backup="${backup_roots[$index]}/$(date +%Y%m%d%H%M%S)"
    suffix=1
    while [[ -e "$backup" || -L "$backup" ]]; do
      backup="${backup_roots[$index]}/$(date +%Y%m%d%H%M%S).$suffix"
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

# Relocate backups made by older installers so skill discovery cannot load them.
shopt -s nullglob
for index in "${selected[@]}"; do
  for legacy in "${roots[$index]}"/project-memory.backup.*; do
    [[ -f "$legacy/SKILL.md" ]] || continue
    grep -q '^name: project-memory$' "$legacy/SKILL.md" || continue
    mkdir -p "${backup_roots[$index]}"
    destination="$(mktemp -d "${backup_roots[$index]}/legacy.XXXXXX")"
    rmdir "$destination"
    mv "$legacy" "$destination"
    migrated_sources+=("$legacy")
    migrated_targets+=("$destination")
  done
done
rollback_needed=0
for index in "${selected[@]}"; do
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

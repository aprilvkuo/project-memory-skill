#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/install-common.sh"

for index in "${selected[@]}"; do
  platform="${platforms[$index]}"
  target="${roots[$index]}/project-memory"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    echo "$platform: project-memory is not installed at $target"
    continue
  fi

  rm -rf "$target"
  echo "Removed project-memory for $platform:"
  echo "  $target"
done

echo
echo "Project-local memory files and installation backups were not removed."

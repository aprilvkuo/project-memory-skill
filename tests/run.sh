#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash "$ROOT/tests/test-task-log-retention.sh"
bash "$ROOT/tests/test-memory-index.sh"
bash "$ROOT/tests/test-long-run.sh"

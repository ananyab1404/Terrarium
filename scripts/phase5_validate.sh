#!/usr/bin/env bash
set -euo pipefail

INFINITY_NODE_ROOT="${INFINITY_NODE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "${INFINITY_NODE_ROOT}"

echo "[phase5] Running concurrency/load validation"
JOBS="${JOBS:-100}" CONCURRENCY="${CONCURRENCY:-10}" \
  elixir --sname worker@localhost -S mix run scripts/load_validate_worker.exs

echo "[phase5] Running worker crash recovery validation"
SLOT_INDEX="${SLOT_INDEX:-0}" \
  elixir --sname worker@localhost -S mix run scripts/validate_worker_recovery.exs

echo "[phase5] Validation complete"

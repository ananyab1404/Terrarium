#!/usr/bin/env bash
set -euo pipefail

INFINITY_NODE_ROOT="${INFINITY_NODE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "${INFINITY_NODE_ROOT}"

ITERATIONS="${ITERATIONS:-100}" SLOT_INDEX="${SLOT_INDEX:-0}" \
  elixir --sname worker@localhost -S mix run scripts/snapshot_fidelity_validate.exs

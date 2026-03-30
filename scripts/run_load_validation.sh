#!/usr/bin/env bash
set -euo pipefail

INFINITY_NODE_ROOT="${INFINITY_NODE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "${INFINITY_NODE_ROOT}"

JOBS="${JOBS:-100}" CONCURRENCY="${CONCURRENCY:-10}" \
  elixir --sname worker@localhost -S mix run scripts/load_validate_worker.exs

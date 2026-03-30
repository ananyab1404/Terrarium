#!/usr/bin/env bash
set -euo pipefail

INFINITY_NODE_ROOT="${INFINITY_NODE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FC_ASSETS="${FC_ASSETS:-${INFINITY_NODE_ROOT}/firecracker/assets}"
WORKER_SLOTS="${WORKER_SLOTS:-10}"

echo "=== Infinity Node Worker Startup ==="

if [[ ! -c /dev/kvm ]]; then
  echo "FATAL: /dev/kvm not found. Bare-metal host required." >&2
  exit 1
fi

echo "[ok] KVM available"

if ! mount | grep -q cgroup2; then
  echo "FATAL: cgroups v2 not mounted." >&2
  exit 1
fi

echo "[ok] cgroups v2 active"

sudo mkdir -p /sys/fs/cgroup/infinity-node
sudo chown "$(whoami):$(whoami)" /sys/fs/cgroup/infinity-node

echo "[ok] cgroup root prepared"

if [[ -f "${FC_ASSETS}/rootfs-base.ext4" ]]; then
  for ((i=0; i<WORKER_SLOTS; i++)); do
    cp "${FC_ASSETS}/rootfs-base.ext4" "${FC_ASSETS}/rootfs-slot-${i}.ext4"
  done
  echo "[ok] rootfs slots reset (${WORKER_SLOTS})"
else
  echo "WARN: ${FC_ASSETS}/rootfs-base.ext4 missing, skipping slot reset" >&2
fi

cd "${INFINITY_NODE_ROOT}"
exec elixir --sname worker@localhost -S mix run --no-halt

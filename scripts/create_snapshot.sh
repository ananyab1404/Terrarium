#!/usr/bin/env bash
set -euo pipefail

# Creates a baseline Firecracker snapshot from a booted VM.
# Requires a Linux host with Firecracker installed and KVM enabled.

INFINITY_NODE_ROOT="${INFINITY_NODE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ASSETS_DIR="${FC_ASSETS:-${INFINITY_NODE_ROOT}/firecracker/assets}"
SNAPSHOT_DIR="${ASSETS_DIR}/snapshots"
FC_SOCKET="/tmp/fc-snapshot.socket"
FC_CONFIG="/tmp/fc-snapshot-config.json"
SLOT_INDEX="${SLOT_INDEX:-0}"
VSOCK_UDS="/tmp/fc-vsock-slot-${SLOT_INDEX}.socket"

mkdir -p "${SNAPSHOT_DIR}"
rm -f "${FC_SOCKET}"

cat > "${FC_CONFIG}" <<EOF
{
  "boot-source": {
    "kernel_image_path": "${ASSETS_DIR}/vmlinux",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "${ASSETS_DIR}/rootfs-base.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 1,
    "mem_size_mib": 128
  },
  "vsock": {
    "guest_cid": 3,
    "uds_path": "${VSOCK_UDS}"
  }
}
EOF

firecracker --api-sock "${FC_SOCKET}" --config-file "${FC_CONFIG}" &
FC_PID=$!

cleanup() {
  kill "${FC_PID}" 2>/dev/null || true
  rm -f "${FC_SOCKET}"
}
trap cleanup EXIT

for _ in {1..20}; do
  [[ -S "${FC_SOCKET}" ]] && break
  sleep 0.1
done

if [[ ! -S "${FC_SOCKET}" ]]; then
  echo "Firecracker API socket did not appear." >&2
  exit 1
fi

# Give the guest a brief warm-up before snapshotting.
sleep 1

curl --silent --show-error --fail --unix-socket "${FC_SOCKET}" \
  -X PUT "http://localhost/vm" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{"state":"Paused"}' >/dev/null

curl --silent --show-error --fail --unix-socket "${FC_SOCKET}" \
  -X PUT "http://localhost/snapshot/create" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{\"snapshot_type\":\"Full\",\"snapshot_path\":\"${SNAPSHOT_DIR}/vm.snap\",\"mem_file_path\":\"${SNAPSHOT_DIR}/vm.mem\"}" >/dev/null

echo "Snapshot created under ${SNAPSHOT_DIR}"

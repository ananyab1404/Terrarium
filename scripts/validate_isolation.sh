#!/usr/bin/env bash
set -euo pipefail

# Adversarial validation for Person 1 isolation requirements.
# Run this on a Linux worker host with cgroups v2 and Firecracker tooling installed.

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

pass() {
  echo "[PASS] $*"
}

require() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require jq
require curl
require unshare
require timeout

TEST_CGROUP="/sys/fs/cgroup/infinity-node/iso-test-$$"

cleanup() {
  if [[ -d "${TEST_CGROUP}" ]]; then
    sudo rmdir "${TEST_CGROUP}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

VM_API_SOCKET="${VM_API_SOCKET:-/tmp/fc-slot-0.socket}"

if mount | grep -q cgroup2; then
  pass "cgroups v2 mounted"
else
  fail "cgroups v2 is required"
fi

controllers=$(cat /sys/fs/cgroup/cgroup.controllers)
echo "${controllers}" | grep -q "cpu" || fail "cpu controller missing"
echo "${controllers}" | grep -q "memory" || fail "memory controller missing"
pass "cgroup controllers include cpu and memory"

sudo mkdir -p "${TEST_CGROUP}"
echo "134217728" | sudo tee "${TEST_CGROUP}/memory.max" >/dev/null
echo "500" | sudo tee "${TEST_CGROUP}/cpu.weight" >/dev/null

[[ "$(cat "${TEST_CGROUP}/memory.max")" == "134217728" ]] || fail "memory.max write did not persist"
[[ "$(cat "${TEST_CGROUP}/cpu.weight")" == "500" ]] || fail "cpu.weight write did not persist"
pass "cgroup memory and cpu limits writable"

if command -v infinity-jailer >/dev/null 2>&1; then
  infinity-jailer --help >/dev/null
  pass "infinity-jailer binary available"
else
  fail "infinity-jailer binary not found"
fi

# In a fresh network namespace, loopback exists only after manual setup and there is no outbound route.
if unshare -n bash -lc 'ip link set lo up; timeout 2 curl -sS https://example.com >/dev/null'; then
  fail "network namespace unexpectedly has outbound connectivity"
else
  pass "private netns blocks outbound connectivity by default"
fi

if [[ -S "${VM_API_SOCKET}" ]]; then
  pass "VM API socket exists"
else
  echo "[WARN] VM API socket not found (${VM_API_SOCKET}); live VM checks skipped"
fi

echo "Isolation validation completed."

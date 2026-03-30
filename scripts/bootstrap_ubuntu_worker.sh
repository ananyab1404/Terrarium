#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a fresh Ubuntu 22.04 metal host for Infinity Node worker development.
# Run this script on the target Ubuntu machine, not on Windows.

FC_VERSION="${FC_VERSION:-1.7.0}"
ERLANG_VERSION="${ERLANG_VERSION:-26.2.1}"
ELIXIR_VERSION="${ELIXIR_VERSION:-1.16.1-otp-26}"
INFINITY_NODE_ROOT="${INFINITY_NODE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ASSETS_DIR="${FC_ASSETS:-${INFINITY_NODE_ROOT}/firecracker/assets}"

log() {
  echo "[bootstrap] $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

assert_kvm() {
  if [[ ! -c /dev/kvm ]]; then
    echo "KVM not available on this host. A bare-metal EC2 instance (i3.metal or c5.metal) is required." >&2
    exit 1
  fi
  log "KVM device found at /dev/kvm"
}

assert_cgroups_v2() {
  if ! mount | grep -q "cgroup2 on /sys/fs/cgroup"; then
    echo "cgroups v2 is not active. Enable unified hierarchy and reboot, then rerun." >&2
    exit 1
  fi
  log "cgroups v2 is active"
}

install_apt_deps() {
  log "Installing apt dependencies"
  sudo apt-get update -y
  sudo apt-get install -y \
    curl wget git build-essential pkg-config libssl-dev unzip jq \
    screen htop iproute2 iptables socat strace awscli \
    musl-tools libncurses5-dev libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev \
    libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev \
    xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk
}

install_rust() {
  if ! command -v rustup >/dev/null 2>&1; then
    log "Installing rustup"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi

  # shellcheck disable=SC1090
  source "${HOME}/.cargo/env"
  rustup target add x86_64-unknown-linux-musl
  log "Rust: $(rustc --version)"
}

install_asdf() {
  if [[ ! -d "${HOME}/.asdf" ]]; then
    log "Installing asdf"
    git clone https://github.com/asdf-vm/asdf.git "${HOME}/.asdf" --branch v0.14.0
  fi

  # shellcheck disable=SC1091
  source "${HOME}/.asdf/asdf.sh"

  asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git 2>/dev/null || true
  asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git 2>/dev/null || true

  if ! asdf list erlang | grep -q "${ERLANG_VERSION}"; then
    log "Installing Erlang ${ERLANG_VERSION}"
    asdf install erlang "${ERLANG_VERSION}"
  fi
  asdf global erlang "${ERLANG_VERSION}"

  if ! asdf list elixir | grep -q "${ELIXIR_VERSION}"; then
    log "Installing Elixir ${ELIXIR_VERSION}"
    asdf install elixir "${ELIXIR_VERSION}"
  fi
  asdf global elixir "${ELIXIR_VERSION}"

  mix local.hex --force
  mix local.rebar --force
  log "Elixir: $(elixir --version | head -n 1)"
}

download_firecracker() {
  log "Installing Firecracker v${FC_VERSION}"
  wget -O /tmp/firecracker.tgz \
    "https://github.com/firecracker-microvm/firecracker/releases/download/v${FC_VERSION}/firecracker-v${FC_VERSION}-x86_64.tgz"
  tar -xzf /tmp/firecracker.tgz -C /tmp/

  sudo cp "/tmp/release-v${FC_VERSION}-x86_64/firecracker-v${FC_VERSION}-x86_64" /usr/local/bin/firecracker
  sudo cp "/tmp/release-v${FC_VERSION}-x86_64/jailer-v${FC_VERSION}-x86_64" /usr/local/bin/jailer
  sudo chmod +x /usr/local/bin/firecracker /usr/local/bin/jailer

  firecracker --version
  jailer --version
}

download_fc_assets() {
  log "Downloading Firecracker guest assets"
  mkdir -p "${ASSETS_DIR}"

  wget -O "${ASSETS_DIR}/vmlinux" \
    "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.7/x86_64/vmlinux-5.10.217"

  wget -O "${ASSETS_DIR}/rootfs.ext4" \
    "https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/v1.7/x86_64/ubuntu-22.04.ext4"

  cp "${ASSETS_DIR}/rootfs.ext4" "${ASSETS_DIR}/rootfs-base.ext4"
}

create_slot_rootfs() {
  local slots="${WORKER_SLOTS:-10}"
  log "Creating ${slots} rootfs slot copies"
  for ((i=0; i<slots; i++)); do
    cp "${ASSETS_DIR}/rootfs-base.ext4" "${ASSETS_DIR}/rootfs-slot-${i}.ext4"
  done
}

main() {
  require_cmd sudo
  assert_kvm
  assert_cgroups_v2
  install_apt_deps
  install_rust
  install_asdf
  download_firecracker
  download_fc_assets
  create_slot_rootfs
  log "Bootstrap complete"
}

main "$@"

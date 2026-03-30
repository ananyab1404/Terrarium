#!/bin/bash
set -euxo pipefail

# Amazon Linux 2023 bootstrap for Firecracker host
# NOTE: Firecracker requires KVM-capable instance families (metal is preferred).

dnf update -y

dnf install -y \
  git \
  jq \
  curl \
  wget \
  tar \
  iproute \
  iptables \
  util-linux \
  procps-ng \
  tmux

# Install Firecracker + Jailer (latest release)
ARCH="x86_64"
FC_VERSION=$(curl -s https://api.github.com/repos/firecracker-microvm/firecracker/releases/latest | jq -r .tag_name)

mkdir -p /opt/firecracker
cd /opt/firecracker

curl -LO "https://github.com/firecracker-microvm/firecracker/releases/download/${FC_VERSION}/firecracker-${FC_VERSION}-${ARCH}.tgz"
tar -xzf "firecracker-${FC_VERSION}-${ARCH}.tgz"

install -m 0755 release-${FC_VERSION}-${ARCH}/firecracker-${FC_VERSION}-${ARCH} /usr/local/bin/firecracker
install -m 0755 release-${FC_VERSION}-${ARCH}/jailer-${FC_VERSION}-${ARCH} /usr/local/bin/jailer

# Create service user/group
groupadd -f firecracker
id -u firecracker >/dev/null 2>&1 || useradd -r -g firecracker -s /sbin/nologin firecracker

# KVM permissions for firecracker user
chgrp kvm /dev/kvm || true
chmod g+rw /dev/kvm || true
usermod -aG kvm firecracker || true

# Working directories
mkdir -p /var/lib/firecracker /var/log/firecracker /etc/firecracker
chown -R firecracker:firecracker /var/lib/firecracker /var/log/firecracker

# Minimal host tuning for many microVM sockets/files
cat >/etc/sysctl.d/99-firecracker.conf <<'EOF'
fs.file-max = 1000000
net.core.somaxconn = 4096
vm.max_map_count = 262144
EOF
sysctl --system

# Optional: prepare cgroup v2 mount point check
mount | grep cgroup2 || true

# Marker file
cat >/etc/firecracker/BOOTSTRAP_DONE <<'EOF'
Firecracker host bootstrap completed.
EOF

# TODO(other project integration):
# - install snapshot base kernel/rootfs artifacts
# - configure seccomp policy generation pipeline
# - install node agent that receives jobs over vsock

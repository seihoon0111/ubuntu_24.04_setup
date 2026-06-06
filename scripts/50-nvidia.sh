#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# NVIDIA proprietary drivers — only when an NVIDIA GPU is present.

if ! command -v lspci >/dev/null 2>&1; then
  sudo apt install -y pciutils
fi

if ! lspci | grep -qi nvidia; then
  warn "NVIDIA GPU not detected; skipping driver installation."
  exit 0
fi

log "NVIDIA GPU detected. Installing recommended drivers"
apt_install ubuntu-drivers-common
sudo ubuntu-drivers autoinstall
warn "NVIDIA driver installed. A reboot is required to take effect."

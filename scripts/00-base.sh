#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# System update + base build/dependency packages.

log "Updating OS packages"
sudo apt update
sudo apt dist-upgrade -y

log "Installing base packages"
apt_install \
  build-essential git curl wget rsync ca-certificates gnupg lsb-release \
  software-properties-common apt-transport-https unzip dbus-x11 pciutils net-tools

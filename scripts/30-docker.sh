#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Docker Engine + Compose from Docker's official apt repository.

log "Adding Docker apt repository"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt update
log "Installing Docker Engine + Compose"
apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow running docker without sudo (takes effect after re-login).
if ! getent group docker >/dev/null; then
  sudo groupadd docker
fi
sudo usermod -aG docker "$USER"
warn "Added '$USER' to the 'docker' group. Log out and back in for it to take effect."

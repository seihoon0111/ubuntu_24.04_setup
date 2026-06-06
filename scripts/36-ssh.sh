#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# OpenSSH server so other machines can connect to this desktop — e.g. a Windows
# laptop running VS Code with the "Remote - SSH" extension.

log "Installing OpenSSH server"
apt_install openssh-server

log "Enabling and starting the SSH service"
sudo systemctl enable ssh >/dev/null 2>&1 || true
sudo systemctl restart ssh

# Open the firewall for SSH only if ufw is installed and active.
if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  log "Allowing SSH through ufw"
  sudo ufw allow OpenSSH || true
fi

ip_addr="$(hostname -I 2>/dev/null | awk '{print $1}')"
log "SSH ready."
log "From the laptop:           ssh $USER@${ip_addr:-<ubuntu-ip>}"
log "VS Code (Windows):         install 'Remote - SSH' extension ->"
log "                           Ctrl+Shift+P -> 'Remote-SSH: Connect to Host' -> $USER@${ip_addr:-<ubuntu-ip>}"
warn "Tip: reserve a static IP for this PC in your router (DHCP) so the address won't change."
warn "For better security, set up SSH key authentication from the laptop instead of a password."

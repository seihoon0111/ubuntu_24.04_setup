#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Samba file sharing with Windows.
# Shares ~/Share read/write, restricted to the current user (authenticated —
# NOT guest/anonymous). From Windows Explorer:  \\<ubuntu-ip>\Share

SHARE_NAME="Share"
SHARE_DIR="$HOME/$SHARE_NAME"

log "Installing Samba"
apt_install samba

log "Creating share directory: $SHARE_DIR"
mkdir -p "$SHARE_DIR"

# Add the share definition only if it isn't already in smb.conf.
if ! grep -q "^\[$SHARE_NAME\]" /etc/samba/smb.conf; then
  log "Adding [$SHARE_NAME] share to /etc/samba/smb.conf"
  sudo tee -a /etc/samba/smb.conf >/dev/null <<EOF

[$SHARE_NAME]
   path = $SHARE_DIR
   browseable = yes
   read only = no
   create mask = 0644
   directory mask = 0755
   valid users = $USER
EOF
else
  log "[$SHARE_NAME] already defined in smb.conf; leaving it unchanged."
fi

# Sanity-check the config.
sudo testparm -s >/dev/null 2>&1 || warn "testparm reported issues in smb.conf — please review."

# Open the firewall for Samba only if ufw is installed and active.
if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  log "Allowing Samba through ufw"
  sudo ufw allow samba || true
fi

log "Restarting Samba services"
sudo systemctl enable smbd >/dev/null 2>&1 || true
sudo systemctl restart smbd || true
sudo systemctl restart nmbd 2>/dev/null || true

# A Samba password (separate from the login password) is required to connect.
if sudo pdbedit -L 2>/dev/null | grep -q "^$USER:"; then
  log "Samba user '$USER' already exists; skipping password setup."
elif [[ "$ASSUME_YES" -eq 1 ]]; then
  warn "Set your Samba password manually before connecting:  sudo smbpasswd -a $USER"
else
  log "Set a Samba password for '$USER' (used when connecting from Windows)"
  sudo smbpasswd -a "$USER" || warn "smbpasswd failed; run 'sudo smbpasswd -a $USER' later."
fi

ip_addr="$(hostname -I 2>/dev/null | awk '{print $1}')"
log "Samba ready. From Windows Explorer:  \\\\${ip_addr:-<ubuntu-ip>}\\$SHARE_NAME"
log "Connect with username '$USER' and the Samba password you set above."

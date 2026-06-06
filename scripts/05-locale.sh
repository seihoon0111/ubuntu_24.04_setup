#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Locale policy: English messages + English XDG folder names, but Korean
# regional formats (date/time, currency, paper size, measurement).
# Korean *input* is handled separately by ibus-hangul (60-korean.sh) and is
# independent of the locale, so the UI/terminal/folders stay English.

log "Generating en_US.UTF-8 and ko_KR.UTF-8 locales"
apt_install locales xdg-user-dirs
sudo locale-gen en_US.UTF-8 ko_KR.UTF-8

log "Setting system locale (English UI, Korean regional formats)"
sudo update-locale \
  LANG=en_US.UTF-8 \
  LC_MESSAGES=en_US.UTF-8 \
  LC_TIME=ko_KR.UTF-8 \
  LC_MONETARY=ko_KR.UTF-8 \
  LC_PAPER=ko_KR.UTF-8 \
  LC_MEASUREMENT=ko_KR.UTF-8

log "Forcing English XDG user directory names (Downloads, Documents, ...)"
LANG=en_US.UTF-8 xdg-user-dirs-update --force || warn "xdg-user-dirs-update failed (no session?)."

# Stop GNOME from offering to rename folders to the current language later.
mkdir -p "$HOME/.config"
if [[ -f "$HOME/.config/user-dirs.conf" ]] && grep -q '^enabled=' "$HOME/.config/user-dirs.conf"; then
  sed -i 's/^enabled=.*/enabled=False/' "$HOME/.config/user-dirs.conf"
else
  echo 'enabled=False' >> "$HOME/.config/user-dirs.conf"
fi

warn "Locale changes apply to NEW sessions. Log out and back in to see them everywhere."

#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Korean input via ibus-hangul + language support.
# NOTE: run this AFTER the theme dconf load, since it sets the GNOME input
# sources, which a dconf import could otherwise overwrite.

log "Installing Korean language support and ibus-hangul"
apt_install language-selector-common ibus ibus-hangul fonts-noto-cjk

# check-language-support prints the recommended package list for Korean.
ko_pkgs="$(check-language-support -l ko 2>/dev/null || true)"
if [[ -n "$ko_pkgs" ]]; then
  # shellcheck disable=SC2086
  apt_install_optional $ko_pkgs
fi

# Remap right Alt to the Hangul key (for keyboards without a dedicated 한/영 key).
altwin=/usr/share/X11/xkb/symbols/altwin
if [[ -f "$altwin" ]]; then
  sudo sed -i 's/symbols\[Group1\] = \[ Alt_R, Meta_R \] };/symbols[Group1] = [ Hangul ] };/g' "$altwin"
fi

# Register ibus-hangul as an input source (US + Korean).
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'hangul')]" 2>/dev/null \
  || warn "Could not set GNOME input sources (no graphical session?). Add Korean input manually if needed."

# Set Noto Sans CJK KR (from fonts-noto-cjk) as the UI-wide font.
# Monospace (terminal/code) is intentionally left untouched. Runs after the
# theme dconf import, so these values take precedence.
KR_FONT="Noto Sans CJK KR"
gsettings set org.gnome.desktop.interface font-name "$KR_FONT 11" 2>/dev/null || true
gsettings set org.gnome.desktop.interface document-font-name "$KR_FONT 11" 2>/dev/null || true
gsettings set org.gnome.desktop.wm.preferences titlebar-font "$KR_FONT Bold 11" 2>/dev/null || true

ibus restart 2>/dev/null || true

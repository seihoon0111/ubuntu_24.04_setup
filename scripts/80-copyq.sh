#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# CopyQ clipboard manager: install, autostart, and bind Super+V to toggle it.
# Runs as the normal user, so plain gsettings is used (no sudo/DISPLAY/DBUS juggling).
# Run AFTER the theme dconf import so the custom keybinding is not overwritten.

MK="org.gnome.settings-daemon.plugins.media-keys"

# True only when a usable GNOME/dconf session is reachable from this process.
has_gnome_session() {
  command -v gsettings >/dev/null 2>&1 && \
    gsettings get org.gnome.desktop.interface gtk-theme >/dev/null 2>&1
}

log "Installing CopyQ clipboard manager"
apt_install copyq

log "Configuring CopyQ autostart"
mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/copyq.desktop" <<'EOF'
[Desktop Entry]
Name=CopyQ
Icon=copyq
GenericName=Clipboard Manager
Comment=Advanced clipboard manager with editing and scripting features
Exec=env QT_QPA_PLATFORM=xcb copyq
Terminal=false
Type=Application
Categories=Qt;KDE;Utility;
X-GNOME-Autostart-enabled=true
EOF
chmod +x "$HOME/.config/autostart/copyq.desktop"

# CopyQ's own config (keeps its internal global shortcut too; harmless on Wayland).
mkdir -p "$HOME/.config/copyq"
[[ -f "$HOME/.config/copyq/copyq.conf" ]] || touch "$HOME/.config/copyq/copyq.conf"
cat > "$HOME/.config/copyq/shortcuts.ini" <<'EOF'
[Commands]
1\Command=copyq: showAt()
1\GlobalShortcut=meta+v
1\Icon=\xf022
1\IsGlobalShortcut=true
1\Name=Show/hide main window
size=1
EOF

if ! has_gnome_session; then
  warn "No GNOME session reachable; CopyQ installed but Super+V shortcut not set."
  warn "Re-run inside a GNOME session: bash scripts/80-copyq.sh"
  exit 0
fi

# 1) Strip any existing <Super>v bindings so the new one does not conflict.
log "Removing conflicting <Super>v shortcuts"
while read -r schema key _; do
  [[ -z "${schema:-}" ]] && continue
  cur="$(gsettings get "$schema" "$key" 2>/dev/null || echo)"
  case "$cur" in
    "['<Super>v']")        new="@as []" ;;
    *"'<Super>v', "*)      new="$(printf '%s' "$cur" | sed "s/'<Super>v', //")" ;;
    *", '<Super>v'"*)      new="$(printf '%s' "$cur" | sed "s/, '<Super>v'//")" ;;
    *) continue ;;
  esac
  gsettings set "$schema" "$key" "$new" 2>/dev/null \
    && log "  cleared <Super>v from $schema $key" || true
done < <(gsettings list-recursively 2>/dev/null | grep -F "'<Super>v'" || true)

# 2) Register a custom keybinding for CopyQ — but skip if one already exists.
cur_keys="$(gsettings get "$MK" custom-keybindings 2>/dev/null || echo '@as []')"

copyq_exists=0
if [[ "$cur_keys" != "@as []" && -n "$cur_keys" ]]; then
  for kp in $(printf '%s' "$cur_keys" | grep -o "custom-keybindings/custom[0-9]\+/"); do
    cmd="$(gsettings get "$MK.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/$kp" command 2>/dev/null || echo)"
    [[ "$cmd" == *copyq* ]] && copyq_exists=1 && break
  done
fi

if [[ "$copyq_exists" -eq 1 ]]; then
  log "CopyQ custom shortcut already present; skipping."
else
  if [[ "$cur_keys" == "@as []" || -z "$cur_keys" ]]; then
    next=0
    new_keys="['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
  else
    last="$(printf '%s' "$cur_keys" | grep -o 'custom[0-9]\+' | sed 's/custom//' | sort -n | tail -1)"
    next=$((last + 1))
    inner="$(printf '%s' "$cur_keys" | sed 's/\[//; s/\]//')"
    newpath="'/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom$next/'"
    new_keys="[$inner, $newpath]"
  fi

  log "Adding CopyQ shortcut as custom$next (Super+V)"
  gsettings set "$MK" custom-keybindings "$new_keys"
  kb="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom$next/"
  gsettings set "$MK.custom-keybinding:$kb" name "CopyQ Clipboard Manager"
  gsettings set "$MK.custom-keybinding:$kb" command 'copyq -e "toggle()"'
  gsettings set "$MK.custom-keybinding:$kb" binding "<Super>v"
fi

log "CopyQ configured. Super+V toggles the clipboard manager."

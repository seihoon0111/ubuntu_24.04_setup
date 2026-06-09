#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Create desktop shortcuts (.desktop launchers) on ~/Desktop.
# Needs a GNOME session with desktop icons (Ubuntu's default "Desktop Icons NG"
# extension shows files placed in ~/Desktop).
#
# Customize the two lists below to taste.

DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR"

# Installed apps to add, by .desktop id (without the .desktop suffix).
# Missing ones are skipped, so it's safe to list apps you may not have.
APP_LAUNCHERS=(
  code                  # VS Code
  google-chrome         # Chrome
  xpad                  # Xpad sticky notes
  org.gnome.Nautilus    # Files
  org.gnome.Terminal    # Terminal
)

# Folder shortcuts as "Label=/absolute/path". Missing folders are skipped.
FOLDER_SHORTCUTS=(
  "Downloads=$HOME/Downloads"
  "Share=$HOME/Share"
)

# Mark a .desktop as executable + trusted so it launches without the
# "Untrusted launcher" warning (DING reads metadata::trusted).
trust() {
  chmod +x "$1" 2>/dev/null || true
  gio set "$1" metadata::trusted true 2>/dev/null || true
}

# Search locations for installed app .desktop files (apt + flatpak + user).
app_desktop_path() {
  local id="$1" d
  for d in /usr/share/applications \
           /var/lib/flatpak/exports/share/applications \
           "$HOME/.local/share/flatpak/exports/share/applications" \
           "$HOME/.local/share/applications"; do
    [[ -f "$d/$id.desktop" ]] && { printf '%s\n' "$d/$id.desktop"; return 0; }
  done
  return 1
}

log "Creating app shortcuts in $DESKTOP_DIR"
for app in "${APP_LAUNCHERS[@]}"; do
  if src="$(app_desktop_path "$app")"; then
    cp -f "$src" "$DESKTOP_DIR/$app.desktop"
    trust "$DESKTOP_DIR/$app.desktop"
    log "  + $app"
  else
    warn "  app not found, skipped: $app"
  fi
done

log "Creating folder shortcuts in $DESKTOP_DIR"
for entry in "${FOLDER_SHORTCUTS[@]}"; do
  label="${entry%%=*}"
  path="${entry#*=}"
  if [[ -d "$path" ]]; then
    f="$DESKTOP_DIR/${label}.desktop"
    cat > "$f" <<EOF
[Desktop Entry]
Type=Application
Name=$label
Comment=Open $path
Exec=xdg-open "$path"
Icon=folder
Terminal=false
Categories=Utility;
EOF
    trust "$f"
    log "  + $label -> $path"
  else
    warn "  folder not found, skipped: $path"
  fi
done

log "Done. Shortcuts are in $DESKTOP_DIR."
warn "If an icon still shows 'Untrusted launcher', right-click it once and choose 'Allow Launching'."

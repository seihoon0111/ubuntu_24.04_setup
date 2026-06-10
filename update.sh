#!/usr/bin/env bash
set -Eeuo pipefail

# ── update.sh ────────────────────────────────────────────────────────────────
# Declaratively manage desktop shortcuts on ~/Desktop.
#
#   1) Edit the three lists below (add / remove entries).
#   2) Run:  ./update.sh
#
# Each run ADDS every shortcut in the lists and REMOVES any shortcut it created
# on a previous run that you have since deleted from the lists. What it created
# is tracked in ~/.config/ubuntu-setup/desktop-shortcuts.list, so your own
# (hand-made) desktop files are NEVER touched.
#
# Run as a normal user — no sudo needed (everything is under $HOME).
# ─────────────────────────────────────────────────────────────────────────────

# 1) Installed apps, by .desktop id (without the .desktop suffix).
#    Find an id with:  ls /usr/share/applications/ | grep -i <name>
APP_LAUNCHERS=(
  code
  google-chrome
  xpad
  org.gnome.Nautilus
  org.gnome.Terminal
)

# 2) Folder shortcuts as "Label=/absolute/path".
FOLDER_SHORTCUTS=(
  "Downloads=$HOME/Downloads"
  "Share=$HOME/Share"
)

# 3) Custom shortcuts as "Label|Exec command|IconName" (icon optional).
CUSTOM_SHORTCUTS=(
  # "GitHub|xdg-open https://github.com|web-browser"
  # "New note|xpad --new-pad|xpad"
)

# ─────────────────────────────────────────────────────────────────────────────
DESKTOP_DIR="$HOME/Desktop"
STATE_DIR="$HOME/.config/ubuntu-setup"
STATE_FILE="$STATE_DIR/desktop-shortcuts.list"
mkdir -p "$DESKTOP_DIR" "$STATE_DIR"

c_blue=$'\033[1;34m'; c_yellow=$'\033[1;33m'; c_reset=$'\033[0m'
log()  { printf '%s[update]%s %s\n' "$c_blue"   "$c_reset" "$*"; }
warn() { printf '%s[skip]%s %s\n'   "$c_yellow" "$c_reset" "$*"; }

# Make a .desktop launchable without the "Untrusted launcher" warning.
trust() {
  chmod +x "$1" 2>/dev/null || true
  gio set "$1" metadata::trusted true 2>/dev/null || true
}

# Locate an installed app's .desktop across apt / flatpak / user dirs.
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

declare -A want=()   # desired .desktop basenames for this run

log "Syncing shortcuts in $DESKTOP_DIR"

# 1) Installed apps — copy their .desktop onto the desktop.
for app in "${APP_LAUNCHERS[@]}"; do
  if src="$(app_desktop_path "$app")"; then
    cp -f "$src" "$DESKTOP_DIR/$app.desktop"
    trust "$DESKTOP_DIR/$app.desktop"
    want["$app.desktop"]=1
    log "  app    + $app"
  else
    warn "  app not found: $app"
  fi
done

# 2) Folder shortcuts.
for entry in "${FOLDER_SHORTCUTS[@]}"; do
  label="${entry%%=*}"; path="${entry#*=}"
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
    want["${label}.desktop"]=1
    log "  folder + $label -> $path"
  else
    warn "  folder not found: $path"
  fi
done

# 3) Custom command/URL shortcuts.
for entry in "${CUSTOM_SHORTCUTS[@]}"; do
  [[ -z "$entry" ]] && continue
  IFS='|' read -r label cmd icon <<< "$entry"
  if [[ -z "${label:-}" || -z "${cmd:-}" ]]; then
    warn "  bad custom entry (need 'Label|Exec|Icon'): $entry"
    continue
  fi
  f="$DESKTOP_DIR/${label}.desktop"
  cat > "$f" <<EOF
[Desktop Entry]
Type=Application
Name=$label
Exec=$cmd
Icon=${icon:-application-x-executable}
Terminal=false
Categories=Utility;
EOF
  trust "$f"
  want["${label}.desktop"]=1
  log "  custom + $label"
done

# Remove shortcuts this script created previously but are no longer listed.
if [[ -f "$STATE_FILE" ]]; then
  while IFS= read -r old; do
    [[ -z "$old" ]] && continue
    if [[ -z "${want[$old]:-}" ]]; then
      rm -f "$DESKTOP_DIR/$old" && log "  removed  - $old"
    fi
  done < "$STATE_FILE"
fi

# Persist the new managed set.
: > "$STATE_FILE"
for k in "${!want[@]}"; do printf '%s\n' "$k" >> "$STATE_FILE"; done

log "Done. ${#want[@]} shortcut(s) currently managed on the desktop."

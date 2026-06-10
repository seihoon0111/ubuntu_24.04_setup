#!/usr/bin/env bash
set -Eeuo pipefail

# ── update.sh ────────────────────────────────────────────────────────────────
# Sync desktop shortcuts on ~/Desktop from a human-friendly list file.
#
#   1) Edit  shortcuts.txt   (app: / folder: / custom: lines)
#   2) Run:  ./update.sh
#
# Each run ADDS every entry in the list and REMOVES any shortcut it created on a
# previous run that is no longer listed (tracked in
# ~/.config/ubuntu-setup/desktop-shortcuts.list). Your own hand-made desktop
# files are NEVER touched. Run as a normal user (no sudo needed).
#
# Custom-shortcut icons may be a system icon name (e.g. web-browser) OR an image
# file you drop into the  application/  folder next to this script.
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${1:-$SCRIPT_DIR/shortcuts.txt}"          # optional: ./update.sh other.txt
APP_ICON_DIR="$SCRIPT_DIR/application"

DESKTOP_DIR="$HOME/Desktop"
STATE_DIR="$HOME/.config/ubuntu-setup"
STATE_FILE="$STATE_DIR/desktop-shortcuts.list"
mkdir -p "$DESKTOP_DIR" "$STATE_DIR"

c_blue=$'\033[1;34m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'; c_reset=$'\033[0m'
log()  { printf '%s[update]%s %s\n' "$c_blue"   "$c_reset" "$*"; }
warn() { printf '%s[skip]%s %s\n'   "$c_yellow" "$c_reset" "$*"; }
die()  { printf '%s[error]%s %s\n'  "$c_red"    "$c_reset" "$*" >&2; exit 1; }

[[ -f "$CONFIG" ]] || die "List file not found: $CONFIG"

# Trim leading/trailing whitespace.
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# Expand ~ and $HOME in a path (no arbitrary eval).
expand_path() {
  local p="$1"
  p="${p/#\~\//$HOME/}"
  p="${p//\$\{HOME\}/$HOME}"
  p="${p//\$HOME/$HOME}"
  printf '%s' "$p"
}

# Resolve an icon token: a file in application/ -> its path, else use as-is.
resolve_icon() {
  local ic="$1"
  if [[ -z "$ic" ]]; then printf 'application-x-executable'; return; fi
  if [[ -f "$APP_ICON_DIR/$ic" ]]; then printf '%s' "$APP_ICON_DIR/$ic"; else printf '%s' "$ic"; fi
}

# Make a .desktop launchable without the "Untrusted launcher" warning.
trust() { chmod +x "$1" 2>/dev/null || true; gio set "$1" metadata::trusted true 2>/dev/null || true; }

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

declare -A want=()   # desired .desktop basenames this run

log "Reading $CONFIG"

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="$(trim "$raw")"
  [[ -z "$line" || "${line:0:1}" == "#" ]] && continue   # blank / comment

  key="$(trim "${line%%:*}")"; key="${key,,}"            # before first ':'
  val="$(trim "${line#*:}")"                              # after first ':'

  case "$key" in
    app)
      [[ -z "$val" ]] && { warn "empty app: line"; continue; }
      if src="$(app_desktop_path "$val")"; then
        cp -f "$src" "$DESKTOP_DIR/$val.desktop"
        trust "$DESKTOP_DIR/$val.desktop"
        want["$val.desktop"]=1
        log "  app    + $val"
      else
        warn "  app not found: $val"
      fi
      ;;
    folder)
      label="$(trim "${val%%=*}")"
      path="$(expand_path "$(trim "${val#*=}")")"
      if [[ -z "$label" || "$val" != *=* ]]; then warn "  bad folder line (need Name=path): $val"; continue; fi
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
        trust "$f"; want["${label}.desktop"]=1
        log "  folder + $label -> $path"
      else
        warn "  folder not found: $path"
      fi
      ;;
    custom)
      IFS='|' read -r c_label c_cmd c_icon <<< "$val"
      c_label="$(trim "${c_label:-}")"; c_cmd="$(expand_path "$(trim "${c_cmd:-}")")"; c_icon="$(trim "${c_icon:-}")"
      if [[ -z "$c_label" || -z "$c_cmd" ]]; then warn "  bad custom line (need Name|Exec|Icon): $val"; continue; fi
      f="$DESKTOP_DIR/${c_label}.desktop"
      cat > "$f" <<EOF
[Desktop Entry]
Type=Application
Name=$c_label
Exec=$c_cmd
Icon=$(resolve_icon "$c_icon")
Terminal=false
Categories=Utility;
EOF
      trust "$f"; want["${c_label}.desktop"]=1
      log "  custom + $c_label"
      ;;
    *)
      warn "  unknown line (expected app:/folder:/custom:): $line"
      ;;
  esac
done < "$CONFIG"

# Remove shortcuts created on a previous run that are no longer listed.
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

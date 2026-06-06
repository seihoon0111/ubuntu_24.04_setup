#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# GUI applications: VS Code, Google Chrome (latest), media apps.
# No terminal emulator here — the theme themes GNOME Terminal + fish/oh-my-posh.

# --- Visual Studio Code (Microsoft repository) ---
if ! command -v code >/dev/null 2>&1; then
  log "Installing Visual Studio Code"
  tmpkey="$(mktemp)"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "$tmpkey"
  sudo install -D -o root -g root -m 644 "$tmpkey" /etc/apt/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  rm -f "$tmpkey"
  sudo apt update
  apt_install code
else
  log "VS Code already installed; skipping."
fi

# --- Google Chrome (official repository, always latest + auto-updates) ---
if ! command -v google-chrome >/dev/null 2>&1; then
  log "Installing Google Chrome (latest)"
  sudo install -m 0755 -d /etc/apt/keyrings
  wget -qO- https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
  sudo chmod a+r /etc/apt/keyrings/google-chrome.gpg
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
    | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
  sudo apt update
  apt_install google-chrome-stable
else
  log "Google Chrome already installed; skipping."
fi

# Terminal: none installed here on purpose — the theme themes GNOME Terminal
# (profiles + dock pin) and sets fish + oh-my-posh as the shell.

# --- Celluloid: GTK media player (mpv frontend), used instead of VLC ---
apt_install_optional celluloid

# --- Timeshift: system snapshot / restore tool ---
apt_install_optional timeshift

# --- Media codecs + MS fonts (gstreamer, mp3/h264, Arial, etc.) ---
# ttf-mscorefonts-installer shows an EULA prompt; pre-accept it for a hands-free install.
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true \
  | sudo debconf-set-selections
sudo DEBIAN_FRONTEND=noninteractive apt install -y ubuntu-restricted-extras \
  || warn "ubuntu-restricted-extras installation failed."

# Add more GUI apps here as needed, e.g.:
#   apt_install_optional gimp inkscape obs-studio
#   Flatpak / .deb apps (Slack, Discord, Obsidian) can be added in their own module.

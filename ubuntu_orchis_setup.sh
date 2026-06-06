#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu GNOME desktop customization script based on the provided installation notes.
# Run as a normal user, not with sudo:
#   chmod +x ubuntu_orchis_setup.sh
#   ./ubuntu_orchis_setup.sh
# Optional flags:
#   --yes                 Skip confirmation prompts where possible
#   --remove-snap          Remove Snap packages and block snapd reinstall
#   --set-fish-shell       Change the login shell to fish
#   --lxc                 LXC/container mode: skip boot/desktop-only steps such as Plymouth
#   --skip-flatpak         Skip Flatpak setup
#   --skip-plymouth        Skip Plymouth theme setup
#   --skip-firefox         Skip Mozilla Team PPA Firefox installation
#   --skip-firefox-theme   Skip WhiteSur Firefox theme installation
#   --skip-gnome-apps      Skip optional GNOME app installation

# Resolve the directory this script lives in, so the bundled theme/ assets
# can be located regardless of where the script is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$SCRIPT_DIR/theme"

ASSUME_YES=0
REMOVE_SNAP=0
SET_FISH_SHELL=0
LXC_MODE=0
SKIP_FLATPAK=0
SKIP_PLYMOUTH=0
SKIP_FIREFOX=0
SKIP_FIREFOX_THEME=0
SKIP_GNOME_APPS=0

for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    --remove-snap) REMOVE_SNAP=1 ;;
    --set-fish-shell) SET_FISH_SHELL=1 ;;
    --lxc) LXC_MODE=1; SKIP_PLYMOUTH=1 ;;
    --skip-flatpak) SKIP_FLATPAK=1 ;;
    --skip-plymouth) SKIP_PLYMOUTH=1 ;;
    --skip-firefox) SKIP_FIREFOX=1 ;;
    --skip-firefox-theme) SKIP_FIREFOX_THEME=1 ;;
    --skip-gnome-apps) SKIP_GNOME_APPS=1 ;;
    -h|--help)
      sed -n '1,28p' "$0"
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err()  { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }

confirm() {
  local msg="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "$msg [y/N]: " ans
  [[ "$ans" == "y" || "$ans" == "Y" || "$ans" == "yes" || "$ans" == "YES" ]]
}

apt_install() {
  sudo apt install -y "$@"
}

apt_install_optional() {
  for pkg in "$@"; do
    if ! sudo apt install -y "$pkg"; then
      warn "Package installation failed or package not available: $pkg"
    fi
  done
}

safe_unzip() {
  local zipfile="$1"
  local dest="$2"
  if [[ -f "$zipfile" ]]; then
    mkdir -p "$dest"
    unzip -o "$zipfile" -d "$dest"
  else
    warn "Missing file, skipped unzip: $zipfile"
  fi
}

require_normal_user() {
  if [[ "${EUID}" -eq 0 ]]; then
    err "Do not run this script with sudo. Run it as a normal user; the script will call sudo only where required."
    exit 1
  fi
}

main() {
  require_normal_user

  log "Updating OS packages"
  sudo apt update
  sudo apt dist-upgrade -y

  log "Installing base applications and dependency packages"
  apt_install \
    curl rsync git gdebi nautilus-admin nautilus-extension-gnome-terminal \
    sassc gnome-tweaks gnome-shell-extension-manager wget unzip ca-certificates

  log "Locating bundled theme assets"
  if [[ ! -d "$THEME_DIR" ]]; then
    err "Theme asset directory not found: $THEME_DIR"
    err "Keep the 'theme' folder next to this script and re-run."
    exit 1
  fi
  log "Using theme assets from: $THEME_DIR"

  log "Installing GNOME extensions"
  safe_unzip "$THEME_DIR/gnome-extensions.zip" "$HOME/.local/share/gnome-shell"

  log "Installing GTK themes"
  mkdir -p "$HOME/.themes"
  safe_unzip "$THEME_DIR/GTK-Themes.zip" "$HOME/.themes"
  mkdir -p "$HOME/.config/gtk-4.0"
  if [[ -d "$HOME/.themes/Orchis-Dark/gtk-4.0" ]]; then
    ln -sf "$HOME/.themes/Orchis-Dark/gtk-4.0/assets" "$HOME/.config/gtk-4.0/assets"
    ln -sf "$HOME/.themes/Orchis-Dark/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
    ln -sf "$HOME/.themes/Orchis-Dark/gtk-4.0/gtk-dark.css" "$HOME/.config/gtk-4.0/gtk-dark.css"
  else
    warn "Orchis-Dark gtk-4.0 directory not found; GTK 4 symlinks skipped."
  fi

  log "Installing icon and cursor themes"
  mkdir -p "$HOME/.local/share/icons"
  safe_unzip "$THEME_DIR/icon-themes.zip" "$HOME/.local/share/icons"
  mkdir -p "$HOME/.icons"
  safe_unzip "$THEME_DIR/cursors-theme.zip" "$HOME/.icons"

  log "Installing fonts and wallpapers"
  safe_unzip "$THEME_DIR/fonts.zip" "$HOME/.local/share"
  if [[ -f "$THEME_DIR/wallpapers.zip" ]]; then
    sudo unzip -o "$THEME_DIR/wallpapers.zip" -d /usr/share/backgrounds/
  else
    warn "Missing file, skipped wallpapers: $THEME_DIR/wallpapers.zip"
  fi
  fc-cache -fv || true

  log "Installing and configuring Conky"
  apt_install conky-all jq curl playerctl
  safe_unzip "$THEME_DIR/conky-config.zip" "$HOME/.config"

  log "Installing and configuring Cava and NeoFetch"
  apt_install cava neofetch
  safe_unzip "$THEME_DIR/cava-config.zip" "$HOME/.config"
  # Extracts neofetch/config.conf and neofetch/idk.txt (ASCII logo) into ~/.config/neofetch
  safe_unzip "$THEME_DIR/neofetch-config.zip" "$HOME/.config"

  log "Installing fish shell and Oh My Posh"
  apt_install fish
  sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 \
    -O /usr/local/bin/oh-my-posh
  sudo chmod +x /usr/local/bin/oh-my-posh
  safe_unzip "$THEME_DIR/fishomp-config.zip" "$HOME"
  if [[ -d "$HOME/.poshthemes" ]]; then
    chmod u+rw "$HOME"/.poshthemes/*.json || true
  fi

  if [[ "$SET_FISH_SHELL" -eq 1 ]]; then
    log "Changing login shell to fish"
    chsh -s /usr/bin/fish "$USER"
  else
    warn "Login shell was not changed. Re-run with --set-fish-shell if you want fish as the default shell."
  fi

  if [[ "$SKIP_FLATPAK" -eq 0 ]]; then
    log "Installing Flatpak and AppImage support"
    apt_install gnome-software gnome-software-plugin-flatpak flatpak libfuse2
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || \
      flatpak remote-add --if-not-exists flathub http://flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub io.bassi.Amberol || warn "Amberol Flatpak installation failed. You may retry manually."
    sudo flatpak override --filesystem="$HOME/.themes"
    sudo flatpak override --filesystem="$HOME/.local/share/icons"
    sudo flatpak override --filesystem=xdg-config/gtk-4.0
  else
    warn "Flatpak setup skipped."
  fi

  if [[ "$SKIP_GNOME_APPS" -eq 0 ]]; then
    log "Installing optional GNOME applications"
    apt_install_optional \
      gnome-weather gnome-maps gnome-audio gnome-calendar gnome-clocks \
      gnome-connections gnome-console gnome-contacts gnome-music gnome-shell-pomodoro
  else
    warn "Optional GNOME app installation skipped."
  fi

  if [[ "$SKIP_PLYMOUTH" -eq 0 ]]; then
    log "Installing and configuring Plymouth theme"
    apt_install plymouth initramfs-tools
    if [[ -f "$THEME_DIR/plymouth-theme.zip" ]]; then
      sudo unzip -o "$THEME_DIR/plymouth-theme.zip" -d /usr/share/plymouth/themes
      if [[ -f /usr/share/plymouth/themes/hexagon_dots/hexagon_dots.plymouth ]]; then
        sudo update-alternatives --install \
          /usr/share/plymouth/themes/default.plymouth \
          default.plymouth \
          /usr/share/plymouth/themes/hexagon_dots/hexagon_dots.plymouth \
          100
        sudo update-alternatives --set default.plymouth \
          /usr/share/plymouth/themes/hexagon_dots/hexagon_dots.plymouth
        sudo update-initramfs -u
      else
        warn "hexagon_dots Plymouth theme file not found."
      fi
    else
      warn "Missing file, skipped Plymouth theme: $THEME_DIR/plymouth-theme.zip"
    fi
  else
    warn "Plymouth setup skipped."
  fi

  log "Applying GNOME shell settings"
  if [[ -f "$THEME_DIR/ubuntu-desktop-settings.zip" ]]; then
    unzip -o "$THEME_DIR/ubuntu-desktop-settings.zip" -d "$HOME/Downloads/"
  fi
  if [[ -f "$HOME/Downloads/ubuntu-desktop-settings.conf" ]]; then
    dconf load / < "$HOME/Downloads/ubuntu-desktop-settings.conf"
  else
    warn "GNOME dconf settings file not found; skipped dconf load."
  fi

  if [[ "$REMOVE_SNAP" -eq 1 ]]; then
    if confirm "This will remove Snap packages and block snapd reinstall. Continue?"; then
      log "Removing Snap apps and service"
      if [[ -d "$HOME/snap" ]]; then
        cp -afv "$HOME/snap" "$HOME/Downloads/" || true
      fi
      for snap_pkg in \
        firefox snap-store gnome-42-2204 gtk-common-themes snapd-desktop-integration \
        firmware-updater core22 bare snapd; do
        sudo snap remove --purge "$snap_pkg" || true
      done
      sudo apt autoremove --remove snapd -y || true
      sudo rm -rf /var/cache/snapd/
      cat <<'NOSNAP' | sudo tee /etc/apt/preferences.d/nosnap.pref >/dev/null
Package: snapd
Pin: release a=*
Pin-Priority: -10
NOSNAP
      sudo apt update
    else
      warn "Snap removal canceled."
    fi
  else
    warn "Snap removal skipped. Re-run with --remove-snap if you want to purge Snap."
  fi

  if [[ "$SKIP_FIREFOX" -eq 0 ]]; then
    log "Installing Firefox from Mozilla Team PPA"
    sudo add-apt-repository -y ppa:mozillateam/ppa
    echo 'APT::Key::Assert-Pubkey-Algo "";' | sudo tee /etc/apt/apt.conf.d/99weakkey-warning >/dev/null
    sudo apt update
    sudo apt install -y -t 'o=LP-PPA-mozillateam' firefox
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:$distro_codename";' | \
      sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox >/dev/null
    cat <<'FIREFOXPIN' | sudo tee /etc/apt/preferences.d/mozillateamppa >/dev/null
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 501
FIREFOXPIN
    sudo apt update
  else
    warn "Firefox PPA installation skipped."
  fi

  if [[ "$SKIP_FIREFOX_THEME" -eq 0 ]]; then
    log "Installing WhiteSur Firefox theme"
    cd "$HOME/Downloads"
    if [[ ! -d WhiteSur-firefox-theme ]]; then
      git clone https://github.com/vinceliuice/WhiteSur-firefox-theme.git
    fi
    cd WhiteSur-firefox-theme
    if [[ "$LXC_MODE" -eq 1 ]]; then
      sudo ./install.sh -m || warn "WhiteSur Firefox theme installation failed."
    else
      ./install.sh -m || sudo ./install.sh -m || warn "WhiteSur Firefox theme installation failed."
    fi
    cd "$HOME"
  else
    warn "Firefox theme installation skipped."
  fi

  log "Finished. Log out and log back in, or restart GNOME Shell/session, to apply all visual changes."
  warn "Weather widget still requires manual OpenWeatherMap city/API configuration: ~/.config/conky/Alfirk-MOD/scripts/weather-v2.0.sh"
}

main "$@"

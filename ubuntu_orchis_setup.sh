#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu 24.04 (GNOME 46) desktop theming — clean, upstream-based.
#
# Why this rewrite:
#   The old version dropped pre-built GNOME extensions from another distro and
#   imported a whole-tree `dconf load /`. On GNOME 46 those extensions were
#   version-incompatible (→ "Oh no, something went wrong" crash) and the dconf
#   dump carried machine-specific keys (e.g. a dock pinned to monitor
#   'Virtual-1', which broke whenever the display layout changed).
#
#   This version instead:
#     * builds the OFFICIAL Orchis theme from source (vinceliuice/Orchis-theme),
#       which targets the running GNOME version — so it does not break;
#     * styles the BUILT-IN Ubuntu dock via Orchis `--tweaks dock` (no extra,
#       incompatible dock extension);
#     * uses only the official User Themes extension (gnome-shell-extensions);
#     * brings the terminal look from this repo's bundle (fish + oh-my-posh +
#       a GNOME Terminal profile + Nerd fonts) — terminal styling is independent
#       of the shell theme and has no GNOME-version dependency;
#     * keeps Conky (optional) from the bundle;
#     * imports ONLY the terminal section of the bundled dconf dump, never the
#       whole tree.
#
# Run as a normal user (NOT sudo):
#   chmod +x ubuntu_orchis_setup.sh
#   ./ubuntu_orchis_setup.sh
#
# Optional flags:
#   --yes                Skip confirmation prompts where possible
#   --set-fish-shell     Change the login shell to fish
#   --skip-conky         Do not install/configure Conky
#   --skip-icons         Do not install the Tela icon theme
#   --skip-wallpaper     Do not install the bundled wallpapers
#   --remove-snap        Remove Snap packages and block snapd reinstall (opt-in)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_DIR="$SCRIPT_DIR/theme"

ASSUME_YES=0
SET_FISH_SHELL=0
SKIP_CONKY=0
SKIP_ICONS=0
SKIP_WALLPAPER=0
REMOVE_SNAP=0

for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    --set-fish-shell) SET_FISH_SHELL=1 ;;
    --skip-conky) SKIP_CONKY=1 ;;
    --skip-icons) SKIP_ICONS=1 ;;
    --skip-wallpaper) SKIP_WALLPAPER=1 ;;
    --remove-snap) REMOVE_SNAP=1 ;;
    -h|--help) sed -n '1,40p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\n\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err()  { printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; }

confirm() {
  local msg="$1"
  if [[ "$ASSUME_YES" -eq 1 ]]; then return 0; fi
  read -r -p "$msg [y/N]: " ans
  [[ "$ans" == "y" || "$ans" == "Y" || "$ans" == "yes" || "$ans" == "YES" ]]
}

apt_install() { sudo apt install -y "$@"; }

safe_unzip() {
  local zipfile="$1" dest="$2"
  if [[ -f "$zipfile" ]]; then
    mkdir -p "$dest"
    unzip -o "$zipfile" -d "$dest"
  else
    warn "Missing file, skipped unzip: $zipfile"
  fi
}

require_normal_user() {
  if [[ "${EUID}" -eq 0 ]]; then
    err "Do not run this script with sudo. Run it as a normal user; the script calls sudo only where required."
    exit 1
  fi
}

# gsettings that tolerates running without a live session (e.g. over SSH).
gset() { gsettings set "$@" 2>/dev/null || warn "gsettings set $* failed (no graphical session?)."; }

main() {
  require_normal_user

  if [[ ! -d "$THEME_DIR" ]]; then
    err "Theme asset directory not found: $THEME_DIR"
    err "Keep the 'theme' folder next to this script and re-run."
    exit 1
  fi

  log "Updating OS packages"
  sudo apt update
  sudo apt dist-upgrade -y

  log "Installing build dependencies (Orchis + tools)"
  # Orchis requires: gnome-themes-extra, gtk2-engines-murrine, sassc.
  # gnome-shell-extensions provides the official "User Themes" extension that
  # the GNOME Shell theme needs in order to apply.
  apt_install \
    git curl wget unzip ca-certificates \
    sassc gnome-themes-extra gtk2-engines-murrine \
    gnome-shell-extensions gnome-tweaks

  # ---------------------------------------------------------------------------
  # GTK + GNOME Shell theme: official Orchis, built for the running GNOME.
  # ---------------------------------------------------------------------------
  log "Building and installing the official Orchis theme"
  build_dir="$(mktemp -d)"
  if git clone --depth=1 https://github.com/vinceliuice/Orchis-theme.git "$build_dir/Orchis-theme"; then
    # -c dark         : dark color variant  -> theme name 'Orchis-Dark'
    # --tweaks dock   : fix style for the built-in ubuntu-dock (no extra extension)
    # -l              : link gtk-4.0 theme for libadwaita apps
    ( cd "$build_dir/Orchis-theme" && ./install.sh -c dark --tweaks dock -l ) \
      || warn "Orchis install.sh reported an error."
  else
    err "Failed to clone Orchis-theme. Check your internet connection."
  fi

  # ---------------------------------------------------------------------------
  # Icons: Tela (same author, the conventional companion to Orchis).
  # ---------------------------------------------------------------------------
  if [[ "$SKIP_ICONS" -eq 0 ]]; then
    log "Building and installing the Tela icon theme"
    if git clone --depth=1 https://github.com/vinceliuice/Tela-icon-theme.git "$build_dir/Tela-icon-theme"; then
      ( cd "$build_dir/Tela-icon-theme" && ./install.sh ) \
        || warn "Tela install.sh reported an error."
    else
      warn "Failed to clone Tela-icon-theme; skipping icons."
    fi
  else
    warn "Icon theme installation skipped (--skip-icons)."
  fi

  rm -rf "$build_dir"

  # ---------------------------------------------------------------------------
  # Fonts: needed for the terminal (FiraCode / Meslo Nerd Fonts) and the theme.
  # ---------------------------------------------------------------------------
  log "Installing bundled fonts (Nerd Fonts etc.)"
  safe_unzip "$THEME_DIR/fonts.zip" "$HOME/.local/share"   # -> ~/.local/share/fonts/
  fc-cache -f || true

  # ---------------------------------------------------------------------------
  # Wallpapers (optional).
  # ---------------------------------------------------------------------------
  if [[ "$SKIP_WALLPAPER" -eq 0 && -f "$THEME_DIR/wallpapers.zip" ]]; then
    log "Installing bundled wallpapers to /usr/share/backgrounds"
    sudo unzip -o "$THEME_DIR/wallpapers.zip" -d /usr/share/backgrounds/ >/dev/null || warn "Wallpaper extraction failed."
  fi

  # ---------------------------------------------------------------------------
  # Apply the themes (User Themes extension + gsettings).
  # ---------------------------------------------------------------------------
  log "Enabling User Themes and applying Orchis"
  gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com 2>/dev/null \
    || warn "Could not enable User Themes yet (it usually appears after the first log out / log in)."
  gset org.gnome.desktop.interface color-scheme 'prefer-dark'
  gset org.gnome.desktop.interface gtk-theme 'Orchis-Dark'
  gset org.gnome.shell.extensions.user-theme name 'Orchis-Dark'
  [[ "$SKIP_ICONS" -eq 0 ]] && gset org.gnome.desktop.interface icon-theme 'Tela-dark'

  # ---------------------------------------------------------------------------
  # Terminal: fish + oh-my-posh + GNOME Terminal profile + (fonts above).
  # This is the look from the original bundle, kept as-is.
  # ---------------------------------------------------------------------------
  log "Setting up the terminal (fish + Oh My Posh)"
  apt_install fish
  sudo wget -q https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 \
    -O /usr/local/bin/oh-my-posh && sudo chmod +x /usr/local/bin/oh-my-posh \
    || warn "oh-my-posh download failed; the prompt may be plain until you retry."
  safe_unzip "$THEME_DIR/fishomp-config.zip" "$HOME"
  [[ -d "$HOME/.poshthemes" ]] && chmod u+rw "$HOME"/.poshthemes/*.json 2>/dev/null || true

  log "Importing ONLY the GNOME Terminal profile from the bundled dconf dump"
  # Extract just the [org/gnome/terminal/...] sections — never the whole tree,
  # so machine-specific keys (monitor pins, keybindings, ...) are NOT imported.
  tmpd="$(mktemp -d)"
  if unzip -o "$THEME_DIR/ubuntu-desktop-settings.zip" -d "$tmpd" >/dev/null 2>&1; then
    conf="$(find "$tmpd" -name '*.conf' | head -1)"
    if [[ -f "$conf" ]]; then
      awk '/^\[/{p=($0 ~ /^\[org\/gnome\/terminal/)} p' "$conf" | dconf load / \
        || warn "Terminal dconf import failed."
    else
      warn "dconf .conf not found in ubuntu-desktop-settings.zip; terminal colors skipped."
    fi
  else
    warn "ubuntu-desktop-settings.zip missing; terminal colors skipped."
  fi
  rm -rf "$tmpd"

  # ---------------------------------------------------------------------------
  # Conky (optional). Works on 24.04; earlier "not showing" was just a session
  # that had not fully reloaded — a reboot brings it up.
  # ---------------------------------------------------------------------------
  if [[ "$SKIP_CONKY" -eq 0 ]]; then
    log "Installing and configuring Conky"
    # Conky uses Xft and does NOT fall back to another font for missing glyphs,
    # so the date config explicitly names 'Noto Sans CJK KR' for the Korean
    # tokens (%A/%B/%p) and the weather city. fonts-noto-cjk provides those
    # glyphs (Korean + Japanese kana + CJK Han), so they render instead of tofu.
    apt_install conky-all jq curl playerctl fonts-noto-cjk fonts-noto-cjk-extra
    safe_unzip "$THEME_DIR/conky-config.zip" "$HOME/.config"   # config + autostart
  else
    warn "Conky installation skipped (--skip-conky)."
  fi

  # ---------------------------------------------------------------------------
  # Login shell.
  # ---------------------------------------------------------------------------
  if [[ "$SET_FISH_SHELL" -eq 1 ]]; then
    log "Changing login shell to fish"
    chsh -s /usr/bin/fish "$USER" || warn "chsh failed; run 'chsh -s /usr/bin/fish' manually."
  else
    warn "Login shell unchanged. Run with --set-fish-shell (or 'chsh -s /usr/bin/fish') for the fish prompt."
  fi

  # ---------------------------------------------------------------------------
  # Snap removal (opt-in, unchanged behavior).
  # ---------------------------------------------------------------------------
  if [[ "$REMOVE_SNAP" -eq 1 ]]; then
    if confirm "This will remove Snap packages (including snap Firefox) and block snapd. Continue?"; then
      log "Removing Snap apps and service"
      [[ -d "$HOME/snap" ]] && cp -af "$HOME/snap" "$HOME/Downloads/" 2>/dev/null || true
      for snap_pkg in firefox snap-store gnome-42-2204 gtk-common-themes \
        snapd-desktop-integration firmware-updater core22 bare snapd; do
        sudo snap remove --purge "$snap_pkg" 2>/dev/null || true
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
  fi

  log "Done. Log out and back in (or reboot) to load User Themes, the shell theme, the dock style, fish, and Conky."
  warn "Conky weather still needs your OpenWeatherMap city/API key: ~/.config/conky/Alfirk-MOD/scripts/weather-v2.0.sh"
}

main "$@"

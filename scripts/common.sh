#!/usr/bin/env bash
# Shared helpers and variables for the modular setup scripts.
# Sourced by every scripts/*.sh module and by install.sh.
#
# Each module sources this file, so helpers and paths are defined once here.
# ASSUME_YES is read from the environment (install.sh exports it); defaults to 0.

# Guard against double-sourcing (written as an if-block so it is safe under set -e).
if [[ -n "${_COMMON_SH_LOADED:-}" ]]; then
  return 0
fi
_COMMON_SH_LOADED=1

# Directory of this file (= scripts/) and the project root above it.
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$COMMON_DIR"
ROOT_DIR="$(cd "$COMMON_DIR/.." && pwd)"
THEME_DIR="$ROOT_DIR/theme"

ASSUME_YES="${ASSUME_YES:-0}"

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
      warn "Package installation failed or not available: $pkg"
    fi
  done
}

require_normal_user() {
  if [[ "${EUID}" -eq 0 ]]; then
    err "Do not run this with sudo. Run as a normal user; sudo is called only where needed."
    exit 1
  fi
}

# Ensure ~/.local/bin exists and is on PATH (used for bat/fd friendly-name symlinks).
ensure_local_bin() {
  mkdir -p "$HOME/.local/bin"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *)
      if [[ -f "$HOME/.bashrc" ]] && ! grep -q '\.local/bin' "$HOME/.bashrc"; then
        printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
      fi
      export PATH="$HOME/.local/bin:$PATH"
      ;;
  esac
}

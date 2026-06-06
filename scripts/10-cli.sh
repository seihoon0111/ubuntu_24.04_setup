#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Terminal quality-of-life CLI tools.

log "Installing CLI tools"
apt_install_optional \
  ripgrep fd-find bat fzf jq tmux neovim btop htop tree ncdu \
  git-extras zoxide eza ffmpeg

ensure_local_bin
# On Ubuntu, bat installs as 'batcat' and fd-find as 'fdfind'. Add friendly names.
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

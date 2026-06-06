#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Python toolchain: system python, pipx (isolated CLI apps), pyenv (version manager).

log "Installing Python base (python3, pip, venv, pipx)"
apt_install python3 python3-pip python3-venv python3-full pipx
pipx ensurepath >/dev/null 2>&1 || true

log "Installing pyenv build dependencies"
apt_install_optional \
  make libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
  llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev

if [[ ! -d "$HOME/.pyenv" ]]; then
  log "Installing pyenv"
  curl -fsSL https://pyenv.run | bash || warn "pyenv installation failed; skipping."
else
  log "pyenv already present; skipping clone."
fi

# Register pyenv in bash and fish so it works in new shells.
if [[ -d "$HOME/.pyenv" ]]; then
  if [[ -f "$HOME/.bashrc" ]] && ! grep -q 'PYENV_ROOT' "$HOME/.bashrc"; then
    cat >> "$HOME/.bashrc" <<'PYENV_BASH'

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
PYENV_BASH
  fi
  fish_conf="$HOME/.config/fish/config.fish"
  if [[ -f "$fish_conf" ]] && ! grep -q 'PYENV_ROOT' "$fish_conf"; then
    cat >> "$fish_conf" <<'PYENV_FISH'

# pyenv
set -gx PYENV_ROOT $HOME/.pyenv
fish_add_path $PYENV_ROOT/bin
pyenv init - fish | source
PYENV_FISH
  fi
fi

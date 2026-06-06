#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Claude Code CLI via the official native installer.
# Self-contained binary in ~/.local/bin — no Node.js required, works in any shell.

log "Installing Claude Code (native installer)"
curl -fsSL https://claude.ai/install.sh | bash || warn "Claude Code installation failed."

# Ensure ~/.local/bin is on PATH for bash and the current process.
ensure_local_bin

# fish: ensure ~/.local/bin is on PATH so the 'claude' command is found.
if command -v fish >/dev/null 2>&1; then
  fish_conf="$HOME/.config/fish/config.fish"
  mkdir -p "$HOME/.config/fish"
  if [[ ! -f "$fish_conf" ]] || ! grep -q '.local/bin' "$fish_conf"; then
    echo 'fish_add_path $HOME/.local/bin' >> "$fish_conf"
  fi
fi

if command -v claude >/dev/null 2>&1; then
  log "Claude Code installed: $(claude --version 2>/dev/null || echo 'OK')"
else
  warn "Claude Code installed to ~/.local/bin. Restart your shell, then run: claude"
fi

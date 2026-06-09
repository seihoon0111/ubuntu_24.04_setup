#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Xpad — sticky-note / post-it memo app (HamoniKR fork: hamonikr/xpad).
#
# Built from source on purpose. The upstream README installs it via the
# HamoniKR apt repo (`repo.hamonikr.org`), but adding that whole third-party
# repo to an Ubuntu system can pull HamoniKR versions of unrelated packages.
# A source build keeps the change self-contained (just xpad in /usr/local).

if command -v xpad >/dev/null 2>&1; then
  log "xpad already installed; skipping."
else
  log "Installing xpad build dependencies"
  apt_install build-essential autotools-dev automake autoconf libtool \
    libgtk-3-dev libglib2.0-dev intltool gettext pkg-config git

  log "Cloning and building hamonikr/xpad"
  build_dir="$(mktemp -d)"
  if git clone --depth=1 https://github.com/hamonikr/xpad.git "$build_dir/xpad"; then
    if (
        cd "$build_dir/xpad"
        ./autogen.sh
        ./configure --prefix=/usr/local
        make -j"$(nproc)"
        sudo make install
      ); then
      sudo update-desktop-database 2>/dev/null || true
      log "xpad installed to /usr/local."
    else
      warn "xpad build/install failed. You can retry, or use the HamoniKR apt repo:"
      warn "  wget -qO- https://repo.hamonikr.org/hamonikr.apt | sudo -E bash - && sudo apt install -y xpad"
    fi
  else
    warn "Failed to clone hamonikr/xpad (network?)."
  fi
  rm -rf "$build_dir"
fi

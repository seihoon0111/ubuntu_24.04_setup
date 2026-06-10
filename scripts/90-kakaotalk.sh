#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# KakaoTalk on Ubuntu via Wine. There is NO official native Linux client, so the
# official Windows installer is run under Wine.
#
# Uses WineHQ *stable* (modern Wine) instead of the distro `wine` package — the
# old distro Wine triggers a "Microsoft Visual C++ Runtime" / compiler error on
# launch. WineHQ stable avoids that.
#
# SECURITY: download KakaoTalk_Setup.exe ONLY from the official site:
#   https://www.kakao.com/talk      (redirects to kakaocorp.com — official)
# Avoid look-alike phishing domains (pc-kakaocorp.com / win-kakaocorp.com / etc.).
# This module does NOT auto-download KakaoTalk; you place the file yourself.
#
# The installer is a GUI: this step pauses while its window is open, then resumes
# once you finish clicking through and the window closes.

WINEPREFIX_DIR="$HOME/.wine-kakao"
# Emoji-fix font (resolves broken/tofu emoji in KakaoTalk under Wine).
# Source: https://github.com/kmbzn/project-winemoji
WINEMOJI_URL="https://raw.githubusercontent.com/kmbzn/project-winemoji/main/Winemoji-NBG.ttf"

# --- WineHQ stable repository ---
log "Adding WineHQ repository and installing WineHQ stable"
sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key

codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
sudo wget -NP /etc/apt/sources.list.d/ \
  "https://dl.winehq.org/wine-builds/ubuntu/dists/${codename}/winehq-${codename}.sources"

sudo apt update
if ! apt_install --install-recommends winehq-stable; then
  warn "winehq-stable install failed; falling back to the distro 'wine' package."
  apt_install_optional wine
fi

# --- Korean fonts + winetricks (for troubleshooting) ---
apt_install_optional winetricks fonts-nanum fonts-noto-cjk

# --- Emoji fix: install Winemoji-NBG.ttf so KakaoTalk emoji don't render as boxes ---
mkdir -p "$HOME/.local/share/fonts"
if [[ ! -f "$HOME/.local/share/fonts/Winemoji-NBG.ttf" ]]; then
  log "Downloading Winemoji emoji font"
  wget -qO "$HOME/.local/share/fonts/Winemoji-NBG.ttf" "$WINEMOJI_URL" \
    || warn "Winemoji font download failed; emoji may show as boxes. Set the font manually later."
fi
fc-cache -f >/dev/null 2>&1 || true

# --- Locate the installer (any KakaoTalk*.exe in ~/Downloads) ---
INSTALLER=""
for f in "$HOME"/Downloads/KakaoTalk*.exe; do
  [[ -f "$f" ]] && { INSTALLER="$f"; break; }
done

if [[ -z "$INSTALLER" ]]; then
  warn "No KakaoTalk*.exe found in $HOME/Downloads"
  warn "Download it from the OFFICIAL site only:  https://www.kakao.com/talk"
  warn "Save it into ~/Downloads, then re-run:  bash scripts/90-kakaotalk.sh"
  warn "Wine + fonts are installed; finishing without launching the installer."
  exit 0
fi

log "Found installer: $INSTALLER"
log "Launching KakaoTalk installer under Wine (complete the on-screen steps)"
# Dedicated prefix + Korean locale so the installer/app renders Korean correctly.
WINEPREFIX="$WINEPREFIX_DIR" LANG=ko_KR.UTF-8 wine "$INSTALLER" \
  || warn "Wine reported an error while running the installer."

log "KakaoTalk install step finished."
log "Launch later:  WINEPREFIX=$WINEPREFIX_DIR wine '$WINEPREFIX_DIR/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe'"
log "EMOJI FIX: in KakaoTalk -> Settings -> font, choose 'Winemoji NBG'."
log "           (if not listed, pick another font, restart KakaoTalk, then search again)"
log "If Korean text is broken: WINEPREFIX=$WINEPREFIX_DIR winetricks -q cjkfonts"

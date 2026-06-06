#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# KakaoTalk on Ubuntu via Wine. There is NO official native Linux client, so the
# official Windows installer is run under Wine.
#
# SECURITY: download KakaoTalk_Setup.exe ONLY from the official site:
#   https://www.kakao.com/talk      (redirects to kakaocorp.com — official)
#   the installer is hosted on kakaocdn.net (Kakao's official CDN)
# Look-alike phishing domains to AVOID:
#   pc-kakaocorp.com / win-kakaocorp.com / apps-kakaocorp.com / kakaotalkdl.net / etc.
# This module does NOT auto-download; you place the file yourself (manual = safest).
#
# The installer is a GUI: this step pauses while its window is open, then the
# script resumes once you finish clicking through and the window closes.

WINEPREFIX_DIR="$HOME/.wine-kakao"

log "Installing Wine + Korean fonts (for running KakaoTalk)"
sudo dpkg --add-architecture i386
sudo apt update
apt_install_optional wine winetricks fonts-nanum fonts-noto-cjk

# Accept any KakaoTalk*.exe placed in ~/Downloads (filename/version may vary).
INSTALLER=""
for f in "$HOME"/Downloads/KakaoTalk*.exe; do
  [[ -f "$f" ]] && { INSTALLER="$f"; break; }
done

if [[ -z "$INSTALLER" ]]; then
  warn "No KakaoTalk*.exe found in $HOME/Downloads"
  warn "Download it from the OFFICIAL site only:  https://www.kakao.com/talk"
  warn "Save it into ~/Downloads, then re-run:  bash scripts/45-kakaotalk.sh"
  warn "Wine + Korean fonts are installed; finishing without launching the installer."
  exit 0
fi

log "Found installer: $INSTALLER"
log "Launching KakaoTalk installer under Wine (complete the on-screen steps)"
# Dedicated prefix + Korean locale so the installer/app renders Korean correctly.
WINEPREFIX="$WINEPREFIX_DIR" LANG=ko_KR.UTF-8 wine "$INSTALLER" \
  || warn "Wine reported an error while running the installer."

log "KakaoTalk install step finished."
log "Later, launch it with:  WINEPREFIX=$WINEPREFIX_DIR wine '$WINEPREFIX_DIR/drive_c/Program Files (x86)/Kakao/KakaoTalk/KakaoTalk.exe'"
log "If Korean text looks broken, run:  WINEPREFIX=$WINEPREFIX_DIR winetricks -q cjkfonts"

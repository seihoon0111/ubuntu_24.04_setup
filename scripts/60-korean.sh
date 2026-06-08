#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Korean input via ibus-hangul + language support.
# NOTE: run this AFTER the theme dconf load, since it sets the GNOME input
# sources, which a dconf import could otherwise overwrite.

log "Installing Korean language support, ibus-hangul, and Nanum fonts"
apt_install language-selector-common ibus ibus-hangul \
  fonts-nanum fonts-nanum-coding fonts-noto-cjk

# check-language-support prints the recommended package list for Korean.
ko_pkgs="$(check-language-support -l ko 2>/dev/null || true)"
if [[ -n "$ko_pkgs" ]]; then
  # shellcheck disable=SC2086
  apt_install_optional $ko_pkgs
fi

# Register ibus-hangul as an input source (US + Korean).
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('ibus', 'hangul')]" 2>/dev/null \
  || warn "Could not set GNOME input sources (no graphical session?). Add Korean input manually if needed."

# Make the right Alt key the 한/영 (Hangul) toggle.
# Use the XKB option via gsettings — this works on Wayland (the old trick of
# editing /usr/share/X11/xkb/symbols/altwin does NOT work reliably on Wayland).
gsettings set org.gnome.desktop.input-sources xkb-options "['korean:ralt_hangul']" 2>/dev/null \
  || warn "Could not set xkb-options for the 한/영 key (no graphical session?)."

# Korean font policy: do NOT change the GNOME UI font — keep whatever the theme
# set for Latin/English text. Instead, make only KOREAN text fall back to Nanum
# (the same family KakaoTalk uses) via fontconfig. Latin text is unaffected
# because these rules match Korean-language runs only.
mkdir -p "$HOME/.config/fontconfig/conf.d"
cat > "$HOME/.config/fontconfig/conf.d/99-korean-nanum.conf" <<'FONTCONF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="pattern">
    <test name="lang" compare="contains"><string>ko</string></test>
    <test name="family"><string>sans-serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>NanumGothic</string></edit>
  </match>
  <match target="pattern">
    <test name="lang" compare="contains"><string>ko</string></test>
    <test name="family"><string>serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>NanumMyeongjo</string></edit>
  </match>
  <match target="pattern">
    <test name="lang" compare="contains"><string>ko</string></test>
    <test name="family"><string>monospace</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>NanumGothicCoding</string></edit>
  </match>
</fontconfig>
FONTCONF
fc-cache -f >/dev/null 2>&1 || true

ibus restart 2>/dev/null || true

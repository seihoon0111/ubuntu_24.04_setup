#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Korean input via ibus-hangul + language support.
# NOTE: run this AFTER the theme dconf load, since it sets the GNOME input
# sources, which a dconf import could otherwise overwrite.

log "Installing Korean language support, ibus-hangul, and CJK fonts"
# fonts-noto-cjk(-extra) bundles Korean + Japanese + Chinese glyphs, so it also
# covers Japanese kanji/kana that show up in media titles, subtitles, etc.
apt_install language-selector-common ibus ibus-hangul \
  fonts-nanum fonts-nanum-coding fonts-noto-cjk fonts-noto-cjk-extra

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

# Font policy: do NOT change the GNOME UI font — keep whatever the theme set for
# Latin/English text. Instead, steer CJK runs to CJK-capable fonts via fontconfig:
#   - Korean text  -> Nanum (the family KakaoTalk uses), then Noto CJK KR
#   - Japanese text -> Noto CJK JP (so kanji use Japanese glyph variants, not the
#                      Korean Han-unification forms)
#   - Any other CJK (often untagged, e.g. media titles/subtitles/filenames) ->
#     Noto CJK appended as a weak fallback to the generic families, so glyphs that
#     the Latin UI font lacks never render as tofu (□).
# Latin text is unaffected: the prepend rules are language-gated, and the weak
# append only kicks in for code points the primary font has no glyph for.
mkdir -p "$HOME/.config/fontconfig/conf.d"
# Remove the older Korean-only file from previous installs (now superseded).
rm -f "$HOME/.config/fontconfig/conf.d/99-korean-nanum.conf"
cat > "$HOME/.config/fontconfig/conf.d/99-cjk-fallback.conf" <<'FONTCONF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <!-- Korean-tagged text: Nanum first, then Noto CJK KR. -->
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

  <!-- Japanese-tagged text: Noto CJK JP so kanji get the Japanese glyph forms. -->
  <match target="pattern">
    <test name="lang" compare="contains"><string>ja</string></test>
    <test name="family"><string>sans-serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Sans CJK JP</string></edit>
  </match>
  <match target="pattern">
    <test name="lang" compare="contains"><string>ja</string></test>
    <test name="family"><string>serif</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Serif CJK JP</string></edit>
  </match>
  <match target="pattern">
    <test name="lang" compare="contains"><string>ja</string></test>
    <test name="family"><string>monospace</string></test>
    <edit name="family" mode="prepend" binding="strong"><string>Noto Sans Mono CJK JP</string></edit>
  </match>

  <!-- Universal CJK fallback for untagged text: appended (weak) so it only fills
       glyphs the primary font lacks. KR first (UI default language), then JP. -->
  <match target="pattern">
    <test name="family"><string>sans-serif</string></test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Sans CJK KR</string>
      <string>Noto Sans CJK JP</string>
    </edit>
  </match>
  <match target="pattern">
    <test name="family"><string>serif</string></test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Serif CJK KR</string>
      <string>Noto Serif CJK JP</string>
    </edit>
  </match>
  <match target="pattern">
    <test name="family"><string>monospace</string></test>
    <edit name="family" mode="append" binding="weak">
      <string>Noto Sans Mono CJK KR</string>
      <string>Noto Sans Mono CJK JP</string>
    </edit>
  </match>
</fontconfig>
FONTCONF
fc-cache -f >/dev/null 2>&1 || true

ibus restart 2>/dev/null || true

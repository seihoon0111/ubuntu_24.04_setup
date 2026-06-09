#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu 24.04 setup orchestrator.
# Runs the modular scripts in scripts/ in order, then the desktop theme script.
#
# Run as a normal user, NOT with sudo:
#   chmod +x install.sh
#   ./install.sh
#
# Each step lives in its own file under scripts/ and can be run on its own, e.g.:
#   bash scripts/30-docker.sh
#
# Options:
#   --yes              Skip confirmation prompts where possible
#   --skip-locale      Skip locale setup         (scripts/05-locale.sh)
#   --skip-cli         Skip CLI tools            (scripts/10-cli.sh)
#   --skip-python      Skip Python toolchain     (scripts/20-python.sh)
#   --skip-docker      Skip Docker               (scripts/30-docker.sh)
#   --skip-dev         Skip both Python + Docker
#   --skip-gui         Skip GUI apps             (scripts/40-gui.sh)
#   --skip-nvidia      Skip NVIDIA drivers       (scripts/50-nvidia.sh)
#   --skip-korean      Skip Korean input         (scripts/60-korean.sh)
#   --skip-claude      Skip Claude Code          (scripts/70-claude-code.sh)
#   --skip-copyq       Skip CopyQ clipboard mgr  (scripts/80-copyq.sh)
#   --skip-theme       Skip the desktop theme script
#
# Theme behavior (both ON by default — pass these to turn OFF):
#   --no-remove-snap   Do NOT remove Snap / snapd
#   --no-fish          Do NOT change the login shell to fish
#   --                 Pass any further raw flags to the theme script
#   -h, --help         Show this help

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/common.sh"

SKIP_LOCALE=0
SKIP_CLI=0
SKIP_PYTHON=0
SKIP_DOCKER=0
SKIP_SAMBA=0
SKIP_SSH=0
SKIP_GUI=0
SKIP_KAKAO=0
SKIP_NVIDIA=0
SKIP_KOREAN=0
SKIP_CLAUDE=0
SKIP_COPYQ=0
SKIP_THEME=0
# Theme extras default ON (snap removal + fish as login shell).
THEME_REMOVE_SNAP=1
THEME_SET_FISH=1
THEME_ARGS=()

usage() {
  cat <<'USAGE'
Ubuntu 24.04 setup orchestrator — runs scripts/ modules, then the theme script.
Run as a normal user (NOT sudo):  ./install.sh

By default you are asked before EACH step ("Run '<module>'? [Y/n]", Enter = yes),
so you can pick what to run. Use --yes to run everything without prompting.

Options:
  --yes              Run all steps without asking (no per-step prompt)
  --skip-locale      Skip locale setup         (scripts/05-locale.sh)
  --skip-cli         Skip CLI tools            (scripts/10-cli.sh)
  --skip-python      Skip Python toolchain     (scripts/20-python.sh)
  --skip-docker      Skip Docker               (scripts/30-docker.sh)
  --skip-dev         Skip both Python + Docker
  --skip-samba       Skip Samba file sharing   (scripts/35-samba.sh)
  --skip-ssh         Skip SSH server           (scripts/36-ssh.sh)
  --skip-gui         Skip GUI apps             (scripts/40-gui.sh)
  --skip-kakao       Skip KakaoTalk (Wine)     (scripts/90-kakaotalk.sh)
  --skip-nvidia      Skip NVIDIA drivers       (scripts/50-nvidia.sh)
  --skip-korean      Skip Korean input         (scripts/60-korean.sh)
  --skip-claude      Skip Claude Code          (scripts/70-claude-code.sh)
  --skip-copyq       Skip CopyQ clipboard mgr  (scripts/80-copyq.sh)
  --skip-theme       Skip the desktop theme script

Theme behavior (both ON by default — pass these to turn OFF):
  --no-remove-snap   Do NOT remove Snap / snapd
  --no-fish          Do NOT change the login shell to fish
  --                 Pass any further raw flags to the theme script
  -h, --help         Show this help
USAGE
}

passthrough=0
for arg in "$@"; do
  if [[ "$passthrough" -eq 1 ]]; then
    THEME_ARGS+=("$arg")
    continue
  fi
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    --skip-locale) SKIP_LOCALE=1 ;;
    --skip-cli) SKIP_CLI=1 ;;
    --skip-python) SKIP_PYTHON=1 ;;
    --skip-docker) SKIP_DOCKER=1 ;;
    --skip-dev) SKIP_PYTHON=1; SKIP_DOCKER=1 ;;
    --skip-samba) SKIP_SAMBA=1 ;;
    --skip-ssh) SKIP_SSH=1 ;;
    --skip-gui) SKIP_GUI=1 ;;
    --skip-kakao) SKIP_KAKAO=1 ;;
    --skip-nvidia) SKIP_NVIDIA=1 ;;
    --skip-korean) SKIP_KOREAN=1 ;;
    --skip-claude) SKIP_CLAUDE=1 ;;
    --skip-copyq) SKIP_COPYQ=1 ;;
    --skip-theme) SKIP_THEME=1 ;;
    --no-remove-snap) THEME_REMOVE_SNAP=0 ;;
    --no-fish) THEME_SET_FISH=0 ;;
    --) passthrough=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Make ASSUME_YES visible to the child module scripts.
export ASSUME_YES

# Ask before running a step (default Yes). With --yes, run everything silently.
module_confirm() {
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  local ans
  read -r -p "Run '$1'? [Y/n]: " ans
  case "$ans" in
    ""|y|Y|yes|YES|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

run_module() {
  local name="$1"
  local file="$SCRIPTS_DIR/$name"
  if [[ ! -f "$file" ]]; then
    warn "Module not found, skipped: $file"
    return 0
  fi
  if ! module_confirm "$name"; then
    warn "Skipped by user: $name"
    return 0
  fi
  log ">>> Module: $name"
  bash "$file"
}

run_theme() {
  local theme_script="$ROOT_DIR/ubuntu_orchis_setup.sh"
  if [[ ! -f "$theme_script" ]]; then
    warn "Theme script not found, skipped: $theme_script"
    return 0
  fi
  if ! module_confirm "ubuntu_orchis_setup.sh (desktop theme)"; then
    warn "Skipped by user: theme"
    return 0
  fi
  local args=()
  [[ "$ASSUME_YES" -eq 1 ]]        && args+=(--yes)
  [[ "$THEME_REMOVE_SNAP" -eq 1 ]] && args+=(--remove-snap)
  [[ "$THEME_SET_FISH" -eq 1 ]]    && args+=(--set-fish-shell)
  args+=("${THEME_ARGS[@]}")
  log ">>> Desktop theme: ubuntu_orchis_setup.sh ${args[*]}"
  chmod +x "$theme_script" 2>/dev/null || true
  bash "$theme_script" "${args[@]}"
}

setup_git_identity() {
  [[ "$ASSUME_YES" -eq 1 ]] && return 0
  if git config --global user.email >/dev/null 2>&1; then
    return 0
  fi
  if confirm "Configure global git user.name / user.email now?"; then
    read -r -p "  git user.name : " gname
    read -r -p "  git user.email: " gemail
    [[ -n "$gname" ]]  && git config --global user.name  "$gname"
    [[ -n "$gemail" ]] && git config --global user.email "$gemail"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
  fi
}

main() {
  require_normal_user

  run_module 00-base.sh

  if [[ "$SKIP_LOCALE" -eq 0 ]]; then run_module 05-locale.sh; else warn "Locale setup skipped."; fi
  if [[ "$SKIP_CLI" -eq 0 ]];    then run_module 10-cli.sh;    else warn "CLI tools skipped.";    fi
  if [[ "$SKIP_PYTHON" -eq 0 ]]; then run_module 20-python.sh; else warn "Python skipped.";       fi
  if [[ "$SKIP_DOCKER" -eq 0 ]]; then run_module 30-docker.sh; else warn "Docker skipped.";       fi
  if [[ "$SKIP_SAMBA" -eq 0 ]];  then run_module 35-samba.sh;  else warn "Samba skipped.";         fi
  if [[ "$SKIP_SSH" -eq 0 ]];    then run_module 36-ssh.sh;    else warn "SSH server skipped.";    fi
  if [[ "$SKIP_GUI" -eq 0 ]];    then run_module 40-gui.sh;    else warn "GUI apps skipped.";     fi
  if [[ "$SKIP_NVIDIA" -eq 0 ]]; then run_module 50-nvidia.sh; else warn "NVIDIA skipped.";       fi
  if [[ "$SKIP_CLAUDE" -eq 0 ]]; then run_module 70-claude-code.sh; else warn "Claude Code skipped."; fi

  setup_git_identity

  # Korean input runs after the theme by convention. (The theme now imports
  # only the GNOME Terminal dconf section, so it no longer overwrites the
  # input-source / keybinding settings — the order is kept for safety.)
  if [[ "$SKIP_THEME" -eq 0 ]]; then run_theme; else warn "Theme skipped."; fi

  if [[ "$SKIP_KOREAN" -eq 0 ]]; then run_module 60-korean.sh; else warn "Korean input skipped."; fi
  if [[ "$SKIP_COPYQ" -eq 0 ]];  then run_module 80-copyq.sh;  else warn "CopyQ skipped.";        fi

  # KakaoTalk runs LAST: it launches a GUI installer that needs clicking, so do
  # all the hands-off steps first, then this one interactive step at the end.
  if [[ "$SKIP_KAKAO" -eq 0 ]];  then run_module 90-kakaotalk.sh; else warn "KakaoTalk skipped.";  fi

  log "All done. Log out and back in (or reboot) to apply group/shell/driver/visual changes."
}

main "$@"

#!/bin/bash

echo "Make Hex the dictation backend and run it as a background service"

# ~/.config/omarchy/defaults/dictation is Omarchy state written by its Setup
# menu, not a stowed file, so the choice is set here. omarchy-dictation then
# dispatches to omarchy-dictation-hex (.local/bin). hex.service keeps Hex
# listening with its window closed, so Alt+Space works from login.

set -uo pipefail

if ! command -v hex &>/dev/null; then
  echo "  hex not installed — run: sudo pacman -S hex-bin"
  exit 0
fi

config=${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/defaults/dictation
mkdir -p "${config%/*}"
[[ $(cat "$config" 2>/dev/null) == hex ]] || echo hex >"$config"

systemctl --user enable --now hex.service >/dev/null 2>&1 ||
  echo "  could not enable hex.service — run: systemctl --user enable --now hex.service"

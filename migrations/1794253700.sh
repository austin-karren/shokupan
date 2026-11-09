#!/bin/bash

echo "Load the tracked Hex dictation vocabulary"

# Hex stores its vocabulary in ~/.local/share/hex/settings.json with machine
# state, so the list is tracked on its own in .config/hex/vocabulary.json and
# applied through Hex's CLI. Rerunnable: `hex-vocabulary apply` only adds.
# After adding terms on any machine: `hex-vocabulary export`, then commit.

set -uo pipefail

if ! command -v hex &>/dev/null; then
  echo "  hex not installed — run: sudo pacman -S hex-bin, then hex-vocabulary apply"
  exit 0
fi

"$HOME/.local/bin/hex-vocabulary" apply ||
  echo "  could not apply — start Hex and run: hex-vocabulary apply"

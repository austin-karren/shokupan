#!/bin/bash

echo "Install the fw-fanctrl fan curves (performance / quiet / max)"

# fw-fanctrl reads /etc/fw-fanctrl/config.json, which is root-owned and outside
# $HOME, so stow cannot place it. The canonical copy is packages/fw-fanctrl.json;
# this migration copies it in and reloads the daemon when it changes.
#
# `performance` is the default: the middle curve, quieter than `max` but
# reacting sooner than `quiet`. Its 15s moving average is deliberate — the 8s it
# had before let a single test run push the fan into the audible 30%+ band.

set -uo pipefail

src=$HOME/shokupan/packages/fw-fanctrl.json
dst=/etc/fw-fanctrl/config.json

if ! command -v fw-fanctrl &>/dev/null; then
  echo "  fw-fanctrl not installed — nothing to do"
  exit 0
fi

if [[ -f $dst ]] && cmp -s "$src" "$dst"; then
  exit 0
fi

if sudo -n true 2>/dev/null; then
  sudo -n install -m 0644 -o root -g root "$src" "$dst" &&
    sudo -n fw-fanctrl reload >/dev/null &&
    echo "  installed and reloaded"
else
  echo "  needs root — run: sudo install -m 0644 $src $dst && sudo fw-fanctrl reload"
fi

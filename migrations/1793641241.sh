#!/bin/bash

echo "Disable USB autosuspend for the MT7925 Bluetooth adapter"

# btusb's options live in /etc/modprobe.d/, root-owned and outside $HOME, so
# stow cannot place them. The canonical copy is packages/btusb-no-autosuspend.conf.
# Revert (once a better adapter replaces the MT7925): delete that file and this
# migration, then sudo rm /etc/modprobe.d/btusb-no-autosuspend.conf and reboot.
# See ADR-0045's 2026-11-02 amendment.

set -uo pipefail

src=$HOME/shokupan/packages/btusb-no-autosuspend.conf
dst=/etc/modprobe.d/btusb-no-autosuspend.conf

if [[ -f $dst ]] && cmp -s "$src" "$dst"; then
  exit 0
fi

if sudo -n true 2>/dev/null; then
  sudo -n install -m 0644 -o root -g root "$src" "$dst" &&
    echo "  installed — takes effect on next boot"
else
  echo "  needs root — run: sudo install -m 0644 $src $dst"
fi

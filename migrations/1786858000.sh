#!/bin/bash

echo "Strip window buttons from GNOME CSD headers — the calendar popup is a dialog"

# The GNOME Calendar popup behaves as a dialog (shokupan-plugins ADR-0006):
# summoned, dismissed by click-outside / the clock / workspace switch — never
# closed by its own X, which quits the warm instance and makes the next open a
# cold multi-second start. GTK offers no per-app switch; button-layout is GLOBAL
# for GNOME CSD apps, so gnome Settings loses its buttons too. Deliberate and
# user-approved (2026-08-15): windows close via SUPER+W and the ladder
# (ADR-0020). One key to revert:
#   gsettings reset org.gnome.desktop.wm.preferences button-layout

set -uo pipefail

if ! command -v gsettings &>/dev/null; then
  echo "  gsettings not available — nothing to do"
  exit 0
fi

if ! gsettings list-schemas 2>/dev/null | grep -qx org.gnome.desktop.wm.preferences; then
  echo "  org.gnome.desktop.wm.preferences schema not installed — nothing to do"
  exit 0
fi

if [[ $(gsettings get org.gnome.desktop.wm.preferences button-layout) != "':'" ]]; then
  gsettings set org.gnome.desktop.wm.preferences button-layout ':'
fi

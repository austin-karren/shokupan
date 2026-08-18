#!/bin/bash

echo "Point GTK's cursor-theme at the Breeze cursor"

# The third of the three mechanisms that have to agree on the pointer (see
# .icons/default/index.theme for the other two and why each exists). GTK reads
# org.gnome.desktop.interface cursor-theme in preference to the icon-path
# default, so a stowed file cannot cover this one — dconf is not a file we can
# track, hence a migration.
#
# The value was 'default' when this was written, which resolves through
# /usr/share/icons/default/index.theme to Adwaita. Nothing in Omarchy writes
# cursor-theme (verified by grep across the whole package tree), so how it came
# to be reset is unproven — a dconf reset, or it was only ever set by a KDE-side
# tool that no longer runs in this session.

set -uo pipefail

if ! command -v gsettings &>/dev/null; then
  echo "  gsettings not available — nothing to do"
  exit 0
fi

if ! gsettings list-schemas 2>/dev/null | grep -qx org.gnome.desktop.interface; then
  echo "  org.gnome.desktop.interface schema not installed — nothing to do"
  exit 0
fi

# Only claim the setting when the theme is actually installed: pointing GTK at a
# missing theme is worse than leaving it on Adwaita, because the fallback is
# per-app and inconsistent.
if [[ ! -d /usr/share/icons/breeze_cursors ]]; then
  echo "  breeze_cursors not installed — leaving cursor-theme alone"
  exit 0
fi

if [[ $(gsettings get org.gnome.desktop.interface cursor-theme) != "'breeze_cursors'" ]]; then
  gsettings set org.gnome.desktop.interface cursor-theme 'breeze_cursors'
fi

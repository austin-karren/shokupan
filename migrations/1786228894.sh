#!/bin/bash

echo "Re-apply the Helium per-profile theme colours"

# Helium is a Chromium fork, and Chromium stores per-profile theming inside each
# profile's Preferences file — a large, volatile blob that also carries identifying
# data. Stowing it is not an option, hence a migration.
#
# Worth knowing why this is not done the Omarchy way: omarchy-theme-set-browser
# writes a BrowserThemeColor managed policy, but only to /etc/chromium,
# /etc/opt/chrome, /etc/opt/edge and /etc/brave. Helium is not in that list and has
# no policy directory here, so its theming was applied by hand, per profile, and a
# rebuilt machine would come up with Helium's stock colours.
#
# Colours are the ones in use, recorded as signed 32-bit ints exactly as Chromium
# stores them. Profile directory names are Chromium's own ("Default", "Profile N"),
# not the display names.
#
# Refuses to run while Helium is running: Chromium rewrites Preferences from memory
# on exit, so a patch applied underneath it is discarded.

set -uo pipefail

ROOT="${LOAF_HOME:-$HOME}/.config/net.imput.helium"

if [[ ! -d $ROOT ]]; then
  echo "  Helium profile directory not found — nothing to do"
  exit 0
fi

if pgrep -f 'helium' >/dev/null 2>&1; then
  echo "  Helium is running — quit it and re-run 'loaf heal'"
  exit 1
fi

python3 - "$ROOT" <<'PY'
import json, os, shutil, sys

root = sys.argv[1]
# profile directory -> user_color2
wanted = {
    "Default": -7558172,
    "Profile 1": -14244198,
}

changed = []
for profile, colour in wanted.items():
    path = os.path.join(root, profile, "Preferences")
    if not os.path.exists(path):
        print(f"  {profile}: no Preferences — skipped")
        continue
    with open(path) as f:
        data = json.load(f)

    theme = data.setdefault("browser", {}).setdefault("theme", {})
    ext = data.setdefault("extensions", {}).setdefault("theme", {})
    if theme.get("user_color2") == colour and ext.get("id") == "user_color_theme_id":
        continue

    shutil.copy2(path, path + ".pre-loaf")
    theme["user_color2"] = colour
    ext["id"] = "user_color_theme_id"
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    changed.append(profile)

if changed:
    print("  re-applied to: " + ", ".join(changed) + " (backups at Preferences.pre-loaf)")
PY

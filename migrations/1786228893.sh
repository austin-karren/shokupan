#!/bin/bash

echo "Hide Slack's Electron menu bar"

# Slack keeps this in its own Electron state blob, not in a config file we could
# stow: ~/.config/Slack/storage/root-state.json, which also holds session data.
# That is why it is patched here rather than tracked -- committing the file to a
# public repo would publish credentials.
#
# The key is settings.userChoices.autoHideMenuBar. Slack's own default lives beside
# it at settings.slackDefaults.autoHideMenuBar and is false; userChoices is the
# override layer, so writing there is the same thing the UI toggle does.
#
# Refuses to run while Slack is running: the app holds this state in memory and
# rewrites the file on exit, so a patch applied underneath a live process is
# silently discarded. Better to skip and stay pending than to appear to succeed.

set -uo pipefail

STATE="${LOAF_HOME:-$HOME}/.config/Slack/storage/root-state.json"

if [[ ! -f $STATE ]]; then
  echo "  Slack state not found — nothing to do"
  exit 0
fi

if pgrep -x slack >/dev/null 2>&1; then
  echo "  Slack is running — quit it and re-run 'loaf heal'"
  exit 1
fi

python3 - "$STATE" <<'PY'
import json, shutil, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

choices = data.setdefault("settings", {}).setdefault("userChoices", {})
if choices.get("autoHideMenuBar") is True:
    sys.exit(0)

# Back up beside the original before touching a file that also holds session state.
shutil.copy2(path, path + ".pre-loaf")
choices["autoHideMenuBar"] = True
with open(path, "w") as f:
    json.dump(data, f, separators=(",", ":"))
print("  autoHideMenuBar = true (backup at root-state.json.pre-loaf)")
PY

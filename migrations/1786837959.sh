#!/bin/bash

echo "Disable GNOME Calendar's weather feature (use-after-free crash trigger)"

# GNOME Calendar 50.0's weather service has a use-after-free: when GeoClue
# idles out ~10s after launch, the async Stop reply lands in
# on_gclue_client_stopped_cb (src/weather/gcal-weather-service.c:810), which
# unrefs an already-freed GClueSimple — SIGSEGV. Three cores on 2026-08-15,
# symbolized via CachyOS debuginfod; upstream issue drafted at
# docs/upstream/gnome-calendar-weather-use-after-free.md.
#
# Nothing is lost by turning it off: the bar and the clock popup already show
# weather, and the setting is reversible in Calendar's own menu (which is also
# why this is a migration, not a stowed dconf file — the app owns the key).
#
# weather-settings is type (bbsmv): (show-weather, auto-location,
# location-name, location). Only the first bool goes false; the rest stay at
# their defaults so re-enabling in the app behaves as before.

set -uo pipefail

if ! command -v gsettings &>/dev/null; then
  echo "  gsettings not available — nothing to do"
  exit 0
fi

if ! gsettings list-schemas 2>/dev/null | grep -qx org.gnome.calendar; then
  echo "  org.gnome.calendar schema not installed — nothing to do"
  exit 0
fi

current=$(gsettings get org.gnome.calendar weather-settings)

# Idempotence: the first tuple element is show-weather; already-off means done.
if [[ $current == "(false,"* ]]; then
  echo "  weather already off ($current) — nothing to do"
  exit 0
fi

gsettings set org.gnome.calendar weather-settings "(false, true, '', @mv nothing)"
echo "  weather-settings: $current -> (false, true, '', @mv nothing)"

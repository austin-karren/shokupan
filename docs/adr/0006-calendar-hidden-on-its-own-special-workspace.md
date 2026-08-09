---
status: accepted
---

# The calendar popup gets its own special workspace, not the scratchpad

> **Mechanism deleted 2026-08-09.** The `custom/calendar` module died with
> `config.jsonc`. `calendar-toggle` and the workspace rule still exist, but
> ADR-0033 expects both to go: quattro's clock popup ships a month grid, which is
> what this ADR was reaching for. Old file: tag `omarchy-v3.8.4-prequattro`.

`calendar-toggle` shows and hides GNOME Calendar on a Hyprland special workspace
named `calendar`, deliberately not the `scratchpad` one that `SUPER+S` toggles.
Sharing the scratchpad would mean `SUPER+S` also summoned the calendar, and that
stashing a window with `SUPER+ALT+S` dumped it next to the calendar.

## Consequences

Omarchy's `looknfeel.conf` sets `hide_special_on_workspace_change = true`, so
changing workspaces dismisses the popup by itself. That is the wanted behaviour
and the reason this needs no focus-tracking logic of its own.

Companion pieces that must move together: the window rules in
`~/.config/hypr/windows.conf` and the `custom/calendar` module in
`~/.config/waybar/config.jsonc`.

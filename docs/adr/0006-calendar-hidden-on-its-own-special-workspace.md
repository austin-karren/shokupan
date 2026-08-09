---
status: accepted
---

# The calendar popup gets its own special workspace, not the scratchpad

> **Bar entry point deleted 2026-08-09; the decision stands.** The `custom/calendar`
> module died with `config.jsonc`. `calendar-toggle` and the workspace rule are
> unchanged and still work. Old file: tag `omarchy-v3.8.4-prequattro`.
>
> **Correction.** ADR-0033 expected this ADR to retire on the grounds that
> "quattro's clock popup ships a month grid". That was not checked and is not true:
> `shell/plugins/bar/widgets/Clock.qml` is 66 lines — a bar label that toggles
> between two date formats on click. It has no popup, there is no clock entry in
> `shell/plugins/panels/`, and nothing in the shell renders a month grid. Nothing
> native replaces this.
>
> **And it would not replace it even if it existed.** The reason this rice runs
> GNOME Calendar is the online accounts: the calendar being consulted is a synced
> one with meetings in it, and a month grid drawn from the system clock cannot show
> those. A future native calendar in the bar retires this ADR only if it reaches
> the same accounts — that is the test to apply, not whether a grid appeared.
>
> Reachable at `SUPER+SHIFT+C` (`bindings.conf`, pending the Lua port) and from the
> Omarchy Menu's **Calendar** row, added with the menu port to cover the gap the
> bar module left.

`calendar-toggle` shows and hides GNOME Calendar on a Hyprland special workspace
named `calendar`, deliberately not the `scratchpad` one that `SUPER+S` toggles.
Sharing the scratchpad would mean `SUPER+S` also summoned the calendar, and that
stashing a window with `SUPER+ALT+S` dumped it next to the calendar.

## Consequences

Omarchy's `looknfeel.conf` sets `hide_special_on_workspace_change = true`, so
changing workspaces dismisses the popup by itself. That is the wanted behaviour
and the reason this needs no focus-tracking logic of its own.

Companion pieces that must move together: the window rules in
`~/.config/hypr/windows.conf`, the `SUPER+SHIFT+C` binding, and the `Calendar` row
in `~/.config/omarchy/extensions/omarchy-menu.jsonc`. The bar entry point is back
as of later on 2026-08-09: `.config/omarchy/bar/modules/calendar.qml`, a
**static** module immediately left of the clock — the slot quattro's own
bar-config button used to reveal into (that button is suppressed via
`centerAnchor: ""` and relocated to the left section). Static deliberately,
unlike the rice's other custom centre modules: the calendar is the left half of
ADR-0029's bracket around the date, and a bracket that is usually missing is not
a bracket. Same glyph and both click actions as the old Waybar module, verified
end to end: show, hide, and the window kept warm on `special:calendar` between
toggles.

Two quattro facts this path depends on, both measured: `hyprctl dispatch` under
`configProvider: lua` takes `hl.dsp.*` calls — the classic
`movetoworkspacesilent` form fails with a Lua parse error — and until the
Hyprland port restores the window rule, a cold launch lands on the current
workspace and `calendar-toggle`'s recapture branch collects it on the next
click.

`hide_special_on_workspace_change` is still `true`, now at
`/usr/share/omarchy/default/hypr/looknfeel.lua:120` rather than in the old
`looknfeel.conf` — so it remains upstream's default and not something this rice
sets. Confirmed by reading that file; `hyprctl getoption` does not expose the
option, so it has not been confirmed against the running compositor.

---
status: proposed
---

# Extend second-click dismissal to the audio and CPU modules

> **Mechanism deleted 2026-08-09.** As ADR-0004: the `on-click` entries went with
> `config.jsonc`, and the audio side lost its target too — `wiremix` is
> uninstalled (ADR-0030). Old file: tag `omarchy-v3.8.4-prequattro`.

> **Half settled.** ADR-0029 deleted the `cpu` module outright and moved btop to
> `SUPER CTRL + T` with the `window-toggle` treatment described below, so that row
> of the table is resolved — by removing its subject rather than by converting it.
> Only `pulseaudio` remains open, and the questions below now apply to it alone.

ADR-0004 gave Second-click dismissal to `custom/omarchy`, `bluetooth`, `network`
and `custom/calendar`. Two right-side modules were never converted and still call
their launcher raw, so clicking them a second time does nothing:

| Module | Current `on-click` | Opens | Status |
|---|---|---|---|
| `pulseaudio` | `omarchy-launch-audio` | wiremix | open |
| `cpu` | `omarchy-launch-or-focus-tui btop` | btop | module deleted, ADR-0029 |

Both are the same shape as `bluetooth` and `network` — a TUI in a floating
toplevel, cheap to restart, showing live state that should not go stale in a
hidden window — so both want `window-toggle`, the closing variant, not
`calendar-toggle`'s hiding variant.

## To settle at grill time

- The window class. `window-toggle` matches on `.class` from `hyprctl clients`,
  and the existing entries use Omarchy's own reverse-DNS classes
  (`org.omarchy.bluetui`, `org.omarchy.impala`). wiremix's class needs reading off
  a live window, not guessing. (btop's turned out to be `org.omarchy.btop`, set by
  `omarchy-launch-tui` via `--app-id`; wiremix is launched differently and cannot
  be assumed to follow.)
- ~~Whether `cpu`'s `on-click-right = alacritty` stays.~~ Moot — the module is gone.
- `battery` is deliberately excluded: its `on-click` is `omarchy-menu power`, a
  Walker menu, not a window. If it ever wants dismissal it needs the
  `menu-toggle` grace-window treatment, not `window-toggle`.

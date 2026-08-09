---
status: accepted
---

# The wallpaper is pinned independently of the theme

> **Re-ported for quattro, 2026-08-09.** The decision holds; two of its
> mechanisms moved and one died. The current-background symlink is now
> `~/.local/state/omarchy/current/background` (the whole `current/` directory
> left `~/.config/omarchy`), and quattro's quickshell background plugin renders
> whatever it points at — swaybg is uninstalled. Both scripts were updated and
> the restore path re-measured: a displaced link is put back by the hook, and
> `omarchy-theme-set` still runs `theme-set.d` hooks. The swaybg paragraph below
> is retired — see Consequences. Quattro's per-theme user backgrounds
> (`~/.config/omarchy/backgrounds/<theme>/`) are not a substitute: a pin
> outranks every theme, not one. The hook itself is now *tracked*; it had been
> a real file only this machine knew about, which is the exact class of loss
> ADR-0028 exists to prevent.

Omarchy treats backgrounds as a property of the Theme: they live inside the theme
directory, and `omarchy-theme-set` repopulates that directory from the new theme
on every switch. A wallpaper chosen from a theme therefore cannot outlive it.
`~/.local/bin/pin-wallpaper` copies the chosen image to `~/.local/share/wallpapers`,
records it in `~/.local/state/omarchy/wallpaper-pin`, and a `theme-set.d` hook
re-applies it after every theme change.

Chosen over giving up and accepting the theme's wallpaper, because Appearance and
wallpaper are separate preferences here: switching light/dark should not change
the image.

## Consequences

A Pinned wallpaper outranks any theme's own background, including one we generate
ourselves (ADR-0008). A generated theme's wallpaper will not appear until
`pin-wallpaper --off`. This looks like a bug when you have forgotten the pin
exists, so the tooling says so out loud.

~~The restore hook cannot trust the `current/background` symlink alone.~~ It can
again, under quattro. The reason it couldn't: when a theme shipped no backgrounds,
`omarchy-theme-bg-next` painted a flat `swaybg --color '#000000'` and returned
**without rewriting the symlink** — the link claimed one thing while the screen
showed another, so a link-only guard concluded "already correct" and left the
desktop black. Quattro removed both halves: swaybg is gone, and the
no-backgrounds branch now sends a notification and leaves the link untouched
(measured in `omarchy-theme-bg-next`'s `TOTAL == 0` branch). The hook's guard is
back to comparing the link and nothing else; the swaybg interrogation went with
the process it interrogated.

Hooks live in `~/.config/omarchy/hooks/theme-set.d/`, and `omarchy-hook` executes
**every** file there that is not named `*.sample`. A backup copy left in that
directory becomes a hook that runs on every theme change. Backups go to
`~/.local/state/omarchy/hook-backups/`.

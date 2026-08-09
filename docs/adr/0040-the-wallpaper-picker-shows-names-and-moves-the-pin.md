---
status: accepted
---

# The wallpaper picker shows names and moves the pin

Quattro replaced the wallpaper menu with a fullscreen thumbnail grid that has
no names and no search. The user preferred the old one. `wallpaper-menu` now
answers the `Background` row and `SUPER+CTRL+SPACE` (one override of
`style.background` covers both, since upstream's `background` alias routes the
binding through that row), and an explicit pick made there moves an active
ADR-0007 pin to the chosen image.

## What "the old one" actually was, measured against what quattro ships

The 3.8.4 selector (`default/elephant/omarchy_background_selector.lua` at
upstream's tag, recovered from GitHub — the local checkout was upgraded in
place and its git history stripped, and the btrfs snapshot needs sudo) was a
compact ~800px Walker list: backgrounds as prettified names ("1-sunset-lake.png"
→ "Sunset Lake"), searchable as you type, one preview image beside the list.

Quattro's `omarchy-theme-bg-switcher` opens `omarchy-menu-images` — the
fullscreen image grid — passing **neither `--show-labels` nor `--filterable`**.
The picker supports both; the stock switcher just never asks. That is the whole
gap: same sources, same apply command, but no names and no type-to-search.

So the fix is two flags, not a UI: `wallpaper-menu` opens quattro's own picker
with labels and filtering on. Nothing of ours renders pixels, so there is
nothing to keep working after upstream updates except the flags themselves.

## Differences accepted rather than fought

- **Fullscreen, not a compact card.** The 800px window was Walker's; quattro's
  picker owns its geometry. Not worth a plugin fork.
- **Labels keep the number prefix** ("1 Sunset Lake", not "Sunset Lake") — the
  label text is the plugin's filename stem, and stripping the ordering prefix
  would mean re-implementing its label pipeline.
- **Thumbnails for every entry** instead of one preview beside a list — a
  strict improvement, kept.

## The pin follows an explicit pick

ADR-0007 made the stock picker a trap: with a pin active, a picked background
applies, then silently reverts on the next theme change — the restore hook
cannot tell a deliberate pick from a theme's default. Neither the old selector
nor quattro's had an answer, because neither knew pins exist.

The rule: **choosing a wallpaper in this picker is exactly the act the pin
exists to remember**, so if a pin is active it moves to the choice (via
`pin-wallpaper`, so the image is copied somewhere theme-proof) and a
notification says so, naming `pin-wallpaper --off` as the exit. With no pin
active nothing is pinned — transient picks stay transient, preserving
ADR-0007's default that wallpapers follow the theme until told otherwise.

The trade-off is real: someone cycling through looks while pinned now drags the
pin with them, where before their pin snapped back on the next theme change.
Chosen deliberately — "I picked it and it vanished" is a bug report, "I picked
it and it stuck" is the feature working.

`wallpaper-menu <image>` skips the picker and applies directly, which is also
how the apply-and-pin path is tested without a human click.

## Verified by use

Opened via the real surface (`omarchy-menu summon background` — the alias the
keybinding uses) and screenshotted: labels and filter live on screen. The
apply path round-tripped: picking a theme background moved the pin to a stable
copy and relinked the background; picking the pinned original moved both back.

## Re-check after upstream updates

The override quotes upstream's icon and aliases, and the flags assume
`omarchy-menu-images` keeps `--show-labels`/`--filterable`. If upstream's
switcher ever grows names and search of its own, this ADR reduces to the pin
rule and the override should shrink accordingly.

---
status: accepted
---

# One list for applications and system commands

> **Mechanism deleted 2026-08-09.** Walker and Elephant are uninstalled, and both
> halves of the merged list — `.config/walker/config.toml` and
> `.config/elephant/menus/palette.lua` — are deleted. The list is therefore *not*
> merged right now. `palette.lua` is the entry inventory the rewrite has to
> translate, so read it before rebuilding: tag `omarchy-v3.8.4-prequattro`.
> Note the unresolved chord collision — quattro already binds `SUPER+SPACE` and
> `SUPER+ALT+SPACE` to its own menu (ADR-0033).

The Launcher (`ALT+SPACE`, applications) and the System Palette (`SUPER+SPACE`, a
hand-written list of Omarchy commands) are now the same list. Both keys open Walker with
two providers merged: `menus:palette` and `desktopapplications`.

Supersedes the direction in ADR-0012.

## It is a provider, not a hand-built list

The obvious implementation — generate one big list and pipe it to `walker --dmenu`, as
`quick-menu` and `omarchy-menu` both do — was rejected. It would mean enumerating
applications by hand, and application discovery is not trivial here: snap `.desktop`
files are only visible because `.config/uwsm/env` adds `/var/lib/snapd/desktop` to
`XDG_DATA_DIRS`, a fix that was itself needed once already. Re-implementing that is how
Slack goes missing again. It would also lose real application icons, pinning, and
frecency.

Defining a menu provider keeps all of that native and adds nothing to maintain.

## One undocumented mechanism makes the ordering work

**With an empty query, Walker merges every provider into one list sorted by text.**
Provider order in the query string has no effect — verified by swapping it and getting
identical output.

**`FixedOrder = true` overrides that for a menu provider**, and does so completely: the
palette's entries stay contiguous, in definition order, ahead of the applications.
Measured — the palette occupies positions 0–22 of 86, with `Aether` at 23.

### Correction: the leading space was never load-bearing

An earlier revision of this ADR claimed a leading space in each entry's `Text` was what
sorted the palette above the applications, and cited a measurement of "position 0 with
the space, 49 of 65 without". **That was wrong, and the measurement was mis-attributed.**
The 49-of-65 case came from a scratch menu that did **not** set `fixed_order`; the
follow-up test that did set it also had the leading space, so the two were never
separated. `FixedOrder` alone was doing the work.

The spaces are gone. They cost real alignment — see below — for nothing.

## Lua, not TOML

The menus provider accepts either. Lua is required here because entries are dynamic:
*Switch to Dark* versus *Switch to Light* depends on the active theme, Hibernate only
appears when `omarchy-hibernation-available` succeeds, and Sleep is hidden when suspend is
disabled. Omarchy uses Lua for its own dynamic menus and TOML for static ones.

Note this is unrelated to whether *applications* appear — that is the
`desktopapplications` provider and `XDG_DATA_DIRS`, not the menu format.

## Naming: Omarchy wins

Omarchy's Toggle Menu entries come first, in Omarchy's order and under Omarchy's names,
because those are canonical. This rice's commands follow.

One genuine collision: **both lists had "Screensaver", with the same glyph and different
actions** — Omarchy's toggles the feature on or off, `quick-menu`'s starts it now. Under
the precedence rule Omarchy keeps the name; ours became **Start Screensaver**. Worth
noticing because the two would have been indistinguishable in a merged list.

## Row alignment

Commands and applications share one list, so their rows have to share one grid. Two
things were wrong once the palette landed:

**The glyph belonged in the icon slot, not the label.** `item.xml` ships a dedicated
`ItemImageFont` — a `GtkLabel` with `width-chars 2`, sitting in the same column as
`ItemImage` — precisely for icons that are font glyphs. Embedding the glyph in `Text`
instead put it inside the label widget, so the two row types indented by unrelated
amounts: the glyph column sat 9px right of the applications' icons while its label sat
8px left of theirs. Worse, that offset is *font-metric* driven, so any glyph with a
different advance width shifts its own row.

Entries now set `Icon` to the glyph and `Text` to the bare label.

**`ItemImageFont` needed the same box as `ItemImage`.** It ships with no margin, so
moving the glyph there fixed the icon column (2px residual) but pushed labels 22px left.
`.item-image-text` now mirrors `.item-image`: `min-width: 18px; margin-right: 14px`.

Measured after, in physical pixels at scale 1.667:

| Row | icon left | label left |
|---|---|---|
| palette | 1452 | 1517 |
| application | 1450 | 1516 |
| websearch | 1446 | 1516 |

One pixel — under a logical pixel, and from the glyph's font-derived natural width being
a shade over 18px.

## min_score

Elephant's matcher is a loose subsequence match over a composite of an entry's fields, so
at the default threshold `term` matched *Theme*, *Wallpaper* and *Nightlight* — burying
applications under commands that merely share letters. `min_score = 60` in
`~/.config/elephant/menus.toml` raises the bar.

Behaviour after: `theme`, `zen`, `lock` reach the commands, `chrom` gives Chromium first,
`term` returns nothing — which is what the application provider does alone, since
`desktopapplications` matches on application *name* only and never matched "term" either.

## Changes need both services restarted

Neither Walker nor elephant re-reads provider configuration while running, and Walker's
`--gapplication-service` is long-lived — it had been up 31 hours when this landed, so the
new provider was invisible even though the config, the Lua file and `elephant
listproviders` were all correct. The symptom is simply the old list, with no error.

    omarchy-restart-walker      # restarts elephant.service and app-walker@autostart

Use that rather than starting elephant by hand. `omarchy-launch-walker` will `setsid` its
own elephant if none is running, which is fine on a cold start but produces a second
instance alongside `elephant.service` if one is already up — and then a restart of the
service does not replace the instance actually answering queries.

## Still open

- **Favourites.** Walker already ships pinning for applications (`state: unpinned`, a
  `pin` action). Whether menu entries can be pinned too is unverified, and pinning is what
  would deliver the "favourites at the top" half of the original Raycast ask.
- **`quick-menu` is now unused** but still present and still bound to nothing. Remove it
  once the merged list has been lived with.
- The stopword case (`the`) still ranks commands above applications. Low priority — it is
  not a query anyone types deliberately.

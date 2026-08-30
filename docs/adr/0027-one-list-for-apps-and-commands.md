---
status: superseded — stock
---

# One list for applications and system commands

> **Fully retired 2026-08-15 — superseded, stock.** The surviving
> `shokupan-cmd-*.desktop` entries the note below credits are deleted too; see
> the closing addendum. Everything between here and there is history.

> **Fork dropped 2026-08-14 (upstream r1046 → r1744) — partially regressed, not
> implemented in full.** Upstream deleted the launcher plugin
> (`shell/plugins/launcher/`) that `shokupan.launcher` forked, folding it into
> `shell/services/AppLibrary.qml` / `AppSearch.js` and moving app launching to
> `omarchy-menu toggle apps`. Rather than re-port a 655-line copy, the fork was
> deleted and both reflexes (`SUPER+SPACE`, `ALT+SPACE`) retargeted to the stock
> apps menu. **What survives**: the merged list itself — the
> `shokupan-cmd-*.desktop` entries are ordinary applications, so commands still
> appear alongside apps. **What regressed**: the commands-first ordering
> contract. Lesson for any future re-port: a fork of the menu must be durable to
> Omarchy breaking changes — a thin patch over upstream internals, never a
> wholesale copy that dies with the file it was copied from.

> **Rebuilt under quattro 2026-08-09 — accepted, with a changed mechanism.** The
> first quattro addendum below declared the merge withdrawn; the user rejected
> that outcome ("my custom combined option/app menu is still not present"), and
> the second addendum records the rebuild: generated `.desktop` entries carry the
> commands, and a forked launcher plugin (`shokupan.launcher`) restores the
> ordering contract. Read the withdrawal addendum as history, not as the state.

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

## Addendum, 2026-08-09: quattro withdraws the merge

Ported to quattro. The mechanism is entirely new, most of the list turned out to
be redundant, and the central decision — one list — could not be kept.

### Why the merge is gone rather than rebuilt

Quattro's launcher (`shell/plugins/launcher/Launcher.qml:214`) builds its rows from
`DesktopEntries.applications.values` and nothing else. There is no provider system,
no merge point, and no plugin hook for injecting non-desktop rows; Elephant's
provider model has no successor. So the two surfaces are now fixed:

- **Launcher** — applications, `SUPER+SPACE`, quickshell overlay.
- **Omarchy Menu** — commands, `SUPER+ALT+SPACE`, a JSONC tree.

The one option for merging would be to write a `.desktop` file per command so the
launcher picks them up. Rejected: it pollutes every other application picker on the
machine — file-manager "Open With", XDG defaults, GNOME's own search — to fix one
list, and it is exactly the "enumerate things by hand" approach this ADR rejected
the first time.

### What the Omarchy Menu became, and why that is most of the ask back

The menu is no longer a nested tree you have to walk. `Menu.qml:461` searches **the
entire tree from the root** on any query, scored over label, id, aliases and
keywords, with a divider separating current-level hits from deeper ones. So it is
browse-first when idle and search-first when typed into — which is what ADR-0012
wanted the System Palette to be, and it is upstream's now rather than ours to
maintain.

What is genuinely lost is typing one query and seeing an application and a command
ranked together. What is kept is that either surface is one keystroke away and both
are searchable.

### Regression: web search is gone, and "Search Google" with it

Quattro's launcher has no web-search fallback of any kind — `grep -r` over
`/usr/share/omarchy` finds no websearch mechanism and no search-engine URL — so the
`websearch.toml` entry this rice carried has nothing to attach to. The entry itself
was one rename: the default engine was retitled from "Google" to **"Search Google"**,
because in a list that mixes applications and commands the bare word "Google" reads
as an app, and several Google web apps are installed. That reasoning survives the
regression: if upstream ever grows a search fallback, re-apply the rename. Nothing
is being rebuilt for this.

### The list shrank from 27 entries to 10

Quattro's own menu absorbed the whole Toggle Menu, plus Install, Remove, Update and
all seven system/power commands. **21 of the 27 palette entries are now upstream
rows with the same names and the same actions** — including Install, Remove and
Update Omarchy Desktop, which this rice had surfaced by hand precisely because they
were buried. That deletion is the real result of the port.

What remains in `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

| Entry | Why it survives |
|---|---|
| 1-Window Zen Ratio | **Override.** Upstream's row hardcodes 1:1; this machine runs 6:5 (shokupan-plugins ADR-0026) |
| Monitor Scaling ↑/↓ | No upstream row at all — keybinding only. `-cycle` was deleted, so one row became two |
| Switch to Light / Dark | No upstream row. Two rows gated on `when:` reproduce the old dynamic label |
| Emoji & Symbols, Clipboard History | Native overlays with keybindings but no menu row |
| Update System | Deliberately distinct from upstream's "Update > Omarchy" (omarchy-desktop-on-cachyos ADR-0034) |
| Calendar | shokupan-plugins ADR-0006 — and its bar entry point died with Waybar |

### The naming rule survived; the ordering machinery did not

"Omarchy wins" ported unchanged and is now enforced by the merge itself: reusing an
id overrides upstream's row rather than appearing beside it, so a name collision is
structurally impossible. The **Screensaver / Start Screensaver** collision this ADR
resolved by hand is upstream's problem now — it ships both `trigger.toggle.screensaver`
and `system.screensaver`, and resolved them the same way.

Deleted as no-longer-applicable, and this is the pleasant part: `FixedOrder`, the
`min_score = 60` tuning, the `ItemImageFont` / `.item-image-text` row-alignment CSS,
and the two-service restart dance. All of them existed to make commands and
applications share one list and one grid. No shared list, no problem to solve. The
row-alignment measurements in this ADR are now historical only.

### Two of this ADR's open questions are closed by deletion

- **Favourites** — no longer answerable here, and no longer this ADR's concern.
  Quattro's launcher has no pinning surface either; if it returns it will be
  upstream's feature.
- **`quick-menu` is now unused** — still true, still present, still bound to
  nothing. Now doubly dead: its replacement's replacement is upstream's menu.

### Corrections to what was written on 2026-08-09

Two claims made when the upgrade landed did not survive being checked:

- omarchy-desktop-on-cachyos ADR-0033 said the palette was "a mechanical rewrite
  into the plugin's config language". It was not mechanical — 21 entries were
  redundant and one had lost its underlying command. - The chord collision was
  resolved in favour of upstream; see below.

### The chord collision, resolved

Quattro binds `SUPER+SPACE` to the launcher and `SUPER+ALT+SPACE` to the menu. This
rice had `SUPER+SPACE` and `ALT+SPACE` both on the merged list, so that either
reflex landed somewhere sensible. With the list split, both reflexes cannot land in
the same place any more.

Decided: **adopt upstream's chords and add bare `ALT+SPACE` → launcher.** Both old
app reflexes reach applications; the command surface moves to `SUPER+ALT+SPACE` and
is relearned. One added binding, no unbinds, nothing to re-check against upstream on
the next update — and the underlying goal, that a reflexive press lands somewhere
sensible rather than nowhere, is what actually needed preserving.

## Addendum: the merge is rebuilt, 2026-08-09

The withdrawal above lasted a few hours. The user's correction stated the actual
contract, which the withdrawal had misfiled as a nice-to-have:

> we had all the options in the top in generally the same order as the omarchy
> options menu plus my extras then the apps in alphabetical order below. They
> were not mixed.

That is the specification: **commands as a contiguous block on top, in roughly
the Omarchy options-menu order plus this rice's extras; applications alphabetical
below; never interleaved.** Walker delivered it with `FixedOrder = true`. It is
delivered again, by two pieces.

### Commands become desktop entries

The withdrawal's claim — the launcher "has no plugin hook for injecting
non-desktop rows" — was true and irrelevant: the launcher lists whatever
`.desktop` entries exist, so commands ride in as generated entries. A tracked
generator, `.local/bin/shokupan-launcher-cmds`, renders the full pre-quattro
palette (28 entries at tag `omarchy-v3.8.4-prequattro`, quattro-adjusted:
`omarchy-toggle-waybar` → `omarchy-toggle-bar`, the deleted scaling `-cycle`
becomes up/down rows, walker modes become shell-IPC toggles, `omarchy-menu`
routes become quattro ids — an action id like `style.theme` runs directly) into
`.local/share/applications/shokupan-cmd-<slug>.desktop`. The output is tracked,
not heal-generated: tracked files are what `loaf heal` defends, and the
conditional entries (Sleep, Hibernate) get their conditions evaluated on the
machine they describe. Glyphs live in the generator as hex codepoints — the
editor-loss trap both palette.lua and the menu extension document — and are
rendered to PNGs at generation time, because the launcher's icon slot takes a
file path; the render fails loudly on a missing glyph. Exec paths are absolute
(quickshell has no `~/.local/bin` on PATH — the same trap as the bar modules).

This ADR originally rejected desktop entries as pollution of other application
pickers. That rejection is overruled by the owner of the list: the merged list
is the requirement, and the pollution is bounded — 28 real commands under
`Categories=System;Utility` in pickers this machine barely has. `NoDisplay=true`
would hide them from the launcher too, so the cost is accepted, not worked around.

### The ordering needs a fork, and the fork is sanctioned

Plain `DesktopEntries` cannot deliver the block: measured, the stock launcher's
resting order is pure lowercased-Name alphabetical (`LauncherSearch.js`
`entrySortKey`), there is no frecency, no pinning, and no launcher key in
`shell.json`. And the stock plugin cannot be shadowed: `PluginRegistry.qml`
rejects any third-party plugin whose id collides with first-party or starts with
`omarchy.` — also measured, it is an explicit branch with a console warning.

So the merged list is its own third-party overlay plugin,
`.config/omarchy/plugins/shokupan-launcher/` (`shokupan.launcher`), the
sanctioned extension path. `Launcher.qml` is upstream's byte-for-byte plus a
provenance header; the one functional change is in its `LauncherSearch.js`: with
an empty query, entries whose desktop-file id is in the command table sort by
that table's position (the generator's order — Toggle Menu first, rice extras
after), everything else alphabetically below. With a query, upstream's relevance
scoring ranks all entries — the block is the resting order, search is search.
`FixedOrder = true` became eleven lines of comparator.

Verified three ways: a screenshot of the running plugin showing the block on top
(Screensaver → Nightlight → Idle Lock → Notifications → Top Bar →
Workspace Layout, glyphs rendering in the icon slot); the fork's `sortedEntries`
run under node against a shuffled mix, asserting contiguous-block, defined
order, alphabetical apps and no interleave; and activation through the
launcher's own `gtk-launch` path flipping the zen-ratio flag (shokupan-plugins
ADR-0026) off and on.

### What is still open

- **`SUPER+SPACE` still summons `omarchy.launcher`.** The binding lives in the
  Hyprland layer (`o.bind` on `omarchy-shell shell toggle omarchy.launcher`),
  which is another work stream's file. The merged list is one word away:
  retarget the toggle at `shokupan.launcher`. Until then it opens by IPC and the
  stock launcher shows the commands mixed alphabetically — present but unordered.
- **The fork must be re-diffed against upstream after omarchy updates.** It is
  655 lines of upstream QML plus our comparator; upstream fixes do not arrive
  for free. The provenance header says exactly this.
- The stock launcher and every other picker also list the command entries. In
  the fork they are the block; elsewhere they are alphabetized among the apps.

## Addendum, 2026-08-15: fully retired at r1744, superseded — stock

The merged list is fully retired under the stock-first rule ("omarchy defaults
are the way to go"). The stock-first audit closed what the r1744 regression had
left half-standing: the generated `shokupan-cmd-*.desktop` entries, their
rendered icons, and the `shokupan-launcher-cmds` generator are deleted, and the
apps menu lists applications only. Commands are reached via the Omarchy Menu
(`SUPER+ALT+SPACE`), which quattro made searchable from the root — the
discovery half of the original ask, upstream's to maintain.

The history argued for this: the entries duplicated quattro's own menu (21 of 27
were already upstream rows when the port landed), and the merge regressed twice
across upgrades — first when quattro deleted Elephant's provider system, then
when r1744 deleted the launcher plugin the rebuild forked. A list that dies with
every upstream restructure is a maintenance contract, not a feature.
`claude-usage` (the script, shokupan-plugins ADR-0039) survives; only its
launcher entry goes.

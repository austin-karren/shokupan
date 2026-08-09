---
status: accepted
---

# The single-window zen aspect ratio: a reading column, not a square

> **Bar surface reborn on quattro 2026-08-09.** The `6 5` value and `ratio-toggle`
> are untouched; the `custom/ratio` row of the table below is now
> `.config/omarchy/bar/modules/ratio.qml` (ADR-0013's addendum has the port).
>
> The menu-override section below is also void: `menu.sh` was deleted with the
> menu port — quattro's `omarchy-menu` sources no such file, so the
> `show_toggle_menu` redefinition it describes has no host. Whether quattro's
> menu has a new extension point for the label is the menus agent's question,
> not the bar's.
>
> **And the value war this ADR spent its correction sections on is over.** The
> Hyprland port put the zen value in `~/.config/hypr/hyprland.lua` itself —
> `hl.config({ layout = { single_window_aspect_ratio = { 6, 5 } } })` whenever
> the flag file *exists* — so the flag's contents stopped mattering. Every
> entry point (Toggle Menu, `SUPER+CTRL+BACKSPACE`, the bar) now delegates to
> `omarchy-hyprland-toggle`, and `ratio-toggle`'s repair-on-poll mechanism is
> deleted along with the problem it repaired. Verified by clicking: a lone
> 2284px window narrows to exactly 1788px (6:5 of its 1490px height) and back.

Omarchy's **single-window square aspect ratio**, kept as a feature and renamed to
**single-window zen aspect ratio**, with the value widened from `1 1` to `6 5`. The point
of the feature is holding a lone window to a comfortable reading width on a wide display;
a square was one setting of that, not the goal, and the old name described the setting.

**Omarchy's branding is kept deliberately.** Only the word "square" changes. An earlier
revision rebranded it to a short "Zen ratio" with its own vocabulary and tooltips, which
was wrong twice over: it discarded a name that already described what the feature does,
and it made the bar disagree with the Toggle Menu entry and notifications for the same
feature.

Implemented in [`ratio-toggle`](../../.local/bin/ratio-toggle).

## Hyprland silently ignores gentle ratios

The requested value was 3:2. Two separate reasons it could not be used, and the second
is the one worth remembering.

**First, this display is already 3:2.** 3840×2560 is exactly 1.500, so a 3:2 constraint
leaves a lone window 2232px of the 2288px usable width — a 28px margin. Not a widening
of the square so much as switching the feature off.

**Second, and much less obvious: there is a hard ceiling at ~1.23 here, and exceeding it
fails silently.** Measured against a real window, available area 2284×1484:

| Ratio | Result | Applied? |
|---|---|---|
| 1:1 (1.000) | 1484px, 65% of full width | yes |
| 11:10 (1.100) | 1632px, 71% | yes |
| 6:5 (1.200) | 1782px, 78% | **yes — chosen** |
| 1.23 | 1826px, 79.9% | yes |
| 1.24 | ignored | no |
| 5:4 (1.250) | ignored | no |
| 4:3 (1.333) | ignored | no |
| 3:2 (1.500) | ignored | no |

The boundary is **0.8 × the available area's own aspect**: `0.8 × 1.5391 = 1.2313`, and
1.23 applies while 1.24 does not. So Hyprland appears to skip the constraint entirely
when it would shrink the window by less than 20% — a minimum-effect guard, with no
warning and no log line. A value above the ceiling looks exactly like the toggle being
broken.

**4:3 was chosen after seeing the width table and is unreachable. So is 5:4**, missing by
0.019. 6:5 is the widest clean ratio under the ceiling, and still takes a lone window
from 65% to 78% of the usable width.

The ceiling scales with the display, so **this is not portable**: on a 16:9 monitor the
limit would be ~1.42 and 4:3 would work fine. It is narrow here precisely because the
panel is 3:2.

## Three entry points, one flag file

The feature is reachable three ways, and all three must keep working:

| Entry point | Runs | How |
|---|---|---|
| The bar module | `ratio-toggle` | `custom/ratio` in `config.jsonc` |
| Toggle Menu → "1-Window **Zen** Ratio" | `ratio-toggle` | `show_toggle_menu` override |
| `SUPER+CTRL+BACKSPACE` | `ratio-toggle` | rebound in `bindings.conf` |

`omarchy-hyprland-window-single-square-aspect-toggle` copies a **fixed** file out of
Omarchy's read-only tree, hardcoding `single_window_aspect_ratio = 1 1`. Editing the copy
is not durable: the next enable re-copies the original.

**Replacing that script is not possible.** `~/.local/share/omarchy/bin` comes *before*
`~/.local/bin` on `PATH`, so a same-named script here never wins.

**The menu, however, has a sanctioned override.** `omarchy-menu` sources
`~/.config/omarchy/extensions/menu.sh` *after* defining its functions, so redefining
`show_toggle_menu` there replaces it with nothing in Omarchy's tree touched. An earlier
revision of this ADR claimed the menu could not be fixed and dismissed it as "far more
machinery than a stale label deserves" — that was simply wrong: the extension point was
there, and the file already existed holding Omarchy's template.

The override is **generated from Omarchy's source rather than retyped**, with exactly two
edits — the label gains "Zen", and the dispatch calls `ratio-toggle`. Verified
byte-identical to upstream otherwise. Retyping it would have meant hand-copying eleven
Nerd Font glyphs, and this work has already lost one glyph to a manual edit.

Its cost is the one Omarchy's own template warns about: **an overridden function does not
receive upstream updates.** If Omarchy adds or renames a Toggle Menu entry, this copy
silently lacks it. Recorded in the file itself with the instruction to re-copy after an
update that touches that menu.

### A private filename was tried and is subtly broken

The first attempt wrote its own `single-window-zen-aspect-ratio.conf`, reasoning that
`hyprland.conf` sources `toggles/hypr/*.conf` so any filename in that glob works.

It does work in isolation, and it **breaks the Toggle Menu**: Omarchy's script tests for
*its* exact path, so with only the private file present it finds nothing to remove and
concludes the feature is off. The menu entry could then only ever turn it **on** — and
because the private file also won the alphabetical glob, enabling from the menu produced
no visible change at all. Reported symptom: "still shows in the omarchy options menu but
does nothing."

### What it does instead

`ratio-toggle` writes **Omarchy's own filename** with different *contents*. Omarchy's
script still finds the file and can still remove it, so off works from every entry point.

`--status` additionally repairs the value: if the file exists but does not carry the
configured ratio, it is rewritten and Hyprland reloaded. Waybar polls that every 3 seconds.

That repair started out as the *mechanism* for making the Toggle Menu apply the right
value. With the menu override in place it is now a **safety net** — every entry point
calls `ratio-toggle` directly, so Omarchy's square script is no longer reachable from any
of them. It is kept because the script can still be run by hand, and because a 1:1 file
left over from before this change would otherwise persist silently.

## The icon vanished, and nothing reported it

Worth recording because the failure was invisible. An intermediate revision embedded the
`U+F2D0` glyph as a literal character in the script; an edit dropped it, `"text"` became
an empty string, and **Waybar rendered nothing at all** — no error, no log line, the
module simply absent from the bar. A module with empty text is indistinguishable from one
that is deliberately blank, which is exactly how Omarchy's own indicators hide themselves.

The glyph is now `$'\uF2D0'` via bash ANSI-C quoting. An escape survives editing; a
private-use codepoint that renders as nothing does not. **Any glyph in a script should be
an escape, not a pasted character** — this is the second time in this work that an
invisible character caused a silent failure.

## Verified

Toggled against a real lone tiled window:

    zen ON   1782x1484   251px margin each side
    zen OFF  2284x1484     0px
    zen ON   1782x1484   251px

`hyprctl getoption layout:single_window_aspect_ratio` reports `[6,5]`, and `hyprctl
configerrors` is clean.

All three entry points exercised:

    bar toggle on                    -> flag written, effective [6,5]
    omarchy's 1:1 copy dropped in    -> effective [1,1]
    one --status poll                -> file rewritten, effective [6,5]
    omarchy's own toggle             -> flag removed, module reports off
    bar toggle on again              -> effective [6,5]

And the bar itself, from a screenshot: the module is present, bright when on and dimmed
when off, with the gaps either side still measuring 50 and 50 physical px.

Note that `hyprctl reload` alone does **not** re-lay-out existing windows — the earlier
measurements needed a float/tile round-trip to force it. Real use hides this because
opening or closing a window re-tiles anyway, but it makes a value change look inert if
you only reload and stare at the screen.

## Follow-up

The ceiling is worth re-measuring if the monitor ever changes, and `ASPECT` in
`ratio-toggle` is a single constant for that reason. Raising it past 6:5 on this display
will make the toggle appear to do nothing.

`omarchy-hyprland-window-single-square-aspect-toggle` is now unreferenced by anything here.
It still exists and still works, applying 1:1; running it by hand is the one way to get a
square back, and the `--status` repair will undo that on the next poll.

Re-copy `show_toggle_menu` from `$OMARCHY_PATH/bin/omarchy-menu` after any Omarchy update
that adds or renames a Toggle Menu entry.

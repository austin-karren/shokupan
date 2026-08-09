---
status: accepted
---

# Resize windows by dragging their borders

Four settings in `general` (`~/.config/hypr/looknfeel.lua`), no scripts:

| Setting | Value | Effect |
|---|---|---|
| `resize_on_border` | `true` | Drag any window edge to resize, no modifier |
| `extend_border_grab_area` | `10` | Widens the draggable strip; `border_size` is 2 |
| `hover_icon_on_border` | `true` | Resize cursor over a draggable edge |
| `snap { enabled }` | `true` | Dragged floating windows pull flush to edges and each other |

`resize_on_border` was explicitly `false`, not merely unset — Omarchy turns it off — so
there was no way to resize with the mouse except the modifier drags below.

## It works on tiled windows too

Worth stating because "resize by dragging" sounds like a floating-window feature.
Dragging a tiled window's border moves the **split boundary**, which is the same thing
the `SUPER+ALT` Size ladder does, but continuously and without discrete rungs.

None of ADR-0022's difficulty applies. That whole mess — a delta whose sign depends on
which child of the split you are, bounds-checked against the wrong window, chunked
through a convergence loop — exists only because `resizeactive` is being driven
*programmatically*. Interactive dragging is Hyprland's own code path and simply works.
The scripted ladder remains worth having for landing on exact fractions, which a drag
cannot do reliably.

## The one trade-off

`border_size` is 2 logical pixels, which is not a mouse target, so the grab strip has to
be widened. That strip is the cost: near a window edge, a click starts a resize instead
of reaching the application.

**10, not Hyprland's default 15**, because the gaps here are deliberately small — 8px at
the screen edge, 8px between windows (`gaps_in` twice, per ADR's uniform-8 rule). At 15
the strip reaches well past the gap and into the neighbouring window. At 10 it covers
the gap with a little margin.

If edge clicks feel grabby, `extend_border_grab_area` is the only knob that matters.
Lower it before touching anything else, and do not compensate by raising `border_size` —
that changes the look to fix an input problem.

`hover_icon_on_border` is what keeps this from being surprising rather than merely
invisible: the cursor changes over a live edge, so the strip is discoverable. It already
defaults to true; it is stated in the config because it is load-bearing here, not
decorative.

## Drag snap

`general:snap` makes a dragged floating window pull flush to screen edges and to other
windows. Hyprland ships it disabled. Both gaps are set to **8** rather than the default
10, so a mouse-snapped window lands on the same margins `float-snap` produces — dragging
a window to the left edge and pressing `SUPER+CTRL+ALT+←` should not give two different
results.

This is **Drag snap**, distinct from the **Keyboard snap** of ADR-0024. The glossary
keeps them apart because Hyprland, this repo and macOS window managers all call both
"snapping".

## Already present, and easy to miss

Omarchy already binds modifier drags, which is why this ADR adds no bindings:

    SUPER + left-drag    movewindow
    SUPER + right-drag   resizewindow

`SUPER` + right-drag has always resized. It remains the better tool when the edge strip
is awkward to hit — a window at a screen edge, or one whose application wants clicks near
its border — because it grabs anywhere in the window.

## Rejected: scroll to resize

`SUPER+ALT` + scroll is currently `changegroupactive`, cycling tabs within a window
group. Groups are unused here (ADR-0023), and under the modifier scheme `SUPER+ALT`
means "resize this window", so binding scroll to the Size ladder looks obvious.

It was rejected because **a wheel emits bursts, not single steps.** One flick would
advance several rungs and wrap, so the window would land somewhere unpredictable — the
opposite of what a ladder is for. Discrete rungs and a continuous input do not mix.
Dragging a border is the correct continuous gesture, and it now exists.

The scroll binding is left alone rather than unbound: it is harmless, and removing it is
a separate decision about groups.

## Not verified by measurement

Unlike the rest of the window work, this is not backed by a measured test. Nothing on
this machine can synthesise a mouse drag — `wtype` is keyboard-only and `ydotool` is not
installed — so the settings were confirmed live via `hyprctl getoption` and the feel has
to be judged by using it. That is acceptable here because every value is a preference
knob with an obvious direction to adjust, not a correctness question.

## Addendum: ported to quattro, 2026-08-09

This ADR came through the quattro migration (ADR-0033) more cheaply than any other in
the window-management set, because it was never anything but settings. The four values
are unchanged; only the file and the syntax moved, from a `general { }` block in
`looknfeel.conf` to an `hl.config({ general = { … } })` call in `looknfeel.lua`. Nested
`snap` survives as a nested Lua table, so even the shape is the same.

Re-confirmed by `hyprctl getoption` after `hyprctl reload`, all four plus the gaps they
depend on:

    resize_on_border         true    extend_border_grab_area  10
    hover_icon_on_border     true    snap:enabled             true
    snap:window_gap          8       snap:monitor_gap         8
    gaps_in                  4       gaps_out                 8

**Quattro re-asserted the Hyprland defaults this ADR overrides**, so none of this was
inherited: `resize_on_border` was back to `false`, `extend_border_grab_area` to `15`,
and `snap:enabled` to `false`. The port was necessary, not decorative.

**`gaps_in`/`gaps_out` are listed above because they are load-bearing here, not as
housekeeping.** Quattro's defaults are `5`/`10`, which both breaks the uniform-8 rule and
widens every gap. `extend_border_grab_area = 10` is chosen against an 8px gap — against
quattro's 10px gaps it would be the wrong number for the reason the section above gives.
Porting this ADR without the gaps would have left the grab strip mistuned in a way no
`getoption` check on the four settings alone would catch.

One line got *shorter*: the `shadow { enabled = false }` block is gone. It existed because
Omarchy set `range = 2`, too short to fade, so it drew a hard near-black line rather than
a shadow. Quattro's `default/hypr/looknfeel.lua` now ships `shadow { enabled = false }`
itself — measured as `decoration:shadow:enabled = false` with our file not mentioning it —
so restating it would be a no-op impersonating a decision.

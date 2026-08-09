---
status: accepted
---

# Promote the single-window aspect-ratio toggle out of a menu and onto the bar

> **Ported 2026-08-09, and it moved.** The toggle is back on the bar, but no
> longer in the right cluster: it is a hover-revealed module at the end of the
> *centre*, next to the indicators. `ratio-toggle` itself is unchanged. See the
> addendum at the foot.

The single-window aspect-ratio toggle — constraining a lone window via Hyprland's
`single_window_aspect_ratio` — is used often enough that living three levels deep
in a menu is the wrong home for it. It is now `custom/ratio` on the right of the bar,
backed by [`ratio-toggle`](../../.local/bin/ratio-toggle).

## Correction to the original framing

It is **not** in the System Palette. It is an entry in Omarchy's Toggle Menu
(`SUPER+CTRL+O`), which dispatches to
`omarchy-hyprland-window-single-square-aspect-toggle`. Worth stating because
"move it out of the quick menu" describes a move that cannot happen as written.

## Decided: it goes on the bar

The bar is the wanted surface, and the precedent is already set — `custom/apexshot`
and `custom/calendar` are both bespoke modules added to this bar for exactly this
reason. A UI toggle is no different in kind. The open questions below are about how,
not whether.

## Settled: always visible, with a state distinction

The module renders in both states rather than only when active — being able to
*point* at it is the reason it is going on the bar. Omarchy's own indicators
(`custom/idle-indicator` and friends) do the opposite, emitting empty text when
inactive, so this is a deliberate departure from that convention.

## How state is read — and a correction

An earlier draft of this ADR said the flag lives at
`~/.local/state/omarchy/toggles/single-window-aspect-ratio` and should be read with
`omarchy-toggle-enabled single-window-aspect-ratio`. **Both are wrong**, and wrong in
a way that fails silently.

`omarchy-hyprland-window-single-square-aspect-toggle` delegates to
`omarchy-hyprland-toggle`, not `omarchy-toggle`, and that variant writes into a
`hypr/` subdirectory with a `.conf` suffix:

```
~/.local/state/omarchy/toggles/hypr/single-window-aspect-ratio.conf
```

`omarchy-toggle-enabled` only ever tests `toggles/$1`, so it returns false while the
toggle is on. Verified by observation: with Ratio enabled, that command still reported
not-enabled. Following the original advice would have produced an icon permanently
stuck in the "off" state, with nothing to indicate why. The module tests the real path
directly.

The two toggle families exist because Hyprland flags have to be *sourced* as config —
`hyprland.conf` sources `toggles/hypr/*.conf` and the script runs `hyprctl reload` —
whereas ordinary toggles are just marker files.

**Superseded in part by ADR-0026.** The module no longer delegates to Omarchy's script at
all: that script copies a file hardcoding `1 1`, so running any other ratio means owning
the file. `ratio-toggle` writes Omarchy's *own* filename with different contents instead, so
Omarchy's script can still remove it and the Toggle Menu keeps working. The
feature is also renamed — see **single-window zen aspect ratio** in the glossary.

The property claimed further down — reachable from both the Toggle Menu and the bar — does
still hold, and there is a third route, `SUPER+CTRL+BACKSPACE`.

> **The 1:1-repair mechanism died with the Hyprland port (2026-08-09).**
> `hyprland.lua` now applies the zen value itself whenever the flag file exists,
> so its contents stopped mattering and all three entry points converge on 6:5
> at config time. `ratio-toggle` is reduced to the bar's adapter: `--status`
> keeps the JSON contract `ratio.qml` polls, and a click delegates to
> `omarchy-hyprland-toggle single-window-aspect-ratio` — the delegation the
> paragraph above once ruled out, made safe because the copied file's contents
> no longer carry the value.

## One glyph, dimmed — after trying two

**Final:** `U+F2D0` (`window-maximize`) in both states, with the `active` class dimming
it to `opacity: 0.45` when off. This is the glyph Omarchy already uses in this toggle's
own notifications, so the bar and the toast agree.

A matched pair was built and shipped first — `U+F01A0` `crop_landscape` for off,
`U+F01A2` `crop_square` for on — so the glyph would show the shape a lone window takes.
It was reverted after looking at it **on the bar** rather than in a test render:

- Both are 1px outlines with almost no mass beside `F2D0`'s filled title bar. Next to
  `apexshot`'s solid camera they read as unfinished.
- At 12px the two barely differ from each other. The aspect distinction that is obvious
  at 40px does not survive the shrink.
- Their ink measured 13–15px against `apexshot`'s 18px, so they were also undersized
  for the cell. With `F2D0` the gaps either side of the module measure 50 and 50
  physical px against an ideal pitch of 49.1; with the outlines they were 47 and 52.

**No square sibling of `F2D0` exists.** Font Awesome's window family (`F2D0`–`F2D3`) is
maximize / minimize / restore / close, none of them square. The nearest Material Design
candidate, `F05AE`, is portrait with a small tab rather than a title bar, so pairing
them reads as "window" versus "shutter". Verified by rendering both families and the
dock family; there is no pair that keeps the weight.

So the earlier draft's recommendation — one glyph plus a class — was right, and for a
reason it had not identified. Its stated argument was that picking a lookalike glyph
blind is how `custom/calendar` ended up needing a comment about `F0479` being an SD
card. That risk is real but answerable: `pango-view` renders a candidate row in one
command. The *actual* reason to prefer one glyph is that a second glyph has to survive
being shrunk to 12px next to solid neighbours, and outline pairs do not.

**Dimming, not colour.** `.active` means `#a55555` red in this bar and is reserved for
warnings — recording, idle disabled, notifications silenced. The constraint being on is a normal
state. Opacity is already the idiom here for "present but not active"
(`#workspaces button.empty`, `.hidden`).

A single glyph also **fixes the module's footprint**, so toggling cannot shift its
neighbours at all — a stronger guarantee than measuring that it happens not to.

### The transferable lesson

Render candidate glyphs, but judge them **composited into the bar at its real size**,
against their actual neighbours. A glyph sheet at 40px on a black background answers
"which icon is this?" and not "does this hold up at 12px beside a solid camera?" — and
only the second question decides whether it looks finished.

## Placement and spacing

`custom/ratio` sits between `custom/apexshot` and `custom/weather`. The right group
divides into actions then status — `apexshot` acts, everything from `weather` rightwards
reports — and a toggle belongs with the actions.

> ADR-0029 later moved `custom/weather` to the centre and deleted `cpu`. The division
> above is unchanged and was the reasoning for both; the status run now begins at
> `bluetooth`, and `custom/ratio`'s position between `apexshot` and it is the same
> position it always held.

It takes **no bespoke margins**. `style.css` already solves this cluster with uniform
*pitch* rather than tuned gaps (`min-width: 18px; margin: 0 5.7px`), precisely because
status glyphs change width between states; adding `#custom-ratio` to that selector list
is the whole change. The glyph's ink measures 18px, the same as `apexshot`, so it sits
inside the shared box.

Verified by measuring ink-blob centres from a screenshot rather than by eye. Neighbour
centres `3452, 3506, 3605, 3652, 3704, 3756, 3804` are unchanged by the toggle, and the
gaps either side of the module are 50 and 50 physical px against an ideal pitch of 49.1.
Residual variation of a few pixels elsewhere in the cluster is glyph ink asymmetry
inside fixed boxes, not layout drift.

## Refresh

Hyprland has to be reloaded for a sourced toggle file to take effect, and nothing in that
path knows about Waybar, so clicking the module sends `SIGRTMIN+11` itself (signals 7–10
are taken by Omarchy's indicators).

A 3-second `interval` backs that up, because the ratio can still be flipped from the
Toggle Menu, which calls Omarchy's script directly and cannot signal the bar. Re-reading a
flag file every few seconds is free and keeps the icon honest whichever route is used.

## Resolved

`~/.config/hypr/looknfeel.conf` carries `single_window_aspect_ratio` **commented out**, so
there is no competing source for the setting. Left as documentation, and the comment now
records the live value and the ceiling from ADR-0026 — setting it there uncommented would
make the constraint permanent and unswitchable.

## Addendum: on quattro it is a hover-revealed centre module, 2026-08-09

This ADR's thesis was that the toggle is used often enough that living three
levels deep in a menu is the wrong home. That still holds. What changed is that
quattro's bar has a state the Waybar bar did not: the centre section reveals its
quiet modules on hover, and a module can opt into that.

So the toggle is no longer the right cluster's action prefix. It sits at the end
of the **centre**, next to the indicators, and mirrors their behaviour exactly:

- zen ratio **on** → the glyph is visible, tinted with the theme's `[bar] active`
  colour;
- zen ratio **off** → the module collapses to zero width until the centre of the
  bar is hovered.

That is a better fit for this ADR's own argument than the old always-on glyph
was. The point of promoting it was reach, not permanent presence, and the state
worth seeing at a glance is the *constrained* one.

**It is a `type: "qml"` module, not `type: "command"`.** A command module was the
obvious port — `ratio-toggle --status` still emits Waybar-style JSON and quattro
consumes exactly that shape — but command modules are always visible, with no
setting to bind visibility to the hover state. Custom QML modules receive the bar
root as `bar`, so `.config/omarchy/bar/modules/ratio.qml` binds to
`bar.centerSectionRevealHeld`, the same property
`plugins/bar/widgets/Indicators.qml` uses. About sixty lines, and it is the
documented extension point rather than a patch.

Two things it inherits by being written by hand rather than declared:

- The status poll keeps its **last good reading** if a poll fails to parse,
  instead of blanking — the ADR-0031 principle, applied to a second module.
- The state colour comes from the theme's `[bar] active`, not from opacity as the
  Waybar version did. Quattro has no per-module opacity knob; the accent colour
  is its equivalent, and it is more legible.

**One trap worth recording.** Quickshell runs module commands through
`bash -lc`, whose `PATH` does **not** include `~/.local/bin` — a minimal login
shell here resolves to `/usr/local/sbin:/usr/local/bin:/usr/bin:…` and nothing
more. The first attempt used a bare `ratio-toggle --status` and the module
rendered as an empty box with no error anywhere. `$HOME/.local/bin/ratio-toggle`
is therefore deliberate, not incidental. The underlying cause is that
`.config/uwsm/env`, which puts `~/.local/bin` on the session `PATH`, is not
currently installed; it also still points `OMARCHY_PATH` at
`~/.local/share/omarchy`, which no longer exists, so it needs rework before it
can be restored.

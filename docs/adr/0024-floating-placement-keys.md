---
status: accepted
---

# Floating windows get placement keys

`SUPER+T` floats a window at whatever size it already had, and until now there was
nothing to do with it afterwards — no resize, no snapping, no centring. That is the
whole reason floating felt unusable rather than merely different.

Implemented as [`float-snap`](../../.local/bin/float-snap), plus a floating branch in
[`window-resize`](../../.local/bin/window-resize).

| Keys | Action |
|---|---|
| `SUPER+CTRL+ALT` + ←/→ | Left / right half |
| `SUPER+CTRL+ALT` + ↑ | Fill the usable area |
| `SUPER+CTRL+ALT` + ↓ | Bottom half |
| `SUPER+CTRL+ALT` + C | Centre, keeping the current size |
| `SUPER+ALT` + arrows | Size ladder — `1/3, 1/2, 2/3` (ADR-0022) |

All of them no-op on tiled windows.

## Why its own modifier set

`SUPER+CTRL+ALT` was left free by ADR-0023 for exactly this. Floating placement is a
different **mode**, not a different intensity, so it earns its own modifier set rather
than displacing the window or workspace tiers.

The Size ladder is the deliberate exception: `SUPER+ALT`+arrows means "size this window"
regardless of whether it is tiled or floating. One gesture, one meaning, two
implementations.

## Centre is not on SUPER+C

`SUPER+C` was requested, and it is taken: Omarchy binds it to **Universal copy**
(`sendshortcut CTRL, Insert`) — the macOS `Cmd+C` reflex, the same technique as this
config's `SUPER+Q`. Taking it would have broken copy in every application, which is a
far worse trade than a longer chord. Centre is on `SUPER+CTRL+ALT+C`, which keeps the
`C` mnemonic and puts it with the rest of the floating family.

`SUPER+V` is Universal paste for the same reason, so the whole letter pair is off
limits.

## ↑ fills rather than taking the top half

The one asymmetry: ←/→/↓ are halves and ↑ is fill. It was the requested behaviour and
it is the more useful action — a top half is rarely wanted on a 2304×1536 logical
desktop, whereas maximise-without-fullscreen is wanted constantly. ↓ keeps the bottom
half so the halves remain reachable.

## The scale rounding trap

Placement needs the monitor's **logical** size, and `hyprctl` will not give it
accurately: it rounds the scale. This machine runs `1.666667` per `monitors.conf`, which
`hyprctl monitors -j` reports as `1.67`, so `width / scale` yields **2299.4** where the
truth is **2304**.

Five pixels sounds ignorable, and it is not, because the error lands entirely in one
margin. Computed that way, a left-half window sits 8px from the left edge and a
right-half window sits 12.6px from the right — visibly lopsided, and precisely the kind
of asymmetry the bar and layout are otherwise tuned to avoid.

Reading `monitors.conf` was rejected: per-monitor rules, `auto`, and multi-monitor
setups all make it an unreliable source for what Hyprland actually resolved.

**Hyprland computes `exact N%` correctly**, so the logical size is obtained by asking it
for `100%` once and reading the answer back. That is cached per monitor and resolution
in `~/.local/state/omarchy/hypr-logical-size`, so the probe runs once rather than per
keypress. The probe needs a floating window, which is the only case this script handles
anyway.

`window-resize`'s tiled branch now prefers that cache too, falling back to
`width / scale`. The tiled path tolerated the error — it is inside the ladder's `EPS`, so
the rung chosen was still right — but there is no reason to keep computing it wrong once
an exact number is available.

## Geometry

Outer margin and the divider between halves are both `gaps_out` (8), so the result
reads as evenly spaced as a tiled layout. Matching tiled gaps exactly would mean
involving `gaps_in` and border widths for no visible gain.

Verified against a throwaway floating window:

| Action | Result |
|---|---|
| usable area | `LW 2304 LH 1536 → x0 8, y0 40, 2288×1488` |
| left | `(8,40) 1140×1488` |
| right | `(1156,40) 1140×1488` — right edge 2296, an 8px margin matching the left |
| fill | `(8,40) 2288×1488` |
| bottom half | `(8,788) 2288×740` |
| centre | size preserved, `x = 582 = (2304−1140)/2`, `y = 40` (clears the bar) |

`y0 = 40` rather than `32` is the bar's reserved 32 plus the 8px gap.

## Two Hyprland behaviours worth knowing

**`centerwindow` needs no help.** It already preserves size *and* accounts for the
reserved area — it offsets by the bar rather than centring on the raw monitor. Centre is
therefore a bare dispatch with nothing computed.

**`resizeactive exact` on a floating window resizes around the window's own centre**,
not the screen's. That is the behaviour wanted for the Size ladder — stepping a size
should not relocate the window — but it means growing a window near an edge pushes it
off screen. Measured: a right-half window stepped one rung wider would have landed at
`x = 964` with its right edge at 2489, 193px past the usable area. So the floating
branch clamps back inside the usable rect, verified landing at `x = 771` instead.

## Not done

This is the cheap half of ADR-0021. Still outstanding there: a **Floating mode** that
can be toggled desktop-wide from the bar, and GNOME-style window buttons — the expensive
item, needing the `hyprbars` plugin via `hyprpm` and a rebuild against every Hyprland
release.

`general:snap`, Hyprland's snapping for *dragged* floating windows, was the cheap
companion to this and is now enabled — see ADR-0025. Note the vocabulary collision:
that is **Drag snap**, not the **Keyboard snap** in this ADR.

## Addendum: ported to quattro, 2026-08-09

**The scale rounding trap is gone, and the probe with it.** The trap existed because
`hyprctl monitors -j` rounds the scale (`1.67` for `1.666667`); quattro's Lua API
returns the true double, and `monitor.reserved` arrives as a named table instead of a
positional array. The usable area is now pure arithmetic, so the whole
ask-Hyprland-for-100%-once dance and its cache
(`~/.local/state/omarchy/hypr-logical-size`) are **deleted, not ported** — and with
`float-snap` and `window-resize` now removed (their raw `hyprctl dispatch` calls
stopped parsing when dispatch became Lua), the cache file is deleted too.

`float-snap` itself is ~30 lines of Lua in `~/.config/hypr/bindings.lua`. The
geometry, the ↑-fills asymmetry, resize-before-move and the bare `centerwindow`
dispatch all carried over unchanged.

Verified live at the machine's current 1.6 scale (2400×1600 logical; the bar now
reserves **26px**, not the `.conf` era's 32 — reading `reserved` at runtime is what
keeps this table from going stale again). Usable area `x0 8, y0 34, 2384×1558`:

| Action | Result |
|---|---|
| left | `(8,34) 1188×1558` |
| right | `(1204,34) 1188×1558` — right edge 2392, an 8px margin matching the left |
| fill | `(8,34) 2384×1558` |
| bottom half | `(8,817) 2384×775` |
| centre | size preserved, `y = 426` — clears the bar with nothing computed |

The Size ladder's floating branch and its edge clamp were re-verified alongside
(ADR-0022's addendum has the numbers).

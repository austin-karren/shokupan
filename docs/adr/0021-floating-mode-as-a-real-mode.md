---
status: rejected
---

# Make floating a real mode, toggleable from the bar

> **Rejected 2026-08-09.** See the decision at the bottom. The capability this ADR
> was really asking for exists and is in daily use; the *mode* is not being built.
> Everything below is kept as the reasoning that led there.

Intent: a **Floating mode** that can be toggled on and off from Waybar. While on, the
desktop behaves like macOS — windows keep their own size and position, can be
resized, snap to halves and edges, and carry GNOME-style window buttons. Toggling
back returns to tiling, which ignores the floating layout entirely.

> **Partly built, and the rest may not be wanted.** The placement half is done and lives
> in ADR-0024, with mouse resizing and Drag snap in ADR-0025: halves, fill, centre, the
> Size ladder and draggable borders all work now.
>
> **The case for the mode itself has weakened as a result.** Having used it, the reported
> position is that a Floating mode may not be needed at all — the desktop "feels more
> mature" without one. That is the expected outcome if the original ask was really about
> *capability* rather than *mode*: what was missing was the ability to place and size a
> floating window at all, and that is now present inside tiling.
>
> Do not build the mode without re-establishing what it would add. On current evidence
> that is only two things: making floating the *default* for new windows, and the
> GNOME-style buttons — which remain the expensive item. This ADR is likely to be
> rejected rather than implemented, and that should be recorded explicitly when decided.

Today `SUPER+T` is Hyprland's `togglefloating`, which floats one window and leaves it
at whatever size it already had. That is the whole of the floating story right now:
no resize bindings, no snapping, no centring.

## What the compositor already gives us

Probed on this machine (Hyprland 0.51-era, layout `dwindle`):

| Want | Mechanism | State |
|---|---|---|
| Centre a floating window, keeping size | `dispatch centerwindow` | **Exists.** Unbound. `SUPER+C` is free. |
| Snap while dragging | `general:snap:*` | **Exists.** `snap:enabled = 0` — off, not missing. |
| Resize a floating window | `dispatch resizeactive` | **Works.** Unbound — this is why sizes feel stuck. |
| Move a floating window | `dispatch moveactive` | Works. Unbound. |
| Half/full snapping | `resizeactive exact` + `moveactive exact` | Needs a script; see the trap below. |

So three of the four asks are bindings and one config flag, not new machinery. Those
three are now done — see ADR-0024, which also records the two traps that made them
more than one-liners: `exact` percentages are relative to the **monitor** rather than
the usable area, and `hyprctl` rounds the monitor scale so `width / scale` is several
pixels wrong.

## Toggling the mode

Hyprland has no "disable tiling" switch. The closest fit is a blanket window rule,
`windowrule = float, class:.*`, and the natural home for it is the mechanism this
system already has: a file in `~/.local/state/omarchy/toggles/hypr/`, which
`hyprland.conf` already sources and which
`single-window-aspect-ratio.conf` already uses for exactly this shape of thing. That
also makes the Waybar item close to free, and it shares the Toggle vocabulary already
in `CONTEXT.md`.

Two things that need settling:

- **Window rules only apply at window open.** Enabling the mode has to be followed by
  a one-shot pass that floats what is already on screen, or the toggle appears to do
  nothing until you open something.
- **Round-tripping the layout.** Hyprland remembers a window's floating geometry, so
  float → tile → float *may* restore cleanly. Unverified. If it does not, the mode
  needs to store geometry itself, which is a large step up in complexity.

## GNOME-style window buttons are the expensive part

This is the one ask with no cheap path, and it should be decided separately from the
rest rather than sinking them.

Hyprland has **no server-side decorations at all**. The only realistic route is the
`hyprbars` plugin, which means `hyprpm` — and `hyprpm` plugins must be rebuilt
against each Hyprland release. On a machine whose whole update story is
`omarchy update`, that is a standing breakage: an update can leave the bar gone or
Hyprland refusing to start. `hyprpm` is not even initialised here yet (its state
store needs a superuser step).

Worth asking whether the buttons are wanted for their own sake or as a hint that a
window is floating — because if it is the latter, a border colour rule is nearly
free and carries none of this risk. Keeping them hidden in tiling mode, as now, is
not the hard part; having them at all is.

## What the decision depends on

- Whether **Floating mode** is per-workspace or global. Per-workspace is more useful
  (one scratch space for floating work) and matches how the Calendar special
  workspace already behaves (ADR-0006); global is what "toggle in the bar" implies.
- Interaction with the **single-window zen aspect ratio** (ADR-0013, ADR-0026, glossary). `single_window_aspect_ratio`
  only applies to a lone *tiled* window, so it silently stops mattering in Floating
  mode. Two toggles on the bar where one quietly disables the other needs a decision,
  not a surprise.
- Whether `SUPER+T` survives. If a whole mode exists, floating one window inside
  tiling mode may stop being useful — or become the more common action.

## Decision: rejected, 2026-08-09

The ADR above asked for this to be re-established before building, and predicted its own
rejection. Both halves held up, so this records it explicitly rather than leaving a
proposed ADR for something nobody intends to build.

**The ask was about capability, not about a mode.** What was missing was any way to place
or size a floating window at all. That is done and has been in daily use since ADR-0024
and ADR-0025: halves, fill, centre, the Size ladder, draggable borders and Drag snap all
work *inside tiling*, with no mode to enter or leave. The reported position after using
it is that the desktop feels more mature without a mode, which is the outcome the ADR
above expected if the diagnosis was right.

That left the two things a mode would still have added, and quattro (ADR-0033) has since
moved both:

- **Floating as the default for new windows.** Still not wanted. It is also the half with
  the unsolved problem the ADR flagged and never answered — round-tripping the layout,
  since window rules only apply at window open, so the mode needs a one-shot pass over
  existing windows *and* somewhere to keep geometry if float → tile → float does not
  restore cleanly. That is a large step up in complexity for the least-wanted half.
- **GNOME-style window buttons.** Unchanged and still the expensive item: Hyprland has no
  server-side decorations, so the only route is `hyprbars` via `hyprpm`, rebuilt against
  every Hyprland release. On a machine whose update story is one command, that is a
  standing breakage. Quattro makes this *worse*, not better — it is package-backed now
  (ADR-0033), so Hyprland moves when the package moves.

Quattro also narrowed what a mode would be for. `SUPER+O` (`omarchy-hyprland-window-pop`)
floats **and** pins a window at a set size natively, which covers the "get one window out
of the layout and keep it there" case that was part of the original motivation.

**Consequences of rejecting:**

- `SUPER+T` survives unchanged as Hyprland's `togglefloating` — the question of whether it
  stops being useful was contingent on the mode existing, so it lapses.
- The **Floating mode** entry in `CONTEXT.md` stays, marked rejected. It is still worth a
  glossary line precisely because the term is ambiguous — it needs to keep pointing at
  the distinction from floating a single window with `SUPER+T`, which does exist.
- The interaction this ADR worried about — a Floating mode silently disabling the
  single-window zen aspect ratio (ADR-0013/0026), since `single_window_aspect_ratio` only
  applies to a lone *tiled* window — does not arise. Two bar toggles where one quietly
  disables the other was a real trap and it is now avoided by not building the toggle.
- If floating-as-default is ever wanted again, it should be a **new** ADR against
  quattro's Lua API, not a revival of this one. `hl.window_rule` and `hl.get_windows()`
  make the one-shot pass over existing windows tractable in a way the `.conf` era did not,
  so the cost analysis above would need redoing rather than inheriting.

ADR-0024 and ADR-0025 are unaffected — they were always independent of this, and this ADR
is not their parent despite having proposed them first.

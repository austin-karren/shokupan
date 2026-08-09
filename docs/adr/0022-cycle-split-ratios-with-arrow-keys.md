---
status: accepted
---

# Cycle window sizes along a ladder with arrow keys

`SUPER+ALT` plus an arrow steps the focused window through a **Size ladder** of
`1/3, 1/2, 2/3` of the screen. Left/right act on width, up/down on height. Implemented
as [`window-resize`](../../.local/bin/window-resize).

The key's direction is spatial, but it names **where the shared edge goes, not whether
the window grows**.

A tiled window has exactly one movable edge — the one it shares with its neighbour —
and which edge that is depends on which side of the split it sits on. The left-hand
window shares its *right* edge; the right-hand window shares its *left*. So "right
widens" can only ever be true for one of them. On the right-hand window it drags the
shared edge leftwards, growing the window in the opposite direction to the key, which
is what made the binding feel wrong from that side.

So the ladder runs in the opposite order for the second child of a split. `RIGHT` moves
the divider right whichever window is focused — widening the left one, narrowing the
right one. Two consequences worth having: the gesture matches dragging that border with
a mouse, and the two windows either side of a split answer the same key identically
instead of fighting over it. Vertically the same argument applies — a bottom window's
shared edge is its top, so `DOWN` pushes that edge down and shrinks it.

**Floating windows are the exception.** They have no shared edge and resize about their
own centre, so there left/up shrink and right/down grow unconditionally. That is the
one place the same chord means two different things, and it is unavoidable: the rule
above is defined by a boundary that a floating window does not have.

This is also why the bindings are labelled `Resize left/right/up/down` rather than
`Wider`/`Narrower` — no single one of those words is true for both sides of a split.

Tiled and floating windows share the ladder and the keys but almost no machinery, and
the asymmetry is worth stating because it is the reverse of what the file sizes suggest.
A tiled window has **no size of its own** — it holds a share of a split, so resizing it
means moving a boundary, which is where everything below comes from. A floating window
owns its geometry and can simply be told what size to be, so that branch is a dozen
lines. Everything that follows concerns the tiled case.

## Neither Hyprland primitive does this on its own

This is the substance of the ADR, because the obvious one-liner does not work and the
reasons are not documented anywhere obvious. Measured on this machine:

**`layoutmsg splitratio` is delta-only.** `exact` is rejected outright with
`failed to parse "exact" as a delta`. Its scale is 0–2 where `1.0` is a 50/50 split,
so a child's fraction is `ratio / 2`.

**Neither primitive is relative to the focused window.** A positive delta always grows
the **first** child of the split, whichever window has focus:

    focus left  window, resizeactive +200  ->  left  window 1136 -> 1336  (grew)
    focus right window, resizeactive +200  ->  right window 1136 ->  936  (shrank)

`layoutmsg splitratio +0.2` behaves identically. So the correct sign depends on which
side of the boundary the focused window is on, and **Hyprland does not expose the
dwindle tree through `hyprctl`** — there is no way to simply ask.

**`resizeactive exact` is not a way out.** It computes its own delta internally and so
inherits the inversion. On a second child, asking for `33%` produces `67%`.

**And the delta is bounds-checked against the wrong thing.** Hyprland validates the
request against the focused window's own size but applies it to the boundary inverted.
Growing a 766px second child by 767px means requesting `-767`, which is rejected
because `766 - 767 < 0` — so a second child can only grow by roughly its own current
size per call, and larger moves must be chunked.

**The two primitives fail in complementary ways on axis.** `splitratio` acts on the
immediate parent split, so pressing *left* on a vertically stacked window changes its
*height*. `resizeactive` walks up to the nearest ancestor with the matching
orientation and gets the axis right. That is why the implementation uses
`resizeactive` despite the clamping, and why a horizontal key on a stacked window
correctly resizes the whole column instead of doing something vertical.

## How the sign is resolved

Guess geometrically, then verify and correct. The guess is "a tiled window abuts my
low edge, so I am the second child", which is right for two windows, a 2x2 grid, and
one window beside a stack — and wrong only for a window in the middle of a nested run
of columns. Rather than reconstruct the tree to catch that, the move is measured and
the sign flipped once if the window travelled away from the target.

The same loop absorbs the chunking requirement from the bounds check. Ordinary
layouts settle in one dispatch; awkward ones take two or three. Measured at ~96ms per
keypress.

**That one guess now decides two things**, and only one of them is self-correcting.
The sign is verified by measurement and flipped if the window moved the wrong way; the
ladder *direction* is chosen before any dispatch and is not revisited. So in the case
the guess gets wrong — a window in the middle of a nested run of columns — the window
still lands exactly on a rung, but potentially the rung on the other side of where it
started. That is an acceptable trade rather than an oversight: a window with neighbours
on *both* sides has two shared edges, so "which way does my edge go" has no single
right answer to recover, and reconstructing the dwindle tree to guess better is the
work this whole approach exists to avoid.

## Window count is the wrong invariant

The rule first proposed was: *an odd number of windows affects multiple sibling
windows; an even number affects one sibling, because there is no conflicting grid.*
This should not be built, because dwindle is a binary tree and the count of windows
says nothing about the tree's shape. Two counter-examples, both trivially reachable:

- **Four windows**, as one on the left and three stacked on the right. Focus the left
  one and resize: all three right-hand windows move. Even count, multiple siblings.
- **Three windows**, as three columns. Focus the middle one and resize leftward: only
  the left neighbour moves. Odd count, one sibling.

The rule is broken in both directions, and the same window count can produce either
outcome depending only on the order the windows were opened.

**What actually decides it is the parent split**, and a binary tree has exactly two
sides: the focused window's side, and everything else. So the question the original
design treats as hardest — "what about 3 windows? what about 4?" — does not need
answering. Nothing is enumerated, no special case is written, and the reported
behaviour for the 1-left/2-right case is what `splitratio` already does unaided.

This is the rare case where the correct design is *smaller* than the proposed one.

## The traversal is a wrapping carousel

The arrows cycle a **list**, they do not mean "grow" and "shrink" directly. Left
traverses the list one way, right the other. Read that way, the sequence originally
described for the left arrow — `1/3`, then `2/3`, then `1/2` — is a descending
traversal **with a wrap**, not an arbitrary order:

    left  from 1/2:   1/3  ->  (wrap)  2/3  ->  1/2  ->  1/3 ...
    right from 1/2:   2/3  ->  (wrap)  1/3  ->  1/2  ->  2/3 ...

Each key keeps exactly one meaning — one step down the ladder, or one step up — and
the apparent reversal is only the wrap becoming visible. This is **not** the
inverted-controls objection from ADR-0017; that was about a consistent mapping
pointing the wrong way, and this mapping is consistent and points the right way.

Still to choose:

- **Wrap or clamp.** Wrapping reaches every size from a single key, which is worth
  real ergonomic money, and with three rungs the wrap costs at most two extra
  presses. Clamping never surprises anyone but requires both keys to move freely.
  Current preference: wrap.
- **Off-ladder starting positions.** A border dragged with the mouse leaves the split
  at something like 0.42, where an index-based carousel has no current position to
  advance from. Snapping to the nearest rung **in the direction of travel** answers
  this and composes with wrapping unchanged.
- **How many rungs.** Three keeps the wrap cheap. A fourth or fifth value makes
  wrapping progressively more annoying and starts to argue for clamping instead, so
  the two choices are not independent.

## Verified behaviour

Exercised against throwaway windows in every layout that matters:

| Case | Result |
|---|---|
| Two windows, focus first child, wrap | `0.494 → 1/3 → 2/3 → 1/2 → 1/3` |
| Two windows, focus second child, wrap | `0.655 → 1/2 → 1/3 → 2/3 → 1/2` |
| Clamp mode, five presses each way | Stops at `1/3` and at `2/3` |
| One left + two stacked right, width from a stacked window | `0.321 → 0.667`, widths `1533/739/739 → 739/1533/1533` — the whole column moved |
| Height ladder on a stacked window | `0.490 → 0.666 → 0.500` |
| Horizontal key on a horizontally-split window | Height unchanged |
| Single tiled window | No-op, leaves the **single-window zen aspect ratio** alone |

The fourth row is the case the original design worried about, working with no
window-counting anywhere in the implementation.

### The shared edge follows the key

Measured separately when the ladder was flipped for second children. Two tiled
terminals at 50/50, widths in px, then a vertical pair:

| Focus | Key | Result | Divider |
|---|---|---|---|
| left window | `RIGHT` | left `1136 → 1536`, right `1136 → 736` | moved right |
| right window | `RIGHT` | right `1120 → 767`, left `→ 1505` | moved right |
| right window | `LEFT` | right `767 → 1152`, left `→ 1120` | moved left |
| bottom window | `DOWN` ×2 | bottom `1002 → 752 → 501` (2/3 → 1/2 → 1/3) | moved down |
| bottom window | `UP` ×2 | bottom `501 → 752 → 1002` | moved up |

The divider column is the point: it tracks the key in every row, regardless of which
window holds focus. Rows 2 and 3 are what changed — before this, both grew the right
window.

One measurement trap worth recording, because it cost a re-run: the first attempt at
the bottom-window case started from a window already sitting at `1/3`, so pressing
`DOWN` **wrapped** to `2/3` rather than shrinking, and read as a failure of the flip
when it was correct wrap behaviour (see the carousel section). Test the direction from
the middle of the ladder, not from an end.

## Keybinding

`SUPER+ALT` + arrows, per the modifier scheme in ADR-0023: two modifiers because it
acts on the window, `ALT` because it resizes rather than moves it.

It first shipped on `SUPER+CTRL+ALT`, the only arrow chord then free at both the
compositor and terminal levels — worth remembering when picking any future arrow
binding, because Hyprland claims `SUPER`, `SUPER+SHIFT` and `SUPER+SHIFT+ALT` arrows
while Ghostty claims `CTRL+SHIFT`, `CTRL+ALT` and `SUPER+CTRL+SHIFT` arrows for its own
tabs and splits. A chord chosen carelessly is either swallowed by the compositor or
collides inside the terminal. `SUPER+ALT` was freed deliberately instead.

Wrap/clamp is switched with `window-resize --toggle-mode`, which flag-files into
`~/.local/state/omarchy/toggles/` like Omarchy's own toggles. Deliberately not bound
to a key — it is an occasional A/B switch, and `SUPER+CTRL+ALT+R` was already taken.
It belongs in the Toggle Menu eventually (ADR-0013).

## Still open

- **Wrap versus clamp is not settled.** Both are implemented so they can be compared
  in real use rather than argued about. Wrap is the default.
- **Naming.** This is a *Size ladder*, not a **Ratio** — the glossary gives "Ratio" to
  `single_window_aspect_ratio`, the lone-window 1:1 constraint. Two unrelated sizing
  features one word apart is exactly the collision `CONTEXT.md` exists to prevent.
- **Rung count interacts with wrap.** Three rungs keep wrapping cheap — at most two
  extra presses. A fourth or fifth value makes wrapping progressively more annoying
  and argues for clamping, so the two are not independent decisions.
- **Nested splits are approximate.** Rungs are fractions of the *screen*, but a
  deeply nested window's parent container is smaller, so a third of the screen may be
  unreachable. The loop clamps harmlessly rather than oscillating, but the landing
  will not be a true third.
- **Interaction with Floating mode** (ADR-0021): meaningless for floating windows,
  which want half/edge snapping instead. Two sizing gestures for two modes, possibly
  on the same keys.

## Addendum: ported to quattro, 2026-08-09

`window-resize` is now Lua inside `~/.config/hypr/bindings.lua`, running in the
compositor's own VM. **The central problem survives intact**: quattro's API still does
not expose the dwindle tree (`window.layout` is `{ name = "dwindle" }` and nothing
else), so the sign guess, the wrong-window bounds check and the convergence loop all
ported as logic, not as syntax. Confirming evidence that this is simply how it has to
be done: quattro's own `omarchy-hyprland-window-width` contains the identical
probe-then-converge loop.

What did change:

- **Dispatches are synchronous in-process** — a resize is applied and measurable on
  the next Lua line (measured: 1184 → 1084 with no wait). Every `settle` delay is
  deleted and the ~96ms per keypress is gone; the loop converges in microseconds.
- **The logical-size problem is gone**: `monitor.scale` is the true double and
  `monitor.reserved` is a named table, so the usable area is pure arithmetic. The
  `hypr-logical-size` probe cache is deleted, not ported (see ADR-0024's addendum).
- Wrap/clamp reads the **same flag file**, so `window-resize --toggle-mode` still
  switches it until the script is retired (quattrotools owns the `~/.local/bin` sweep).

Verification re-run under quattro (usable area 2384×1558 at the current 1.6 scale),
driving the live handler from `hyprctl repl`:

| Case | Result |
|---|---|
| Two windows, focus first child, `RIGHT` | `1184/1184 → 1589/779` — divider right, 2/3 exact |
| Focus second child at 1/3, `RIGHT` | wrapped to 2/3 — and was briefly misread as a failure, *again*; the warning below stands |
| Vertical pair, bottom window `DOWN`, `UP`, `UP` | `771 → 519 → 779 → 1038` (1/2, 1/3, 1/2, 2/3), divider tracking the key |
| Horizontal key on a vertical pair | heights unchanged |
| Floating, `LEFT` from fill | `2384 → 1589 → 1192 → 794`, every rung exact, position held |
| Floating at the right edge, grow | clamped to `x = 803 = 2392 − 1589`, nothing off screen |
| **Special workspace** (scratchpad) | rungs are fractions of the *monitor's* usable area, and the scratchpad's box is smaller — some rungs are unreachable and the loop stops after one refused flip, harmlessly. Same class as the nested-splits approximation above; not worth special-casing. |

The measurement trap from the original table struck again during this port's testing:
a rung at the end of the ladder wraps, and the wrap reads as "the key went the wrong
way" unless the test starts mid-ladder. It cost a re-run in the `.conf` era and nearly
cost one here. Test from 1/2.

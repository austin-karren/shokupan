---
status: accepted
---

# Arrow-key modifiers encode what you are acting on

The rule for every arrow binding:

| Modifier | Meaning | Bindings |
|---|---|---|
| `SUPER` | Navigate — change focus, change nothing else | Focus left/right/up/down |
| `SUPER+SHIFT` | Act on the window — move it | Swap window in that direction |
| `SUPER+ALT` | Act on the window — resize it | Size ladder (ADR-0022) |
| `SUPER+CTRL` | Leave the window — move between workspaces | Previous/next workspace |
| `SUPER+SHIFT+ALT` | Move a whole workspace to another monitor | Omarchy default |

Modifier **count** carries intensity, the **letter** carries the axis of what is being
changed. One unmodified pass changes nothing; two modifiers touch the window; `CTRL`
means you have left the window entirely.

## Why not strict "more modifiers = further out"

The tempting rule is to sort purely by scope, which would put workspace switching —
the outermost thing arrows do — on three modifiers, and window resizing on two. Sorted
by modifier count, the layout before this change broke that rule in exactly two
places: workspace switching sat at two modifiers, and resizing at three.

Strict scope ordering was rejected because **frequency has to outrank tidiness**.
Workspace switching is the most-used arrow gesture here, and it exists specifically to
reproduce macOS Spaces, where it is a *two*-key chord (`ctrl` + arrow). Promoting it
to a four-key chord to satisfy a naming scheme would undermine the reason the binding
was created. Resizing to a specific third, by contrast, is something done once while
arranging a layout and then left alone.

So the scheme keeps the cheap chord on the frequent action and distinguishes scope by
which modifier is held rather than how many.

## What this cost

`SUPER+ALT`+arrows previously ran `moveintogroup` — Hyprland window groups, a tabbed
container. Those bindings are gone.

The judgement that this is free rather than a loss rests on evidence, not preference:
`CTRL+SUPER`+left/right, which was `changegroupactive` (cycling tabs *within* a group),
had already been unbound to make room for workspace switching. Nothing in use was lost.

To be precise, though — groups are **not** fully dismantled, and an earlier version of
this ADR overstated it by saying they were unusable. `SUPER+G` still toggles grouping and
`SUPER+ALT`+scroll still cycles a group. So groups remain reachable, just without arrow
navigation. That scroll binding is left alone deliberately: removing it is a separate
decision about whether groups are wanted at all, and ADR-0025 declines to reuse it.

If groups are ever wanted, they should come back on a three-modifier chord, since
they are window-structural rather than navigational.

## Consequences

- **`SUPER+CTRL+ALT`+arrows is now free**, and is the natural home for floating-window
  snapping and centring (ADR-0021) — floating placement is a different mode, not a
  different intensity, so it earns its own modifier set rather than displacing one of
  these.
- **`SUPER+J` remains an inconsistency.** `layoutmsg togglesplit` is a structural
  change to the layout on a *single* modifier, where every other layout operation
  needs two, and "J" is vim vocabulary that does not mean "toggle" even in vim.
  Deliberately left alone: it is an Omarchy default, so changing it means another
  `unbind` and further divergence, and a bare key is genuinely fast while arranging
  windows. Worth revisiting only if the window-shaping family moves as a group.
- Every binding here uses `bindd`, not `bind`. The `SUPER+K` keybindings menu is
  generated live from `hyprctl binds` and lists only entries that carry a description,
  so a plain `bind` is invisible in it. That is the only reason the menu needs no
  maintenance when bindings change.
- Still unbound and arguably worth keys later: `layoutmsg swapsplit` (swap the two
  sides of a split — the companion to `togglesplit`) and `pin` (keep a floating window
  above others across workspaces).

## Addendum: ported to quattro, 2026-08-09

The scheme survives unchanged, and so — remarkably — did its collisions: quattro binds
the same two group chords in the same two places (`SUPER+CTRL+←/→` group focus cycling,
`SUPER+ALT`+arrows move-into-group), so the same two unbinds resolve them for the same
reason. Groups keep `SUPER+G`, `SUPER+ALT+G`, `SUPER+ALT+TAB` and the scroll binds, so
they remain reachable without arrows, exactly as before.

`SUPER+CTRL+ALT`+arrows was still free under quattro's defaults — measured before
anything was changed — so ADR-0024's floating placement kept its modifier set without a
fight.

The `bindd`-visibility point translates: `o.bind`'s description argument is what the
`SUPER+K` keybindings menu lists, so the discipline is unchanged in substance —
a bind without a description is invisible in the menu.

One quattro default worth noting fell to this file on the same day: `SUPER+ALT+RETURN`
was upstream's tmux chord (`omarchy-launch-terminal-tmux`), dead since herdr replaced
tmux (ADR-0015). Rebound to open the terminal running herdr — same chord, same grammar,
the ALT variant of the terminal key means "terminal with the multiplexer in it".

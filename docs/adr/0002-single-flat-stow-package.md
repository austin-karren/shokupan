---
status: accepted
---

# One flat Stow package per tree, adopted in place

Each self-stowing tree is a single Stow package whose paths mirror `$HOME`
directly, rather than the conventional per-application packages (`stow hypr
waybar zed`). There is exactly one machine and one profile to install, so
per-package granularity would buy selective installation nobody needs while
making every path one level deeper.

Installation uses `stow --adopt`, which pulls the live files into the repo and
replaces them with symlinks — the only way to onboard a machine that was
already configured before the repo existed.

*Amended 2026-08-19: the claim was originally "one flat Stow package",
singular, written when this repo was the only tree. It is now one flat package
**per tree**. The flat-path layout, the `--adopt` onboarding, the `git diff`
warning and "link files, not directories" all still hold, unchanged, for every
tree — which is why this is an amendment and not a supersession.*

## There are three self-stowing trees

| Tree | Owns | Needs |
|---|---|---|
| `shokupan` | the Linux rice — Hyprland, terminals, themes | Omarchy |
| `claude-config` | agent config | nothing |
| `crumb` | dev config that travels — shell, git, mise, Zed | no desktop at all |

Each stows itself. `loaf` manages only the rice; it has no authority over the
other two and does not check them.

## Consequences

`--adopt` resolves conflicts by **overwriting the repo copy with the live
file**, silently. A `git diff` immediately after stowing is not optional; it is
the only place a wrong-direction adoption becomes visible.

**Two trees must never track the same `$HOME` path.** This hazard is created by
the amendment above: with one tree, a path was owned or it was not. With three,
the same path can be claimed twice, and `--adopt` picks a winner silently — the
loser's copy is overwritten with whatever the winner left on disk, and no tool
reports it. Nothing enforces this partition today; it is a convention held by
hand. Zed is the case that already went wrong (see below).

~~Kept as a separate repo from the macOS dotfiles rather than sharing one with
host detection: the two platforms overlap on almost nothing but `.gitconfig`,
and the shell differs (bash here, zsh there).~~

*Superseded 2026-08-19 by crumb ADR-0002.* Half the overlap reasoning is
stale. Zed was tracked in **both** trees and the two copies diverged — proof
that the platforms overlap on more than `.gitconfig`, and the concrete instance
of the collision hazard above. crumb ADR-0002 re-examines this and keeps the
separation anyway, on the half of the premise that still holds: the shells
genuinely differ, so unifying the two small JSON files that actually overlap
would mean introducing host detection to serve them alone. The config that
travels now lives in `crumb`. Kept here struck through rather than deleted
because the reasoning's history is why `crumb` exists.

**Verified under quattro, 2026-08-09.** The decision survives the upgrade
unchanged: Omarchy moving from a checkout to packages
(omarchy-desktop-on-cachyos ADR-0035) changed what sits *under* the rice, not
how the rice installs. `stow --simulate --no-folding .` runs clean apart from
the three files the upgrade overwrote (tracked in the migration doc) — the
package layout itself needed nothing. One caution recorded since: `loaf doctor`
tests each tracked path with `[[ -L ]]`, so a *directory* symlink makes every
file under it read as clobbered — link files, not directories
(shokupan-plugins ADR-0013 has the incident).

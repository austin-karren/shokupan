---
status: accepted
---

# herdr's config lives in shokupan, as a plain tracked file

`~/.config/herdr/config.toml` existed only on this machine — load-bearing for
the whole working day, in no repo, one `omarchy refresh herdr` away from being
silently replaced. It is now tracked as `.config/herdr/config.toml` in this
repo's stow tree, verified byte-identical to the live file at the time of
tracking.

## Which repo

`shokupan`, not `crumb`. Both are legitimate on remit grounds — herdr's
`name = "terminal"` theme setting references no Omarchy path, so it would
satisfy `crumb`'s desktop-agnostic `.bashrc` constraint — but the decisive
reason is that `.config/tmux/tmux.conf` already lives here, and shokupan
ADR-0015 is the record of *why* the two multiplexers must never fight over a
prefix. Splitting the configs across repos would hide that invariant from
whichever one doesn't carry the ADR. Secondary support: Omarchy now installs
`herdr` itself as a base package (`omarchy-base.packages:53`, `pacman -Q herdr`
→ `herdr 0.8.0.r13-1`), so the desktop layer owning it is `shokupan`'s remit —
this **updates ADR-0015**, which described herdr as "a static binary in
`~/.local/bin`... not by pacman"; that was true when written and is no longer
true under quattro. shokupan ADR-0002 forbids two stow trees tracking the same
`$HOME` path; `crumb` was checked and tracks no `.config/herdr/` path, so there
is no collision to resolve either way.

## Why not the `forks` manifest

`packages/forks` (ADR-0042) records exactly two relationships to an upstream
file: a **fork** (`rice_path` is a copy of `upstream_path`; drift means re-diff
and carry the change across) or a **watch** (`rice_path` loads or wraps
`upstream_path` in place). `~/.config/herdr/config.toml` is neither. It is a
deliberately smaller, independent file that does not copy or load
`/usr/share/omarchy/config/herdr/config.toml` — full adoption of that template
would move `prefix` from `ctrl+s` to `ctrl+space`, colliding with the tracked
tmux prefix (`C-Space`, ADR-0015), turn sounds back on, and drop
`confirm_close`. Recording it as a `fork` would stamp a sha implying a copy
relationship that isn't there, and would send a future `loaf forks --record`
into a re-diff with no correct answer. There is nothing to watch either: no
code here loads upstream's file at all.

## Why a plain tracked file is enough

The hazard this file actually faces is not upstream's *template* changing
shape — it is `omarchy refresh herdr` (`omarchy-refresh-config
herdr/config.toml` then `omarchy-restart-herdr`) overwriting the live symlink
with a plain copy of that template, then live-reloading it in, in one shot.
`loaf doctor`'s Rice layer already detects exactly this shape of damage,
generically, for every tracked config: it walks `git ls-files` (minus
`REPO_ONLY`) and reports any tracked path whose `$LOAF_HOME` counterpart is a
real file instead of a symlink back to the repo (`✗ symlinks N replaced by real
files`). Tracking `.config/herdr/config.toml` here is sufficient by itself to
put it under that check — no new detection code, no forks entry, is needed.
`loaf doctor` now has something to say about this file purely as a side effect
of it being tracked at all.

The just-merged post-update hook (`.config/omarchy/hooks/post-update.d/20-forks-drift`)
is scoped to `loaf-forks`' fork/watch ledger and does not need to learn about
this file for the same reason: the symlink-displacement check is not part of
that ledger, and doesn't need to be.

## Consequences

- `omarchy refresh herdr` remains destructive to `ctrl+s` and every other
  divergence from upstream's template. Tracking the file does not stop the
  overwrite from happening; it makes `loaf doctor` notice it happened, and
  `loaf heal` can then re-assert the tracked version by re-stowing.
- The `ctrl+s` / `C-Space` non-collision (shokupan ADR-0015) is the consequence
  worth naming explicitly: any future full adoption of upstream's herdr
  template — by hand, or via `omarchy refresh herdr` followed by an unreflective
  `loaf heal` in the wrong direction — silently hands `ctrl+space` to herdr and
  breaks tmux's prefix the moment both are in use in the same pane tree. The
  fix is one line (`keys.prefix = "ctrl+s"`) and it must survive every future
  re-verification of this file against upstream's.
- ADR-0015's packaging claim about herdr ("stays outside the package
  manifest... not by pacman") is stale under quattro and should be read
  superseded by this ADR's finding above; it is not otherwise amended here.

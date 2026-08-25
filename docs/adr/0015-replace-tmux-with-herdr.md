---
status: accepted
---

# Herdr for agents, tmux for everything else

Two multiplexers, split by job: **herdr** owns agent session management — it is
what hosts the daily Claude sessions, holds them across disconnects, and covers
the reach-it-from-the-MacBook case (`herdr --remote`, ADR-0016). **tmux** stays
for everything that is not an agent: ad-hoc long-running shells, the odd server
process, the muscle memory. The tracked 107-line `~/.config/tmux/tmux.conf`
stays with it.

> **Partially reverted 2026-08-09, by the user, same day it was accepted.** The
> first acceptance ("Replace tmux with herdr", below) removed tmux entirely,
> ratifying that no tmux server was running and nothing depended on the package.
> The user's correction: *"previously I got rid of tmux — leave it. We can have
> herdr for agents and tmux for everything else."* Zero usage over one
> observation window was survey data, not a decision — the removal read absence
> of current use as absence of want. tmux is reinstalled, `tmux.conf` is
> restored from history and re-stowed, and the split above is the standing
> decision.

## The boundary

- **Agent sessions** — anything a coding agent runs in, anything that must
  survive a disconnect *and* be findable by tooling — live in herdr. Its server
  model (`herdr` attaches or launches the persistent session,
  `herdr session attach <name>`) is the mechanism ADR-0016's remote workflow
  rides on.
- **Everything else** — a shell you want back tomorrow, a process started by
  hand — is tmux's, exactly what it has always been for. Prefix is `C-Space`
  (with `C-b` kept as prefix2), vi copy-mode, `M-Enter`/`M-S-Enter` splits; see
  the tracked config.
- Neither replaces Ghostty splits (ADR-0014) or Hyprland tiling. Four mechanisms
  can split a screen here; they divide by lifetime, not by geometry — WM and
  terminal splits die with the session, tmux and herdr survive it.

## What the first acceptance established, and what survives it

The observations were sound even though the conclusion overreached, so they are
kept:

- The **CSI-u keybinds** in Ghostty, Alacritty and foot were originally added
  *for* tmux but are load-bearing without it: they let any TUI distinguish
  `Shift+Enter` and `Alt+Shift+Enter` from plain `Enter`, which agent TUIs use.
  Their comments no longer credit tmux, and that stays true — they serve both
  multiplexers and neither.
- **herdr stays outside the package manifest**: it is a static binary in
  `~/.local/bin`, installed and updated by its own `herdr update` channel, not
  by pacman — the same reason the npx shims are untracked. tmux, by contrast, is
  a pacman package and belongs in `packages/chosen.packages`.
- `SUPER+ALT+RETURN` ran `tmux attach || tmux new -s Work` and was declared dead
  when tmux left; with tmux back it is merely *unported* — the binding lives in
  the Hyprland layer's `bindings.conf → .lua` work and should come back with it.

## Consequences

- `tmux` is a manifest package again (`packages/chosen.packages`), so
  `loaf doctor`'s manifest check fails until it is installed — which is the
  correct pressure, since the tracked config now points at it.
- A session's home is now a *choice*. The default is by kind — agents in herdr,
  hand-run work in tmux — and when in doubt, the question is "does tooling need
  to find this session?" Yes → herdr.
- The two configs never interact: herdr has its own state, tmux reads
  `~/.config/tmux/tmux.conf`. Nothing here needs to keep them in step.

## Addendum, 2026-08-15: upstream adopted herdr; the rebind retires

Upstream r1744 binds herdr natively — `SUPER+CTRL+RETURN` opens herdr,
`SUPER+ALT+RETURN` opens tmux (`default/hypr/bindings/applications.lua`). This
rice's `bindings.lua` rebind, which had pointed `SUPER+ALT+RETURN` at herdr
while quattro's default still targeted an uninstalled tmux, is deleted as
superseded-by-upstream: both stock bindings return, and with tmux reinstalled
(the partial revert above) each chord now opens a multiplexer that exists. The
user retrains to `SUPER+CTRL+RETURN` for herdr. The split itself — agents in
herdr, everything else in tmux — is unchanged and remains the standing decision.

## Addendum, 2026-08-25: herdr is package-backed; the manifest claim is stale

"What the first acceptance established" above says herdr "stays outside the
package manifest: it is a static binary in `~/.local/bin`, installed and
updated by its own `herdr update` channel, not by pacman." That is no longer
true under quattro. Omarchy now installs herdr as a base package: it appears
in `omarchy-base.packages`, and `pacman -Q herdr` reports `herdr
0.8.0.r13-1`. `herdr --version` reports `0.8.2` — the two strings differ
because one is the pacman package version and the other is the binary's own
version string; both are real, neither is wrong.

This was found and first recorded in shokupan ADR-0050, while tracking
herdr's config in this repo. That ADR is the record of *why* the two
multiplexers must never fight over a prefix, and its finding supersedes the
manifest claim above; nothing else in this ADR changes. This addendum exists
so the correction lives here too, not only in the newer ADR that noticed it.

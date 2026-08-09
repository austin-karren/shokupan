---
status: accepted
---

# Replace tmux with herdr

Drop tmux and use **herdr** for session management. The tracked 104-line
`~/.config/tmux/tmux.conf` goes with it.

> **Accepted 2026-08-09, mostly by observation.** The proposal below recorded an
> intent whose *how* was deliberately undecided, with a list of load-bearing
> questions. By the time anyone came back to grill it, the decision had made
> itself: herdr 0.8.0 is installed, its server is running, and it hosts this
> machine's daily agent sessions — while tmux had no server running, no reverse
> dependencies, and nothing but comments referencing it outside one keybind.
> Ratifying reality, the remaining tmux footprint was removed the same day.

## The questions the proposal left open, answered

- **Can it hold a session open across a disconnect?** Yes — this is herdr's
  model, not a feature: `herdr` "launches or attaches to the persistent
  session", `herdr session attach <name>` reattaches by name, and
  `herdr --remote <ssh-target>` exists specifically for the ADR-0016 case of
  reaching work on this machine from the MacBook. The entanglement with
  ADR-0016 resolves in herdr's favour rather than against it.
- **What in the tmux config was load-bearing?** Nothing, it turned out. The
  CSI-u keybinds in Ghostty, Alacritty and foot were added *for* tmux but are
  kept: they let any TUI distinguish Shift+Enter and Alt+Shift+Enter from plain
  Enter, which agent TUIs use. Their comments now say so instead of crediting
  tmux.
- **Overlap with ADR-0014 (Ghostty splits)?** Unchanged — Ghostty splits and
  Hyprland tiling remain, herdr adds agent-workspace panes. Three mechanisms
  became three again, but the one that was unused is the one that left.

## What was removed, measured first

- `tmux 3.7_b-1.1` uninstalled (`pacman -Rns`; `pactree -r` showed nothing
  depended on it, and no tmux server had been running). `packages.txt`
  regenerated.
- `.config/tmux/tmux.conf` deleted from the repo; the dangling symlink and its
  directory removed from `$HOME`.

## Left in place, deliberately

`SUPER+ALT+RETURN` in `.config/hypr/bindings.conf` still runs
`tmux attach || tmux new -s Work` and is now dead — pressing it opens a terminal
that exits immediately. That file is owned by the Hyprland layer's work stream
and was not edited here; the bind needs re-aiming (plausibly at `herdr`) or
deleting by whoever next touches the bindings.

herdr itself stays outside the package manifest: it is a static binary in
`~/.local/bin`, installed and updated by its own `herdr update` channel
mechanism, not by pacman — the same reason the npx shims are untracked.

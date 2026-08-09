---
status: accepted
---

# Decide the Ghostty split keybinds, and bind close_surface

> **Verified under quattro, 2026-08-09.** The decision needed nothing; the
> *symlink* did. The upgrade replaced `~/.config/ghostty/config` with a real
> file that was byte-identical to ours — the migration doc required a diff
> before restoring, the diff was empty, and the link is back (upstream's copy
> kept as `.displaced.<epoch>`). `ghostty +validate-config` passes and
> `+list-keybinds` shows both bindings live: `super+d=new_split:right`,
> `ctrl+shift+w=close_surface`. Ghostty is 1.3.1. One caveat inherited from the
> port: the `SUPER+W` forwarding this ADR defers to (ADR-0020) rides on the
> Hyprland bindings, which are still being relearned as Lua — until that lands,
> `ctrl+shift+w` is the direct route it always was.

Splits were unusable in practice: every process got its own window, and splits
happened by accident with no obvious way out of one. The cause was concrete and
worth recording, because it was a **missing** binding rather than a wrong one.

## Decided

Two bindings added to the tracked config:

| Keys | Action | Why |
|---|---|---|
| `super+d` | `new_split:right` | Muscle memory from macOS `cmd+d`. `SUPER+D` is free at the Hyprland level because lazydocker was moved to `SUPER SHIFT+D`, so it reaches the terminal. |
| `ctrl+shift+w` | `close_surface` | Overrides `close_tab:this`. One key for the whole ladder, matching macOS `cmd+w`. |

`close_surface` is the right action precisely because it escalates on its own —
Ghostty's docs: *"Close the current 'surface', whether that is a window, tab, split,
etc."* One key closes the smallest thing that is open:

    split  →  tab (when it is the last split)  →  window (when it is the last tab)

That is why this is a single binding rather than three, and why `close_tab` and
`close_window` stay unbound: both skip levels of that ladder.


Deliberately **not** bound:

- **`super+w`** (the literal macOS `cmd+w`) — Hyprland binds it to `killactive`, so
  it would kill the whole window before Ghostty saw it. `ctrl+shift+w` is the
  compromise, and it is the key that was already wrong, so nothing is lost.
  **Superseded in effect by ADR-0020**, which rebinds `SUPER+W` to a script that
  forwards `ctrl+shift+w` into Ghostty — so `super+d` / `super+w` now work as the
  macOS pair after all, with `ctrl+shift+w` still there as the direct binding.
- **`super+shift+d`** (the macOS down-split) — Hyprland binds it to lazydocker. Down
  splits stay on Ghostty's default `ctrl+shift+e`, so the two directions are
  asymmetric: one macOS-style, one Ghostty-style. Accepted rather than fixed,
  because moving lazydocker a second time to buy symmetry is not worth it.

The general rule this exposes: **Hyprland wins every `super` chord.** Any terminal
binding on `super` has to be checked against `hyprctl binds` first, or it silently
never fires.

## What the bindings were before

Ghostty's defaults, none of them overridden in `~/.config/ghostty/config`:

| Keys | Action |
|---|---|
| `ctrl+shift+o` | `new_split:right` |
| `ctrl+shift+e` | `new_split:down` |
| `ctrl+alt+←/↑/→/↓` | `goto_split:<dir>` |
| `super+ctrl+[` / `]` | `goto_split:previous` / `next` |
| `super+ctrl+shift+arrows` | `resize_split:<dir>,10` |
| `ctrl+shift+w` | **`close_tab:this`** |

The tracked config adds only `super+ctrl+shift+alt+arrows` for `resize_split:…,100`
— a coarser resize. It binds nothing for creating or closing.

**`close_surface` is not bound at all.** It exists as an action, but no default
key invokes it. `ctrl+shift+w` is `close_tab:this`, which closes the tab and every
split inside it — exactly the "can't close a pane without losing the whole window"
symptom. Binding `close_surface` is the fix, and it needs no new concepts.

Also unbound and relevant: `toggle_split_zoom` (temporarily fullscreen one pane)
and `equalize_splits`.

`confirm-close-surface = false` was already set, so `close_surface` takes effect
with no prompt. Fine for a pane; it also means `ctrl+shift+w` on the last pane
closes the window outright.

## Still open

- **The accidental splits.** `ctrl+shift+e` and `ctrl+shift+o` are still bound and
  still easy to hit reaching for `ctrl+shift+c`/`ctrl+shift+t`. Left alone for now on
  the theory that a pane you can close cheaply is a much smaller mistake — revisit
  only if it keeps happening now that `super+d` is the deliberate way in.
- **Splits versus tmux versus the window manager.** Three things here can split a
  screen: Ghostty, tmux (ADR-0015 proposes removing it), and Hyprland itself. Doing
  it in Ghostty means the WM cannot manage those panes and they do not survive
  detach. If multiplexing moves to a persistent session tool, Ghostty splits may not
  be wanted at all — in which case these two bindings become dead weight rather than
  wrong, which is why they did not need to wait on ADR-0015.
- `toggle_split_zoom` (`ctrl+shift+enter`) is a Ghostty default and already works;
  `equalize_splits` remains unbound.

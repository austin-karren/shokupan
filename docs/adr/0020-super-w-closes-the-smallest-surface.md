---
status: accepted
---

# SUPER+W closes the smallest surface, not the whole window

Omarchy binds `SUPER, W` to `killactive` (in
`default/hypr/bindings/tiling-v2.conf`) to give the desktop a macOS feel. The
binding is the right *key* and the wrong *action*, and the gap is structural rather
than a matter of taste.

`killactive` is a **compositor-level** close request. Hyprland knows about windows;
it has no idea a window contains three terminal splits, nine browser tabs or an
unsaved buffer. macOS `cmd+w` is **app-level**, which is why it can walk a ladder:

    pane  ->  tab (when it is the last pane)  ->  window (when it is the last tab)

Closing the window only when nothing smaller is left is the part that makes `cmd+w`
safe to hit reflexively. On Omarchy, the same reflex destroys a terminal full of
running processes.

## Decision

`SUPER, W` is unbound and rebound to [`close-surface`](../../.local/bin/close-surface),
which reads the focused window's class and retypes **that app's own**
close-smallest-unit shortcut into it via `sendshortcut`. The app then decides what
"close" means, because every app already implements the ladder — the compositor was
simply pre-empting it.

| Class | Sent | Why |
|---|---|---|
| `com.mitchellh.ghostty` | `CTRL+SHIFT+W` | `close_surface` (see ADR-0014) |
| `helium`, `dev.zed.Zed`, `org.gnome.*` | `CTRL+W` | Closes the innermost tab/document, escalates on its own |
| `chrome-*` | `CTRL+W` | Every `omarchy-launch-webapp` window |
| anything else | `killactive` | Unchanged behaviour |

`chrome-*` is worth calling out because it is easy to miss: `chromium --app` names
the window class **after the host, not after the browser** —
`chrome-chatgpt.com__-Profile_1`, not `helium`. So whitelisting the browser does not
cover the web apps, and every one of ChatGPT, Grok, hey Calendar and Email, YouTube,
X, WhatsApp, Messages and Photos needs the wildcard. Those windows have no tab
strip, so `ctrl+w` lands directly on the window rung — the same visible outcome as
`killactive`, but performed by the app rather than the compositor.

**There is no single universal keystroke, which is why this is a script and not a
one-line `sendshortcut` bind.** `CTRL+W` is very nearly the universal GUI answer,
but inside a terminal it is readline's `unix-word-rubout` — sending it to Ghostty
would silently eat a word off the command line and close nothing. That one
exception is the entire justification for the indirection.

## Whitelist, not blacklist

Only classes verified to implement the ladder get the keystroke; everything
unrecognised falls through to `killactive`.

The alternative — send `CTRL+W` to everything and treat `killactive` as the
exception — was rejected because the failure modes are wildly asymmetric. A wrong
guess in a whitelist costs nothing: the window closes the old way. A wrong guess in
a blacklist makes a window **silently unclosable** — the keystroke goes nowhere and
`SUPER+W` appears broken, with no feedback explaining why. Adding an app is one line;
debugging a dead close key is not.

The cost is real and accepted: **new apps do not get the good behaviour until they
are added to the list.** This is a maintenance burden, deliberately taken on because
the fallback is the previous, working behaviour rather than a broken one.

## How this relates to the Q keys

`CTRL+Q` was added earlier because Omarchy left app-level quit on each app's native
binding, so Omarchy apps and GNOME apps disagreed about how to close. That created
three close keys, which now divide cleanly along the axis both macOS and GNOME use —
**W closes the smallest unit, Q closes the whole thing**:

| Keys | Action | Meaning |
|---|---|---|
| `SUPER+W` | `close-surface` | Innermost pane/tab, else the window |
| `CTRL+Q` | `killactive` | Close this window |
| `SUPER+Q` | `sendshortcut CTRL+Q` | Ask the app to quit itself |
| `SUPER+SHIFT+Q` | `forcekillactive` | SIGKILL, last resort |

`CTRL+Q` and `SUPER+W` were previously the same action; they are now deliberately
different, and that difference is the point of this ADR.

Note the standing trade-off from the `CTRL+Q` bind is unchanged: a compositor-level
bind consumes the key before the app sees it, so no application can receive `CTRL+Q`
from the keyboard. `SUPER+Q` is the escape hatch.

## Verification

Tested end-to-end against a throwaway `ghostty --title=closetest`, driven by
`sendshortcut` with a title regex so no real window was involved:

1. split created — 1 window
2. first close — **still 1 window** (the split died, the window survived)
3. second close — 0 windows

Step 2 is the whole point. Under `killactive` it would have been 0.

A `chromium --app` window was verified separately, and exposed a limit of that
method: **`sendshortcut` at an unfocused window reaches Ghostty but not Chromium.**
The same `CTRL, W` that did nothing to an unfocused web app closed it immediately
once focused. This does not affect the binding, which always targets
`activewindow` — but it means the title-regex trick above cannot be used to test
future entries, and a "nothing happened" result from it proves nothing. Focus the
window first.

## Follow-ups

- **`~/.local/bin` is not tracked by this repo.** `close-surface` is the first script
  in it that a keybinding depends on, so it was added at `.local/bin/close-surface`.
  The rest (`quick-menu`, `waybar-watchdog`, `pin-wallpaper`, `calendar-toggle`,
  `window-toggle`, `menu-toggle`, `toggle-appearance`, `aether-theme`) are still
  machine-only, which means ADR-0005, ADR-0007 and ADR-0012 all document behaviour
  whose implementation would not survive a rebuild.
- Ghostty and `chrome-*` are observed. `helium`, `dev.zed.Zed` and `org.gnome.*` are
  on the list from documented `ctrl+w` behaviour, not from a run.
- **Apps not yet on the list**, each one line when wanted: `signal`, `obsidian`
  (has tabs, so a real ladder rung), `typora`, `spotify`, `1password`. Until then
  they get `killactive`, which is what they got before.

## Addendum: ported to quattro, 2026-08-09

The script is gone. `close-surface` is now ~40 lines of Lua inside
`~/.config/hypr/bindings.lua`, running in the compositor's own VM — the class comes
from `hl.get_active_window().class` instead of a `hyprctl | jq` round trip, and no
process is spawned per keypress. The whitelist, the fallback and the reasoning above
are unchanged. `.local/bin/close-surface` is deleted — confirmed unreachable from
any live binding or menu first, and doubly dead: quattro's `hyprctl dispatch` now
parses Lua, so the script's `dispatch sendshortcut` calls would fail even if
something still ran it.

Two things changed in substance rather than syntax:

**The ladder grew a rung below "pane": an open Omarchy shell popup.** Quattro's
menus, launcher and pickers are quickshell *layers*, not windows — `killactive`
never touched them, so the close reflex died precisely on the surfaces Omarchy
itself puts in front of you. All of `SUPER+W`, `CTRL+Q` and `SUPER+Q` now dismiss
an open transient `omarchy-*` layer first (via `omarchy-shell shell hide`, the same
call `omarchy-menu close` makes) and only then proceed to their window action.
Permanent layers — bar, background, OSD, notifications, lock — are excluded by
name, lock deliberately twice over.

**The keystroke injection inherited upstream's stuck-key fix.** The `.conf` era
used `sendshortcut`, which sometimes leaves the synthetic key stuck and repeating
(hyprwm/Hyprland#14099). Quattro's own Universal copy/paste works around it with
`send_key_state` down plus a 50ms timer up, and the port adopts that idiom — the
old script had the bug and did not know it.

The Q keys moved as spec'd: `CTRL+Q` → `hl.dsp.window.close()`, `SUPER+Q` retypes
`CTRL+Q`, `SUPER+SHIFT+Q` → `hl.dsp.window.kill()`.

### Verification, re-run under quattro

Nothing on this machine can synthesise a key press — `wtype`'s virtual keyboard
delivers nothing under this compositor (measured: a probe bind never fired and
typed text never arrived) and `ydotool` is not installed. So the handlers are
exposed as `shokupan.*` and driven from `hyprctl repl` — the *live closures the
binds hold*, not copies — with `hyprctl binds` covering the chord→handler wiring:

1. Throwaway `ghostty --title=closetest`, split created by retyping
   `CTRL+SHIFT+O`: first close — **still 1 window** (the split died); second
   close — 0. The step-2 result is the whole point; `killactive` would give 0.
2. Omarchy Menu open: close dismissed the menu layer (1 → 0) with window count
   untouched (5 → 5). Same for the Launcher.
3. `retype("CTRL", "Q")` at a focused `gnome-calculator`: the app quit — which
   also exercises the `org.gnome.*` whitelist arm end-to-end.
4. `window.close()` and `window.kill()` each took a throwaway window.

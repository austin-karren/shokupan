---
status: proposed
---

# Retune the idle chain, and keep the machine reachable

Two goals: the screensaver arrives too soon, and the gap before locking should be
much longer. Separately, this machine needs to stay reachable and keep long-running
processes (Claude, Vite dev servers) alive for the remote workflow in ADR-0016.

## Re-based onto quattro, 2026-08-09

Everything below the standing requirement was written against hypridle, which the
upgrade uninstalled (hyprlock too — `~/.config/hypr/hypridle.conf` is still on
disk and now inert). The idle chain is quattro's quickshell service plugin, and
the knobs are two keys in `.config/omarchy/shell.json`:

```json
"idle": { "screensaver": 150, "lock": 300 }
```

Measured in `plugins/services/idle/Service.qml`:

- **The timers are independent and absolute** — both are seconds since idle
  began, not a chain. `lock: 300` means lock at 300s, full stop. The hypridle
  trap this ADR documented (launching the screensaver reset the idle timer, so
  the second number silently meant "after the screensaver") is gone, and with it
  the "re-measure after any change" caveat.
- **Current values reproduce the old behaviour.** 150/300 are also the plugin's
  own defaults, and land within seconds of the old effective 150s/≈302s. So the
  retune this ADR wants has *not* happened yet — the numbers just moved house.
- **No idle suspend exists**, same as before: the service knows screensaver and
  lock, and nothing else. `grep suspend` over the idle plugin comes back empty.
- **Display-off now exists**, answering an open question below: 5 seconds after
  the lock engages, the lock plugin runs `omarchy-brightness-display off` (and
  keyboard backlight off), waking on interaction. The screensaver itself still
  keeps the display lit.
- **A stay-awake toggle is native** (`~/.local/state/omarchy/indicators/stay-awake`
  disables the whole chain), which is what `omarchy update` flips on while it
  runs.

## Sanity check: nothing is killing your background processes

The belief that idle behaviour kills background processes did not hold up under
hypridle and still does not: nothing auto-suspends this machine, locking is a
fullscreen surface with no relationship to process lifetime, and the one suspend
on record was manual (bedtime, not idle). What genuinely breaks across a suspend
is **network state, not processes** — open sockets die, HMR websockets drop. And
while suspended the machine is unreachable, which is the real conflict with
ADR-0016 — an argument for never suspending rather than for changing timings.

So the timings are worth changing because 2.5 minutes is annoying, not because
anything is being lost.

## Standing requirement

The machine must stay usable from away over SSH, with long-running processes
still alive. That is a fixed requirement for anything decided here, not an open
question — so no change may introduce an idle suspend. Verified to hold under
quattro (no suspend listener anywhere in the idle plugin), and now backed by an
actual remote path: Tailscale SSH is enabled (ADR-0016).

## Still to settle

- **The two numbers.** "Slightly too fast" and "much longer" still need actual
  values; under the new semantics they are trivially expressible — e.g.
  `screensaver: 300, lock: 1800` reads exactly as it behaves. They live in
  `shell.json`, which is hot-reloaded, so trying values costs nothing.
- **Whether to lock on idle at all**, given the remote goal. A machine you SSH
  into does not benefit from its local screen locking — but it is a physical
  desktop, so this is a security decision, not a technical one.
- **Whether to remove Sleep from the menu.** Suspend and hibernate remain the
  only things that make this machine unreachable, and both are still offered.
- ~~Whether display-off should exist~~ — it does now, attached to the lock
  rather than the screensaver. Whether the screensaver *itself* should ever
  blank the display is a smaller question and probably answered by "no, that is
  what the lock stage is for".

---
status: superseded
---

# The audio TUI opens on Output Devices

> **Superseded by quattro's native behaviour, 2026-08-09.** The addendum below
> left one question open — whether `omarchy.audio` has an equivalent of "start
> on Output" — and the answer, measured in the plugin rather than assumed, is
> that it *is* the default. `plugins/panels/audio/Panel.qml` builds its section
> list with `output` first and always visible (`input` and `streams` only appear
> when they have content), and focus lands on the first section. The question
> this ADR fought for — *which device is the sound coming out of* — is the
> panel's opening screen by construction, with nothing to configure and no file
> to own. The rice carries nothing for this any more; the sections below stay as
> the record of why the preference mattered and what adopting the config file
> cost.

> **Implementation deleted 2026-08-09.** `wiremix` is uninstalled — the
> upgrade itself does `rm -rf ~/.config/wiremix` — and `wiremix.toml` is
> deleted with it. omarchy-desktop-on-cachyos ADR-0033 replaces the TUI with
> `omarchy.audio`, so the open question is whether that surface has an
> equivalent of "start on Output", not how to set `tab`. Old file: tag
> `omarchy-v3.8.4-prequattro`.

wiremix starts on the Output Devices tab instead of Playback. One line of config:

```toml
tab = "output"
```

The question that sends you to this TUI is nearly always *which device is the sound
coming out of* — speakers, the monitor over HDMI, bluetooth earbuds. That is the
Output tab. Playback lists per-application streams, which is the rarer question and
one keypress away on F1.

## Why config and not a flag

The Waybar headphones icon is the usual way in, and `on-click` could just as easily
have been `wiremix -v output`. It isn't, because the Omarchy menu's audio entry and
any future keybind go through the same binary and would keep landing on Playback.
"Default tab" should mean the default everywhere, so it belongs in wiremix's own
config.

## Why the file had to be adopted first

`~/.config/wiremix/wiremix.toml` already existed and was **byte-identical to
Omarchy's** `config/wiremix/wiremix.toml`, as an untracked regular file. Editing
it in place would have worked until the next `omarchy update` rewrote it — the
exact displacement failure omarchy-desktop-on-cachyos ADR-0028 exists to catch,
and one that leaves no trace in `git status` because the file was never ours.

So it moved into the rice as a tracked file and is now stowed like everything else,
which is what makes the single line above durable. Everything in it except `tab` is
still Omarchy's, and the header comment says so, because a future reader diffing
against upstream should be able to see at a glance which line is the deviation.

## Consequences

The rice now owns a file it barely modifies, so it will not pick up improvements
Omarchy makes to the rest of that config. `loaf doctor` cannot help here — it checks
that tracked files are symlinks to the repo, not whether the repo's copy has drifted
behind an upstream default it was forked from. The mitigation is the header comment
and the upstream URL already in the file, not a check.

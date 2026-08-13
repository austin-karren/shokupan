# Shokupan

My rice: one CachyOS machine running [Omarchy](https://omarchy.org) on Hyprland,
managed with [GNU Stow](https://www.gnu.org/software/stow/) and maintained by a
small CLI called `loaf`.

Named for 食パン, Japanese milk bread. A rice can be named anything — "rice" is
just the term for a customized desktop, so the bread is a joke rather than a
category error.

Kept separate from my [macOS dotfiles](https://github.com/austin-karren/dotfiles)
because the two platforms share almost nothing beyond `.gitconfig`. The shell
here is bash (Omarchy's), not the zsh setup from that repo.

## Layout

This is a single flat Stow package: paths mirror `$HOME` directly.

```
.bashrc                 -> ~/.bashrc
.config/hypr/*.lua      -> ~/.config/hypr/*.lua    (quattro; .conf for the rest)
.local/bin/*            -> ~/.local/bin/*
...
```

## Install

```bash
cd ~
gh repo clone austin-karren/shokupan
cd shokupan
sudo pacman -S --needed stow
stow --adopt .   # --adopt takes ownership of existing files in place
git diff         # review what --adopt pulled in from the live system
loaf doctor      # confirm all three layers agree
```

`--adopt` is the first-machine move — it captures a live system into the repo.
A **fresh** machine goes the other way: install CachyOS normally, layer quattro
(`lab/`, ADR-0035), then run `.local/bin/loaf-install` from the clone. It
refuses an Omarchy other than `packages/omarchy.pin` (ADR-0043), installs the
chosen packages and flatpaks, stows, debloats and migrates — every step
idempotent, so a failed run resumes by running it again.

The directory name matters: `loaf` defaults to `~/shokupan` when `LOAF_ROOT` is
unset, so cloning it anywhere else means exporting that variable.

`--adopt` moves your existing config files into the repo and replaces them with
symlinks. If the live files differ from what's committed, `--adopt` **overwrites
the repo copy with the live one** — so always `git diff` afterwards and decide
which version you actually want.

## Required: git identity

`.config/git/config` deliberately contains no email. It ends with:

```gitconfig
[include]
	path = ~/.gitconfig.local
```

Create that file (it is gitignored, and never committed):

```gitconfig
[user]
	email = your.email@example.com
```

A missing include fails **silently** — git will not warn you, it will just reject
commits with "please tell me who you are". If you see that, this file is why.

Note: git reads `~/.gitconfig` only when `~/.config/git/config` does not exist.
Since this repo installs the latter, a stray `~/.gitconfig` is ignored entirely.

## Required: compose identity

`.XCompose` ends with `include "%H/.XCompose.local"` — the identity expansions
(name, email as compose sequences) live machine-side (ADR-0010). Create that
file (gitignored, never committed):

```
<Multi_key> <space> <n> : "Your Name"
<Multi_key> <space> <e> : "your.email@example.com"
```

Unlike the git include, a missing file here is **fatal to the whole compose
table** — xkbcommon aborts the parse, so every sequence dies, emoji included.
An empty file is enough to parse. Run `omarchy-restart-xcompose` after edits.

## Optional: shell identity

`.bashrc` ends with the same pattern, for anything carrying an account name or a
secret:

```bash
[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local
```

Create that file (gitignored, never committed) with whatever this machine needs —
currently the AWS profile:

```bash
export AWS_PROFILE=your-profile
export AWS_SDK_LOAD_CONFIG=1
```

Unlike the git include this one is guarded, so a missing file is harmless: the
shell starts fine and you simply have no AWS profile. It is sourced **last**, so
it can also override anything the tracked `.bashrc` set.

## What's here

| Path | Notes |
|---|---|
| `.config/hypr/` | Hyprland: bindings, monitors, looknfeel, windows, idle/lock/sunset |
| `.config/ghostty/`, `alacritty/`, `foot/` | Terminals. Ghostty sources Omarchy's dynamic theme path, which stays machine-side |
| `.config/zed/` | Editor + agent settings |
| `.config/git/config` | Aliases, delta pager, zdiff3, rerere |
| `.config/uwsm/` | Session env (incl. making snap apps visible to the launcher) |
| `.config/omarchy/shell.json` | The quickshell bar: layout, module settings, idle timings. Hot-reloaded for bar/layout edits — but the **idle timings need `omarchy-restart-shell`**: hot-reload updates the reported values while the IdleMonitor keeps its old timer, so the chain silently never fires (observed 2026-08-11) |
| `.config/omarchy/bar/modules/` | Custom QML bar modules, for behaviour a `type: "command"` entry cannot express: the bar-settings gear after the workspaces, the indicators fork carrying the zen-ratio toggle, and the hosted widgets. The legacy form since ADR-0044 — wave 1 moved the calendar, menu and ApexShot buttons out to plugins. New files here need `omarchy-restart-shell`; edits hot-reload |
| `.config/omarchy/themed/shell.toml.tpl` | Theme template override that pins the bar dark in every theme (ADR-0009). User templates outrank Omarchy's, so this replaces the built-in wholesale — re-diff it after an upgrade |
| `.config/omarchy/extensions/omarchy-menu.jsonc` | Our rows in the Omarchy Menu, and the System Palette's only home since quattro (ADR-0027) — the sanctioned extension point, not a patched Omarchy file. Hot-reloaded. Replaced `menu.sh`, whose bash extension point quattro removed |
| `.config/starship.toml`, `.config/tmux/` | Prompt, and the general-purpose multiplexer. Agent sessions live in herdr instead — a self-updating binary in `~/.local/bin`, deliberately not in the manifest (ADR-0015) |
| `.bashrc` | Thin — sources Omarchy's `default/bash/rc` |
| `.local/bin/` | The `loaf` CLI, plus every script a keybinding or bar module depends on. The npx shims (`codex`, `gemini`, …) stay untracked — they are generated, not config |
| `.config/omarchy/hooks/post-update.d/` | Runs `loaf heal` after each `omarchy update` — the sanctioned hook directory, not a patched Omarchy file |
| `.local/share/applications/` | The web apps (`omarchy-launch-webapp` entries) and their icons, plus the Flatpak ref handler, plus the `shokupan-cmd-*` command entries of ADR-0027's merged list — generated by `shokupan-launcher-cmds`, edited there, never by hand. Tracked because a rebuild would otherwise come up with no web apps at all |
| `.config/omarchy/plugins/shokupan-launcher/` | The merged app+command launcher (ADR-0027): upstream's launcher forked as a third-party overlay plugin, command block on top, apps alphabetical below. Re-diff against upstream after omarchy updates |
| `.config/omarchy/plugins/shokupan-dpms-guard/` | Service plugin that keeps the display off while locked: the BenQ's USB-C deep sleep hotplugs the connector and Hyprland sometimes wakes the output (ADR-0019 addendum). Polls while locked, re-asserts display-off if the user is still idle |
| `.config/omarchy/plugins/shokupan-{calendar,omenu,apexshot}/` | Bar-widget plugins, converted from QML modules in ADR-0044's wave 1: the static calendar button, the menu button wearing the power glyph, and the ApexShot screenshot button (expected to be replaced by quattro's full-release screenshot tool). Enabled by their `shokupan.*` ids in `shell.json`'s bar layout |
| `.config/wireplumber/wireplumber.conf.d/` | One `zz-`named drop-in that puts headset (HFP) profiles back into `bluez5.auto-connect` (ADR-0045). Omarchy's A2DP-only fragment lives in the same real directory; `conf.d` fragments merge in filename order and the later matching rule wins, so this overrides without touching Omarchy's file |
| `.config/mimeapps.list` | Which application handles what. Load-bearing, not incidental: it is the half of ADR-0032 that actually activates the Flatpak ref handler, and the half of ADR-0036 that decides which browser every web app and browser bind opens |
| `.config/chromium-flags.conf`, `.config/helium-browser-flags.conf` | Browser flags. Read by each browser's launcher wrapper, which is the only place a flag reaches web-app windows — `.desktop` `Exec=` lines are truncated to their first token (ADR-0036) |
| `packages/`, `migrations/` | Repo-only: the package manifests (pacman and Flatpak), and one-shot fixes for state that lives outside the repo |

### Deliberately not tracked

- **`~/.config/nvim`** — unmodified LazyVim starter. Nothing of mine in it yet.
- **`~/.XCompose.local`** — the identity expansions split out of the now-tracked
  `.XCompose` (ADR-0010); see "Required: compose identity" above.
- **`*.bak.<timestamp>`** — Omarchy migration artifacts, not config.

## The `loaf` command

Stow installs the symlinks once. It has no opinion about what happens to them
afterwards — and on this machine CachyOS and Omarchy both update underneath the
rice, with Omarchy's migrations rewriting files in `~/.config` that are our
symlinks. `loaf` is the part that notices.

```bash
loaf              # list commands
loaf doctor       # check all three layers for drift — read-only, no sudo
loaf heal         # re-assert the rice on top, apply pending migrations
loaf packages     # diff the manifest against what is installed
loaf flatpaks     # same, for the Flatpak manifest
loaf debloat      # re-remove the Omarchy defaults decided against (ADR-0043)
loaf forks        # check recorded forks and watched upstream files for drift
loaf install      # bootstrap a fresh CachyOS + Omarchy machine, bound to the pin
```

`loaf heal` runs automatically after every `omarchy update`, via
`.config/omarchy/hooks/post-update.d/10-loaf-heal`. Files that displaced one of
our symlinks are kept as `.displaced.<epoch>` rather than deleted — that is
upstream's new default, usually worth reading first.

Commands are discovered at run time from `loaf-*` on PATH, so a new script in
`.local/bin` shows up in the help as soon as it carries a `# loaf:summary=` line.

See [ADR-0028](./docs/adr/0028-the-rice-re-asserts-itself-after-upstream-updates.md)
for why this exists and why migrations are worth having on a single machine.

## Packages

The manifests in `packages/` each record one kind of decision: `chosen.packages`
and `chosen.flatpaks` (what was added), `removed.webapps` (which Omarchy default
launchers were removed — re-asserted by `loaf debloat`, ADR-0043), `forks` (which
upstream files the rice forks or structurally depends on, and the SHA-256 each
had at verification — a trailing `watch` marks files referenced rather than
copied; checked by `loaf forks`, ADR-0042), and `omarchy.pin` (which Omarchy all
of it was verified against).

Two files, doing different jobs:

- **`packages/chosen.packages`** is the manifest — packages deliberately added on
  top of the CachyOS + Omarchy baseline. Hand-maintained, in Omarchy's own
  `install/*.packages` format. `loaf packages` diffs it against what is
  installed.
- **`packages.txt`** is the record — the raw output of `pacman -Qqe`, every
  explicitly-installed package on the machine.

The record is **not an install list**. Most of its ~300 entries are the CachyOS
base install and Omarchy's own dependencies, not deliberate choices of mine.
Feeding the whole file to `pacman -S` on a fresh machine is not the intended use.
That is what the manifest is for:

```bash
sudo pacman -S --needed $(sed -e 's/#.*//' -e '/^\s*$/d' packages/chosen.packages)
```

Regenerate the record after installing or removing anything:

```bash
pacman -Qqe > packages.txt
```

`bat` in particular is not optional on an Omarchy box: `default/bash/envs`
exports `MANPAGER="sh -c 'col -bx | bat -l man -p'"` unconditionally, so without
it `man` pipes into a missing binary in any interactive terminal.

Language runtimes stay out of both files — [mise](https://mise.jdx.dev) owns
those, pinned per-project in `~/.config/mise/config.toml`.

## Which Omarchy a commit was built against

The rice is written against a specific Omarchy. Bar modules, menu overrides and window
rules all reach into upstream's files, so "does this work" is only answerable together
with a version.

The answer lives in the commit, as `packages/omarchy.pin` — one line, holding exactly
what `pacman -Q omarchy` reports:

```bash
cat packages/omarchy.pin                     # 4.0.0.r1046.gd570d99-1
git show omarchy-v3.8.4:packages/omarchy.pin # what a past release was verified against
```

The pin is a claim about *compatibility*, not chronology: it says this tree ran against
that Omarchy with the inventory in `~/snapshots/` passing. When upstream moves, the
workflow is to rebuild forward rather than guess what broke — check out the older tree,
read the ADRs that touch what upstream changed, and re-apply them against the new
version.

`loaf doctor` compares the pin to what is installed, so drift is visible without having
to remember to look:

```
✓ version pin    verified against 4.0.0.r1046.gd570d99-1
! version pin    verified against 4.0.0.r1046.gd570d99-1, Omarchy is 4.1.0-1 — re-verify, then re-pin
```

A mismatch is a warning, not a failure: upstream moving ahead is normal and only means
the rice has not been re-verified there yet.

Re-pin once a state is verified working, not when the update completes:

```bash
pacman -Q omarchy | awk '{print $2}' >>packages/omarchy.pin  # then trim the old line
```

**Why a file rather than a tag.** It used to be a tag, `omarchy-vX.Y.Z`, which `loaf
doctor` found with `git tag -l 'omarchy-v*' | sort -V | tail -1`. That was wrong twice.
One namespace was holding two different kinds of claim — `omarchy-v3.8.4-prequattro` is
a *rollback point*, not a pin, and it sorted above the actual pin `omarchy-v3.8.4` and
won. And quattro's version string is `4.0.0.r1046.gd570d99-1`: no leading `v`, and an
`.r<n>.g<sha>-<pkgrel>` suffix that `sort -V` cannot meaningfully order against `v3.8.4`.
Ordering was never going to survive package-backing, so the pin compares by equality
instead — and a file answers this section's own question for *every* commit, not only for
tagged ones.

Tags stay, for marking releases and for rolling back:

```bash
git tag -l                                   # releases and rollback points
git tag -a "omarchy-v4.0.0" -m "verified against Omarchy 4.0.0"
git diff omarchy-v3.8.4..HEAD                # what has changed since
```

## Why things are the way they are

[`CONTEXT.md`](./CONTEXT.md) is the glossary. Worth reading first if you are going
to touch the menus or the bar — Omarchy, Hyprland, Quickshell and this repo all use
"theme", "menu" and "toggle" to mean different things, and three of the four menus
are one modifier apart.

[`docs/adr/`](./docs/adr/) records the decisions. Accepted ones explain existing
behaviour that looks odd on purpose; proposed ones are decisions not yet made, and
are the to-do list.

| ADR | Decision | Status |
|---|---|---|
| [0001](./docs/adr/0001-omarchy-on-cachyos-not-the-omarchy-iso.md) | Omarchy layered onto CachyOS, not the Omarchy ISO — includes the installer path fix | accepted |
| [0002](./docs/adr/0002-single-flat-stow-package.md) | One flat Stow package, adopted in place | accepted |
| [0003](./docs/adr/0003-identity-behind-untracked-includes.md) | Identity behind untracked includes | accepted |
| [0004](./docs/adr/0004-waybar-modules-dismiss-on-second-click.md) | Bar modules dismiss on a second click | superseded by 0033 |
| [0005](./docs/adr/0005-waybar-supervised-by-a-userspace-watchdog.md) | Waybar supervised by a polling watchdog | superseded by 0033 |
| [0006](./docs/adr/0006-calendar-hidden-on-its-own-special-workspace.md) | Calendar on its own special workspace | accepted |
| [0007](./docs/adr/0007-wallpaper-pinned-independently-of-the-theme.md) | Wallpaper pinned independently of the theme | accepted |
| [0008](./docs/adr/0008-aether-confined-to-generated-named-themes.md) | Aether may generate themes, not apply them | accepted |
| [0009](./docs/adr/0009-waybar-stays-dark-in-every-theme.md) | The bar stays dark in every theme | superseded by 0033 |
| [0010](./docs/adr/0010-split-xcompose-to-track-it.md) | Split `~/.XCompose` so it can be tracked | accepted |
| [0011](./docs/adr/0011-extend-second-click-dismissal-to-audio-and-cpu.md) | Second-click dismissal for audio and CPU | proposed |
| [0012](./docs/adr/0012-unify-launcher-and-palette-on-elephant-menus.md) | Unify Launcher and System Palette | superseded by 0027 |
| [0013](./docs/adr/0013-promote-the-ratio-toggle-to-the-bar.md) | Single-window aspect-ratio toggle onto the bar | accepted |
| [0014](./docs/adr/0014-ghostty-split-keybinds.md) | Ghostty split keybinds, and bind `close_surface` | accepted |
| [0015](./docs/adr/0015-replace-tmux-with-herdr.md) | Herdr for agents, tmux for everything else | accepted |
| [0016](./docs/adr/0016-remote-access-from-the-macbook.md) | Reach this machine from the MacBook over Tailscale | accepted |
| [0017](./docs/adr/0017-druk-as-the-terminal-editor.md) | Bake off druk, Helix and Neovim as the terminal editor | proposed |
| [0018](./docs/adr/0018-worktrunk-for-git-worktrees.md) | Manage worktrees with worktrunk | proposed |
| [0019](./docs/adr/0019-idle-timings-for-a-remote-first-machine.md) | Retune the idle chain, keep the machine reachable | accepted |
| [0020](./docs/adr/0020-super-w-closes-the-smallest-surface.md) | `SUPER+W` closes the smallest surface, not the window | accepted |
| [0021](./docs/adr/0021-floating-mode-as-a-real-mode.md) | Make floating a real mode, toggleable from the bar | rejected — the capability shipped in 0024/0025, the mode is not wanted |
| [0022](./docs/adr/0022-cycle-split-ratios-with-arrow-keys.md) | Cycle window sizes along a Size ladder | accepted |
| [0023](./docs/adr/0023-arrow-modifiers-encode-scope.md) | Arrow-key modifiers encode what you are acting on | accepted |
| [0024](./docs/adr/0024-floating-placement-keys.md) | Floating windows get placement keys | accepted |
| [0025](./docs/adr/0025-resize-windows-by-dragging-borders.md) | Resize windows by dragging their borders | accepted |
| [0026](./docs/adr/0026-zen-ratio-instead-of-a-square.md) | Single-window **zen** aspect ratio, 6:5 not square | accepted |
| [0027](./docs/adr/0027-one-list-for-apps-and-commands.md) | One list for applications and system commands | accepted — rebuilt under quattro (desktop entries + shokupan.launcher fork) |
| [0028](./docs/adr/0028-the-rice-re-asserts-itself-after-upstream-updates.md) | The rice re-asserts itself after upstream updates | accepted |
| [0029](./docs/adr/0029-the-bar-is-sorted-by-question-not-by-mechanism.md) | The bar is sorted by the question each module answers | accepted |
| [0030](./docs/adr/0030-the-audio-tui-opens-on-output.md) | The audio TUI opens on Output Devices | superseded — quattro's `omarchy.audio` opens on Output natively |
| [0031](./docs/adr/0031-the-bar-remembers-the-weather.md) | The bar remembers the weather, so a failed fetch cannot blank it | accepted |
| [0032](./docs/adr/0032-flathub-on-the-web-with-a-ref-handler.md) | Flathub on the web, with a ref handler | accepted |
| [0033](./docs/adr/0033-quattro-is-a-hyprland-rewrite-not-a-bar-swap.md) | Quattro is a Hyprland rewrite, not a bar swap | accepted |
| [0034](./docs/adr/0034-omarchy-is-clay-cachyos-is-the-base.md) | Omarchy is clay; CachyOS is the base | accepted |
| [0035](./docs/adr/0035-shokupan-owns-the-install-path.md) | Shokupan owns the install path; the bridge is retired | proposed |
| [0036](./docs/adr/0036-middle-click-autoscroll-via-the-flags-file.md) | Middle-click autoscroll, set where the browser reads it | accepted |
| [0037](./docs/adr/0037-the-about-window-is-sized-to-fastfetch.md) | The About window is sized to fastfetch, by measuring the cell | accepted |
| [0038](./docs/adr/0038-helium-plays-drm-through-a-donated-widevine.md) | Helium plays DRM through a donated Widevine; Chrome is gone | accepted |
| [0039](./docs/adr/0039-claude-usage-belongs-in-the-launcher-not-on-the-bar.md) | Claude usage belongs in the launcher, not on the bar | accepted |
| [0040](./docs/adr/0040-the-wallpaper-picker-shows-names-and-moves-the-pin.md) | Wallpaper picker shows names and moves the pin | accepted |
| [0041](./docs/adr/0041-rice-files-out-of-the-omarchy-namespace.md) | Rice files leave the omarchy namespace where upstream's contract allows | proposed |
| [0042](./docs/adr/0042-loaf-must-reassert-the-quattro-rice-without-hands.md) | Loaf must re-assert the quattro rice without hands | proposed |
| [0043](./docs/adr/0043-loaf-installs-and-debloats-bound-to-the-pin.md) | Loaf installs and debloats, bound to the Omarchy pin | accepted |
| [0044](./docs/adr/0044-plugins-are-the-default-shape-for-new-shell-work.md) | Plugins are the default shape for new shell work | accepted |

## To do

- **Make loaf quattro-complete (ADR-0042)** — the port was done by hand; the four
  gaps that would make the next `omarchy update` need hands again are listed
  there: launcher-fork drift detection, hosted-widget path assertions, heal
  restarting the shell after module changes, and heal adopting identical foreign
  real files with truthful reporting
- Work through the other proposed ADRs above (0017, 0018, 0035, 0041)
- Teach `loaf doctor` to check that the pinned wallpaper survived the last theme
  change — an ADR'd behaviour with no assertion behind it. The watchdog half of
  this item died with Waybar (ADR-0005, ADR-0033)
- Decide whether `loaf heal` should ever act on `.displaced.*` files, or only
  ever leave them for a human to read
- Settle wrap versus clamp for the Size ladder (ADR-0022) after using both, and put
  the switch in the Toggle Menu. Until then it is the flag file itself:
  `~/.local/state/omarchy/toggles/window-resize-clamp` (present = clamp) —
  `window-resize --toggle-mode` went with the script in the quattro port
- Play one DRM stream in Helium to close ADR-0038's owed verification, then
  delete the leftover `~/.config/google-chrome/` profile

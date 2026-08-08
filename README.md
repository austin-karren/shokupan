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
.config/hypr/*.conf     -> ~/.config/hypr/*.conf
.config/waybar/*        -> ~/.config/waybar/*
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
| `.config/waybar/` | Bar config, styles, and theme override |
| `.config/walker/` | Launcher front-end: window, theme, list widget |
| `.config/elephant/` | Launcher backend: what appears in the list. `menus/` defines the System Palette; the `*.toml` files are per-provider overrides, each holding only the keys that differ from the default — `elephant generate config` will expand them into full default dumps, which is not what you want |
| `.config/ghostty/`, `alacritty/`, `foot/` | Terminals. Ghostty sources Omarchy's dynamic theme path, which stays machine-side |
| `.config/zed/` | Editor + agent settings |
| `.config/git/config` | Aliases, delta pager, zdiff3, rerere |
| `.config/uwsm/` | Session env (incl. making snap apps visible to walker) |
| `.config/omarchy/extensions/menu.sh` | Omarchy menu overrides — the sanctioned extension point, not a patched Omarchy file |
| `.config/starship.toml`, `.config/tmux/` | Prompt and multiplexer |
| `.bashrc` | Thin — sources Omarchy's `default/bash/rc` |
| `.local/bin/` | The `loaf` CLI, plus every script a keybinding or bar module depends on. The npx shims (`codex`, `gemini`, …) stay untracked — they are generated, not config |
| `.config/omarchy/hooks/post-update.d/` | Runs `loaf heal` after each `omarchy update` — the sanctioned hook directory, not a patched Omarchy file |
| `.local/share/applications/` | The web apps (`omarchy-launch-webapp` entries) and their icons, plus the Flatpak ref handler. Tracked because a rebuild would otherwise come up with no web apps at all |
| `.config/mimeapps.list` | Which application handles what. Load-bearing, not incidental: it is the half of ADR-0032 that actually activates the Flatpak ref handler |
| `packages/`, `migrations/` | Repo-only: the package manifests (pacman and Flatpak), and one-shot fixes for state that lives outside the repo |

### Deliberately not tracked

- **`~/.config/nvim`** — unmodified LazyVim starter. Nothing of mine in it yet.
- **`~/.XCompose`** — contains a literal email expansion; kept out of a public repo.
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

Every state known to work is therefore tagged `omarchy-vX.Y.Z`:

```bash
git tag -l 'omarchy-*'                       # every pinned state
git show omarchy-v3.8.4 --stat               # what the rice looked like for that release
git diff omarchy-v3.8.4..HEAD                # what has changed since
```

The tag is a claim about *compatibility*, not just chronology: it says this tree ran
against that Omarchy with the inventory in `~/snapshots/` passing. When upstream moves,
the workflow is to rebuild forward from the tag rather than to guess what broke — check
out the tag, read the ADRs that touch what upstream changed, and re-apply them against
the new version.

`loaf doctor` reports the pin against what is installed, so drift is visible without
having to remember to look:

```
✓ version pin    verified against v3.8.4
! version pin    verified against v3.8.4, Omarchy is v3.9.0 — re-verify, then re-tag
```

A mismatch is a warning, not a failure: upstream moving ahead is normal and only means
the rice has not been re-verified there yet.

Tag a state once it is verified working, not when the update completes:

```bash
git tag -a "omarchy-v$(omarchy-version)" -m "verified against Omarchy vX.Y.Z"
git push --tags
```

## Why things are the way they are

[`CONTEXT.md`](./CONTEXT.md) is the glossary. Worth reading first if you are going
to touch the menus or the bar — Omarchy, Hyprland, Walker and this repo all use
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
| [0004](./docs/adr/0004-waybar-modules-dismiss-on-second-click.md) | Bar modules dismiss on a second click | accepted |
| [0005](./docs/adr/0005-waybar-supervised-by-a-userspace-watchdog.md) | Waybar supervised by a polling watchdog | accepted |
| [0006](./docs/adr/0006-calendar-hidden-on-its-own-special-workspace.md) | Calendar on its own special workspace | accepted |
| [0007](./docs/adr/0007-wallpaper-pinned-independently-of-the-theme.md) | Wallpaper pinned independently of the theme | accepted |
| [0008](./docs/adr/0008-aether-confined-to-generated-named-themes.md) | Aether may generate themes, not apply them | accepted |
| [0009](./docs/adr/0009-waybar-stays-dark-in-every-theme.md) | The bar stays dark in every theme | accepted |
| [0010](./docs/adr/0010-split-xcompose-to-track-it.md) | Split `~/.XCompose` so it can be tracked | proposed |
| [0011](./docs/adr/0011-extend-second-click-dismissal-to-audio-and-cpu.md) | Second-click dismissal for audio and CPU | proposed |
| [0012](./docs/adr/0012-unify-launcher-and-palette-on-elephant-menus.md) | Unify Launcher and System Palette | superseded by 0027 |
| [0013](./docs/adr/0013-promote-the-ratio-toggle-to-the-bar.md) | Single-window aspect-ratio toggle onto the bar | accepted |
| [0014](./docs/adr/0014-ghostty-split-keybinds.md) | Ghostty split keybinds, and bind `close_surface` | accepted |
| [0015](./docs/adr/0015-replace-tmux-with-herdr.md) | Replace tmux with herdr | proposed |
| [0016](./docs/adr/0016-remote-access-from-the-macbook.md) | Reach this machine from the MacBook over Tailscale | proposed |
| [0017](./docs/adr/0017-druk-as-the-terminal-editor.md) | Bake off druk, Helix and Neovim as the terminal editor | proposed |
| [0018](./docs/adr/0018-worktrunk-for-git-worktrees.md) | Manage worktrees with worktrunk | proposed |
| [0019](./docs/adr/0019-idle-timings-for-a-remote-first-machine.md) | Retune the idle chain, keep the machine reachable | proposed |
| [0020](./docs/adr/0020-super-w-closes-the-smallest-surface.md) | `SUPER+W` closes the smallest surface, not the window | accepted |
| [0021](./docs/adr/0021-floating-mode-as-a-real-mode.md) | Make floating a real mode, toggleable from the bar | proposed (placement done in 0024) |
| [0022](./docs/adr/0022-cycle-split-ratios-with-arrow-keys.md) | Cycle window sizes along a Size ladder | accepted |
| [0023](./docs/adr/0023-arrow-modifiers-encode-scope.md) | Arrow-key modifiers encode what you are acting on | accepted |
| [0024](./docs/adr/0024-floating-placement-keys.md) | Floating windows get placement keys | accepted |
| [0025](./docs/adr/0025-resize-windows-by-dragging-borders.md) | Resize windows by dragging their borders | accepted |
| [0026](./docs/adr/0026-zen-ratio-instead-of-a-square.md) | Single-window **zen** aspect ratio, 6:5 not square | accepted |
| [0027](./docs/adr/0027-one-list-for-apps-and-commands.md) | One list for applications and system commands | accepted |
| [0028](./docs/adr/0028-the-rice-re-asserts-itself-after-upstream-updates.md) | The rice re-asserts itself after upstream updates | accepted |
| [0029](./docs/adr/0029-the-bar-is-sorted-by-question-not-by-mechanism.md) | The bar is sorted by the question each module answers | accepted |
| [0030](./docs/adr/0030-the-audio-tui-opens-on-output.md) | The audio TUI opens on Output Devices | accepted |
| [0031](./docs/adr/0031-the-bar-remembers-the-weather.md) | The bar remembers the weather, so a failed fetch cannot blank it | accepted |
| [0032](./docs/adr/0032-flathub-on-the-web-with-a-ref-handler.md) | Flathub on the web, with a ref handler | accepted |

## To do

- Work through the proposed ADRs above
- Teach `loaf doctor` to check the things it currently cannot: that Waybar's
  watchdog is actually running, and that the pinned wallpaper survived the last
  theme change. Both are ADR'd behaviours with no assertion behind them
- Decide whether `loaf heal` should ever act on `.displaced.*` files, or only
  ever leave them for a human to read
- Settle wrap versus clamp for the Size ladder (ADR-0022) after using both, and put
  the switch in the Toggle Menu instead of `window-resize --toggle-mode`
- Put Tailscale in the right-hand group of the bar. `omarchy install tailscale`
  already exists and installs the service plus an admin-console web app, so the
  work is the module, not the install. Placement follows ADR-0029 — the question
  it answers, not where there is room — and it joins the existing box rule for
  Pitch rather than getting margins of its own
- Make the Flatpaks reproducible. A fresh clone installs the Ref handler
  (ADR-0032) but no Flatpaks: `packages/chosen.packages` is pacman-only, so an
  app like Dawn appears in neither the manifest nor the record. Wants a second
  manifest and a `loaf` command that installs and diffs it. Install order for
  anything new is `omarchy install <thing>` when Omarchy ships an installer,
  then `omarchy pkg add <packages...>`, and Flatpak only for what neither
  covers — note `omarchy pkg install` is a fuzzy-finder TUI that ignores
  arguments, so it is never the scripted form
- Survive an upstream Waybar change without losing features or gaining
  regressions. When Omarchy ships a new bar, the wanted outcome is a diff — read
  what upstream changed, adopt the good parts, keep ours. Half of that already
  works: `loaf heal` keeps the overwriting file as `.displaced.<epoch>` and
  restores ours, so both versions survive. Two gaps. First, nothing snapshots
  `$HOME` first: `/home` is its own btrfs subvolume but snapper has a config for
  `/` only, so the pre/post snapshots on every pacman transaction do not cover
  any config. Second, nothing announces that a new upstream version arrived and
  is worth reading — a `.displaced` file is easy to miss. Note Omarchy has no
  pre-update hook (only `post-update.d`), so a snapshot step needs either a
  snapper config for `@home` or a wrapper around `omarchy update`
- Audit the per-application tweaks and track the ones worth keeping. Slack's
  Electron menu bar is hidden, Helium's profiles were made themable, and Helium
  got the Chrome DRM component — none of them are in the repo today, and
  `~/.config/chromium-flags.conf` is untracked but still stock. Expect more of
  these than the three named

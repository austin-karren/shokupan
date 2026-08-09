# Porting the rice to quattro

Working document, not an ADR. The ADRs are the specification — they record *why*
each binding and module exists, and that is the part that has to survive. This
file tracks what is left to do and what has already been established, so the work
can be picked up cold.

Written 2026-08-09, immediately after the upgrade. Delete it when the list is empty.

## Where the machine actually is

Verified after the reboot, not assumed:

- `omarchy-dev 4.0.0.r1046.gd570d99-1`, package-backed at `/usr/share/omarchy`
- Hyprland and quickshell both running; **`hyprctl systeminfo` reports
  `configProvider: lua`**, so the Lua config is live
- CachyOS base intact: 4 `[cachyos*]` repo sections, `linux-cachyos 7.1.6-1`,
  291-line CachyOS mirrorlist — byte-identical to the pre-upgrade baseline
- `loaf doctor`: 3 problems, all expected (below)

**Removed by the upgrade, so anything depending on them is dead:** `waybar`,
`walker`, `elephant`, `swaybg`, `wiremix`.

## Rules for this work

- **Do not run `loaf heal`.** It re-asserts every tracked symlink (ADR-0028), which
  would restore `hyprland.conf` / `bindings.conf` / `autostart.conf` next to
  quattro's `.lua` files and reinstall configs for packages that no longer exist.
  `loaf doctor` reporting those as missing is *expected* until this list is done.
- Rollback if needed: btrfs `@-prequattro-20260809-093156` and
  `@home-prequattro-20260809-093156`, or git tag `omarchy-v3.8.4-prequattro`.
- Desktop changes update the ADRs, `CONTEXT.md` and `README.md` in the same commit.
- `./test/loaf-test.sh` must stay green. One pre-existing failure: `weather-icon`
  SC2016. Do not "fix" it as part of this.
- Never add `Co-Authored-By: Claude` to commits.

## The work list

`loaf doctor` is the honest inventory. 31 tracked symlinks are not installed and
3 were replaced by real files. Each falls into one of three buckets, and deciding
the bucket is most of the work:

**Delete — the software is gone, the config is dead weight** — ✅ done 2026-08-09

All 12 files removed; see the addendum on ADR-0033 for what was measured first.
`loaf doctor`'s not-installed count drops 31 → 19.

Two of them are the *specification* for the Port bucket and must be read before it
is attempted — `config.jsonc` for the bar's module list and order, `palette.lua`
for the merged list's entries:

    git show omarchy-v3.8.4-prequattro:.config/waybar/config.jsonc
    git show omarchy-v3.8.4-prequattro:.config/elephant/menus/palette.lua

Still dead but *not* deleted, because they are code rather than config and belong
with their own ADRs: `.local/bin/waybar-watchdog` (ADR-0005, retire), the three
toggle wrappers (ADR-0004/0011, native now). The `omarchy-toggle-waybar` line went
with the whole of `.config/omarchy/extensions/menu.sh`, deleted when the menus were
ported — quattro sources no such file, so it was dead in full rather than in one
line. `packages.txt` also still lists `waybar`,
`omarchy-walker` and `wiremix`; regenerating it sweeps in the whole upgrade's
package churn, so it wants its own commit.

**Port — the behaviour is still wanted, the mechanism changed**

    .config/hypr/{bindings,autostart}.conf  →  the .lua equivalents
    the merged app+command palette (ADR-0012/0027)   ← withdrawn, see ADR-0027

The **bar is done** as of 2026-08-09 — layout, the custom modules and the
fixed-dark treatment, verified rendering on the live session. Six tracked files
carry it:

    .config/omarchy/shell.json                       layout, module settings, idle
    .config/omarchy/bar/modules/ratio.qml            zen-ratio toggle, inactive face
    .config/omarchy/bar/modules/ratio-on.qml         zen-ratio toggle, active face
    .config/omarchy/bar/modules/omenu.qml            menu button wearing the power glyph
    .config/omarchy/bar/modules/calendar.qml         static, left of clock (ADR-0006)
    .config/omarchy/bar/modules/model-usage.qml      hosts upstream's widget, hover-revealed
    .config/omarchy/bar/modules/barcfg.qml           bar-settings gear, after workspaces
    .config/omarchy/themed/shell.toml.tpl            pins the bar to Tailwind-950

`tailscale-icon` is retired in favour of the native `omarchy.tailscale` plugin.
`weather-icon` and `waybar-watchdog` are now unreferenced by the bar but still
tracked; see ADR-0031 and ADR-0005 before removing either. The built-in
bar-config control is suppressed with `centerAnchor: ""` (it only renders when
the anchor is the clock) — the calendar module occupies its old slot, and the
gear lives after the workspaces (ADR-0029's addendum has the whole layout).

Traps found the hard way (first ones recorded in ADR-0013):

- Quickshell runs module commands through `bash -lc`, which has **no
  `~/.local/bin` on `PATH`**. A module whose `exec` is not found renders as an
  empty box with no error anywhere. Use absolute paths until `.config/uwsm/env`
  is re-decided. **The same trap holds for Omarchy Menu actions**
  (`Quickshell.execDetached`, and the floating-terminal presentation): every
  rice-owned command in `extensions/omarchy-menu.jsonc` carries an absolute path,
  measured by `update.system` failing with "command not found" inside an
  otherwise-working terminal.
- The shell's `FileView` watch on `extensions/omarchy-menu.jsonc` goes **stale
  when the file's inode is replaced** (rm + ln, stow re-stow): the old content
  stays live with no error. The symlink itself is fine — verified by summoning a
  rice-only submenu through it. After swapping the file, run `omarchy-menu
  refresh` (or any shell restart) and re-check.
- `loaf doctor` tests each tracked path with `[[ -L ]]`, so a **directory**
  symlink makes every file under it read as "replaced by a real file". Link
  files individually.
- The shell registers **new** files in `bar/modules/` only at startup. Layout
  edits hot-reload, and edits to an already-registered module hot-reload, but a
  freshly added `.qml` file renders nothing until `omarchy-restart-shell` — with
  no error, because quickshell's stdout and stderr both point at `/dev/null`.
  Cost three "failed" implementations before it was identified.
- **`hyprctl dispatch` changed languages.** With `configProvider: lua`, the
  classic `hyprctl dispatch movetoworkspacesilent …` form is parsed as Lua and
  fails; dispatchers are `hl.dsp.*` calls now, e.g.
  `hyprctl dispatch 'hl.dsp.workspace.toggle_special("calendar")'` and
  `hl.dsp.window.move({ workspace = …, window = "address:…", silent = true })`.
  `calendar-toggle` is converted and verified end to end. **`float-snap`,
  `close-surface`, `window-resize` and `window-toggle` still carry the old
  syntax** and are broken until converted — their keybindings are dead anyway,
  so they belong to the `bindings.conf` → `.lua` port, not the bar.
- QML string literals do not understand `\U000FXXXX`; supplementary-plane Nerd
  Font glyphs must be embedded as literal characters (or `\u{F00ED}`).

Resolved since first noted here: `omarchy.model-usage` *can* hover-reveal
without cloning its chip. `Ui/BarWidget.qml` is a plain `Item`, so
`bar/modules/model-usage.qml` hosts upstream's real `Widget.qml` by absolute
path, injects `bar` / `moduleName` / `settings` the way the host would, and owns
only visibility — popup, provider tabs and upstream fixes all retained.

**Re-decide — quattro may already do it natively** — ✅ emptied 2026-08-09

Each entry got a measured decision:

- `.config/swayosd/*` — **retired.** The package itself was uninstalled by the
  upgrade (`pacman -Q swayosd` fails) and quattro's `omarchy.osd` plugin is the
  OSD. No tracked file referenced it outside the archived upgrade script.
- `.config/uwsm/env` — **retired, one line promoted.** The upgrade displaced it
  and no-op'd its Omarchy-managed lines in `env.d/99-omarchy-upgrade-env` —
  including `PATH += ~/.local/bin`, which was ours, not Omarchy's to omit. That
  omission is the root cause of every "command not found" this migration hit:
  quickshell and all its children lost the rice's bin directory. The line now
  lives in tracked `.config/uwsm/env.d/20-local-bin` — `env.d/*` being the
  override point upstream's own `10-omarchy` names as preferred. Everything else
  in the old file is upstream's job now (OMARCHY_PATH, omarchy bin, mise) or was
  preserved by the upgrade (the snap XDG_DATA_DIRS block).
- `.config/uwsm/default` — **retired.** Upstream still sources
  `~/.config/uwsm/default` for compatibility, but every line of ours is now
  expressed upstream: `TERMINAL=xdg-terminal-exec` is the quattro default, and
  `EDITOR=nvim` is what `omarchy-launch-editor` falls back to anyway — no
  default editor is configured and druk is not installed, so ADR-0017's bakeoff
  is unaffected and still proposed.
- `.config/xdg-terminals.list` — **kept, re-linked.** `xdg-terminal-exec` is
  quattro's TERMINAL and three terminals are installed (ghostty, alacritty,
  foot), so the deterministic ghostty pin still earns its place. Verified by
  spawning through it: class `com.mitchellh.ghostty`.
- `.local/share/applications/icons/*` — **kept, verified whole** under the
  ADR-0032 pass: every tracked entry's Exec resolves, every Icon path exists,
  every link live.

The absolute paths written into `extensions/omarchy-menu.jsonc` during the menu
port **stay as belt-and-braces**: the env fix makes bare names work, but this
exact upgrade demonstrated how a session-env line can be silently dropped by a
migration, and the absolute paths cost nothing while surviving that class of
failure. The live-session fix is NOT omarchy-restart-shell (menu actions and keybinds
execute via Hyprland's env through hl.exec_cmd, not quickshell's - measured by
a bare-name menu row failing while quickshell's own env resolved it); it is one
runtime dispatch, `hl.env("PATH", ...)`, which patched the running Hyprland and
was verified by a bare-name menu row executing end-to-end. It dies with the
session exactly when the `env.d` drop-in takes over.

Three tracked files were overwritten with real files by the upgrade and need
diffing against ours before anything is restored:

    .config/foot/foot.ini
    .config/ghostty/config
    .config/hypr/hyprland.conf   ← 77 bytes, recreated by ApexShot at 10:04,
                                    inert while configProvider is lua

## Disposition of the ADRs

From ADR-0033, which did this analysis against the quattro worktree. Four of these
end in *deleting* code, which is the good news:

| ADR | Under quattro |
|---|---|
| 0004, 0011 second-click dismissal | Native. **Delete the toggle wrappers** |
| 0029 bar sorted by question | Native layout. The measured-width CSS goes entirely |
| 0012 / 0027 merged app + command list | ✅ Done. **Not** mechanical, and the merge is **withdrawn** — the launcher takes applications only. 21 of 27 entries were already native; 10 rows remain in `extensions/omarchy-menu.jsonc` |
| 0005 waybar watchdog | Retire. It guarded a Waybar GTK3 crash that no longer exists |
| 0006 calendar on a special workspace | **This row was wrong.** Quattro's clock is a 66-line bar label with no popup and no month grid, and there is no clock panel. ADR-0006 keeps GNOME Calendar — see its own correction |
| 0019 idle timings | Moves into `shell.json` as `idle.screensaver` / `idle.lock` |
| 0030 audio TUI opens on Output | `omarchy.audio` replaces wiremix |
| 0009 bar stays dark in every theme | Ports, modest work |
| 0013 / 0026 zen ratio toggle | Ports as a bar **command module** |
| 0031 weather Reading | **The one real regression.** Rebuild as a plugin clone |
| 0020–0025 window management | The expensive half — relearn as the `hl.*` Lua API |

The bar's command-module tier reads Waybar-style JSON, and `tailscale-icon --status`,
`ratio-toggle --status` and `weather-icon` already emit exactly that shape. They
port as-is.

**Known collision — resolved 2026-08-09.** Quattro binds `SUPER+SPACE` to its
launcher and `SUPER+ALT+SPACE` to its menu; ADR-0027 had the merged list on
`SUPER+SPACE` and `ALT+SPACE`. With the list split across two surfaces both
reflexes can no longer land in the same place.

Decided: **adopt upstream's chords, and add bare `ALT+SPACE` → launcher** so both
old app reflexes still reach applications. One added binding, no unbinds. Recorded
in ADR-0027 and **applied 2026-08-09**: the `o.bind` line is live at the top of
`~/.config/hypr/bindings.lua` and verified in `hyprctl binds` (modmask 8 → "Launch
apps"). The file itself is being ported by the windows agent; only the SPACE lines
in it are the menus'.

## Tooling that is now wrong — ✅ done 2026-08-09

- `checkout` → `package`, asserting `pacman -Q omarchy` (which resolves through
  `omarchy-dev`'s `Provides: omarchy`). The porcelain-edits check and `cachyos
  patch` were deleted with it: no worktree to be dirty, and quattro ships the
  package list *inside* the omarchy package, so asserting a local edit to it
  survives is a check that must eventually fail on a healthy machine.
- The version pin moved out of the tag namespace into `packages/omarchy.pin`.
  `tag -l 'omarchy-v*' | sort -V | tail -1` was picking the **rollback** tag
  `omarchy-v3.8.4-prequattro` over the real pin, and `4.0.0.r1046.gd570d99-1`
  cannot be ordered against `v3.8.4` regardless. See the README.
- `bridge patch`, `stale clone` and `walker hold` deleted — their subject is an
  installer that will never run again, and a Walker quattro does not ship.
- `wifi backend` **was measurably wrong, not merely stale.** `iwd` is not just
  disabled, it was *removed* by the upgrade's `pacman -Rns`; the
  `wifi.backend=iwd` stanza stayed behind, so NetworkManager has no backend at
  all — `wlp192s0` reports `unavailable` and `nmcli d wifi list` returns nothing
  on unblocked hardware. Doctor reported ✓ the whole time, because ethernet hid
  it. It now asserts that the configured backend is *installed*, which is the
  invariant that holds however this is resolved. **The machine's wifi is still
  broken** — see below.
- New `mirrorlist` check, taking the freed slot: fails if
  `/etc/pacman.d/mirrorlist` points at an Omarchy mirror. That frozen-Arch mirror
  was ADR-0035's root cause and nothing was watching for it.
- ADR-0034's two-command split has collapsed and both ADRs now say so.
  `omarchy-update-git` no longer exists; Omarchy is upgraded *by* `pacman -Syu`.
  The surviving distinction is attended vs unattended, not base vs desktop.

## Still open, from that work

- **This machine has no wifi backend.** `wifi.backend=iwd` in
  `/etc/NetworkManager/NetworkManager.conf` names a package the upgrade removed.
  Decide between dropping the `[device]` stanza — NetworkManager falls back to
  `wpa_supplicant`, which is installed, and is what quattro leaves it on — and
  reinstalling `iwd`. `loaf doctor` fails until one of them happens. Not fixed
  blind, because ADR-0016's remote access rides on this machine's networking.
- `impala` (ADR-0016's wifi TUI) was removed by the same sweep. Its replacement
  is unexamined.

## Notes for the bar, from the menu port

Measurements taken while porting the menus that the bar work needs. Recorded here
rather than acted on: `shell.json`, `.config/omarchy/bar/modules/` and ADR-0013 /
0026 / 0029 are the bar's, not the menus'.

**A custom module cannot join the `omarchy.indicators` cluster.** `Indicators.qml`
loads only from `/usr/share/omarchy/shell/plugins/bar/indicators/` (`Dictation`,
`Dnd`, `NightLight`, `Reminder`, `ScreenRecording`, `StayAwake`); that tree is
package-owned and read-only, and the widget exposes no user-directory search path.
So a rice module can sit *beside* the cluster but never *inside* it.

What it can do instead is bind to the same property the cluster binds to —
`bar.centerSectionRevealHeld` (`Bar.qml:47`) — which gives identical hover
behaviour without membership. `ratio.qml` already does exactly this. Two
consequences worth knowing before designing anything:

- The hover group exists **only in the centre section**. A module in `left` or
  `right` has nothing to bind to, so hover-hiding it means moving it to centre.
- First-party plugin widgets (`omarchy.model-usage`, `omarchy.weather`, …) do not
  bind to it and have no visibility setting. Hover-gating one means re-implementing
  it as a custom QML module and losing whatever popup it owned.

`alwaysShow` on `omarchy.indicators` (`plugins/bar/README.md:76`) is the one
supported visibility lever, and it applies to the whole cluster at once.

### The calendar icon (ADR-0006)

Restoring it is bar work, and it is the **only** entry point still missing. The
other two are back: a `Calendar` row in `extensions/omarchy-menu.jsonc`, and
`SUPER+SHIFT+C` in `bindings.conf` once the Hyprland bindings reach Lua.

ADR-0006 does **not** retire — quattro ships no month grid and no clock popup, and
the reason for GNOME Calendar is online accounts, which a clock-derived grid cannot
show. See the correction on that ADR.

The old Waybar module was `custom/calendar`, glyph **U+F00ED** (`󰃭`), click
running `calendar-toggle`. Nothing about `calendar-toggle` changed, so the module
is the whole job. As a plain always-visible entry it is a `type: "command"` row:

    {"id":"calendar","type":"command","text":"\udb80\udced","tooltip":"Calendar","onClick":"/home/austinkarren/.local/bin/calendar-toggle"}

Note the absolute path — quickshell runs module commands through `bash -lc`, which
has no `~/.local/bin` on `PATH`, and a not-found command renders as an empty box
with no error. If it should hover-hide instead, it needs the `ratio.qml` treatment
and a place in the centre section, per the constraint above.

**Also flagged, not edited:** `docs/adr/0026` still points at
`~/.config/omarchy/extensions/menu.sh` for the Toggle Menu override. That file is
deleted; the override now lives in `.config/omarchy/extensions/omarchy-menu.jsonc`
as a reuse of upstream's `trigger.toggle.one-window-ratio` id. ADR-0026 is
bar-owned, so the one-line correction was left to its owner.

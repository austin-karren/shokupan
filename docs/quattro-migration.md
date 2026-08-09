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

The **bar is done** as of 2026-08-09 — layout, both custom modules and the
fixed-dark treatment, applied to the live session with no shell restart. Three
new tracked files carry it:

    .config/omarchy/shell.json                 layout, module settings, idle
    .config/omarchy/bar/modules/ratio.qml      hover-revealed zen-ratio toggle
    .config/omarchy/themed/shell.toml.tpl      pins the bar to Tailwind-950

`tailscale-icon` is retired in favour of the native `omarchy.tailscale` plugin.
`weather-icon` and `waybar-watchdog` are now unreferenced by the bar but still
tracked; see ADR-0031 and ADR-0005 before removing either.

Two traps found the hard way, both recorded in ADR-0013:

- Quickshell runs module commands through `bash -lc`, which has **no
  `~/.local/bin` on `PATH`**. A module whose `exec` is not found renders as an
  empty box with no error anywhere. Use absolute paths until `.config/uwsm/env`
  is re-decided.
- `loaf doctor` tests each tracked path with `[[ -L ]]`, so a **directory**
  symlink makes every file under it read as "replaced by a real file". Link
  files individually.

Still open on the bar: `omarchy.model-usage` cannot be made to hover-reveal by
configuration — it has no visibility setting, and the hover group only loads
indicators from inside the package. Matching the ratio treatment means a second
QML module that re-implements its chip and loses its popup.

**Re-decide — quattro may already do it natively**

    .config/swayosd/*        quattro has its own OSD
    .config/uwsm/{default,env}
    .config/xdg-terminals.list
    .local/share/applications/icons/*   (web-app icons; ADR-0032 flatpak handler)

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
| 0012 / 0027 merged app + command list | Search is native; the palette is a mechanical rewrite into the plugin's config language |
| 0005 waybar watchdog | Retire. It guarded a Waybar GTK3 crash that no longer exists |
| 0006 calendar on a special workspace | Quattro's clock popup ships a month grid |
| 0019 idle timings | Moves into `shell.json` as `idle.screensaver` / `idle.lock` |
| 0030 audio TUI opens on Output | `omarchy.audio` replaces wiremix |
| 0009 bar stays dark in every theme | Ports, modest work |
| 0013 / 0026 zen ratio toggle | Ports as a bar **command module** |
| 0031 weather Reading | **The one real regression.** Rebuild as a plugin clone |
| 0020–0025 window management | The expensive half — relearn as the `hl.*` Lua API |

The bar's command-module tier reads Waybar-style JSON, and `tailscale-icon --status`,
`ratio-toggle --status` and `weather-icon` already emit exactly that shape. They
port as-is.

**Known collision:** quattro binds `SUPER+SPACE` and `SUPER+ALT+SPACE` to its own
menu; ADR-0027 put the merged list on `SUPER+SPACE` and `ALT+SPACE`. Decide whether
to keep our chords or adopt theirs before rebuilding the palette — ADR-0027's whole
point was that either reflex lands somewhere sensible.

## Tooling that is now wrong

- `loaf doctor`'s `checkout` check fails with *"/usr/share/omarchy is not a git
  checkout"*. Correct — quattro is package-backed. The check needs rewriting to
  assert the **package** version instead, and the version-pin logic with it.
- The `wifi backend` check warns when `wifi.backend=iwd` is *missing*. Quattro
  dropped `iwd` and actively disables it (ADR-0035), so this check has to invert
  or go.
- `bridge patch` and `stale clone` checks are about the retired bridge (ADR-0035).

## Handed to the bar, not done here

Requested 2026-08-09 while the menus were being ported. Both are bar-owned
(`shell.json` layout, `.config/omarchy/bar/modules/`, ADR-0013/0026), so they are
written down rather than acted on. The measurements are here so whoever picks them
up does not have to redo them.

**1. The zen ratio toggle should always be visible.** Two separate asks, and the
second is the easy one:

- *Always visible.* `ratio.qml` line ~36 is
  `readonly property bool revealed: active || (bar && bar.centerSectionRevealHeld === true)`.
  Making that unconditionally `true` is the whole change. The module's own header
  already documents the opposite knob ("to make it hover-only in both states, drop
  `|| active`"), so this is the third point on a scale it was written to have.
  Worth noting it then behaves exactly like a `type: "command"` entry, which the
  header says was rejected *because* it would always be visible — so ADR-0013's
  reasoning needs revisiting, not just the code.
- *Inside the hover group rather than beside it.* This one is blocked. In
  `shell.json` the centre section is `[clock, weather, system-update, indicators,
  ratio]` — `ratio` is a **sibling of** `omarchy.indicators`, not a member of it,
  which is exactly the "near it, not in it" being reported. It cannot be made a
  member by configuration: `Indicators.qml` loads only from
  `/usr/share/omarchy/shell/plugins/bar/indicators/` (`Dictation`, `Dnd`,
  `NightLight`, `Reminder`, `ScreenRecording`, `StayAwake`), that tree is
  package-owned and read-only, and the widget has no user-directory search path.
  The sibling module is the workaround for that limit, not an oversight.

  If group membership is wanted for *appearance* rather than mechanism, the lever
  is `alwaysShow` on `omarchy.indicators` (documented at
  `plugins/bar/README.md:76`) — but it applies to the whole cluster, so every
  inactive indicator becomes permanently visible too. That is a bar-composition
  decision, and ADR-0029 owns it.

**2. "Same with the Claude usage."** Needs one clarification before anyone changes
anything, because the premise did not reproduce. `omarchy.model-usage` sits in the
**right** section of `shell.json`, and only the *centre* section has a hover-reveal
group (`Bar.qml:47` `centerSectionRevealHeld`). Its widget has no hover gating, no
`alwaysShow` setting, and renders an `EmptyUsageChip` when no provider has data, so
by construction something is always drawn. So either something else is hiding it,
or what reads as "hidden" is the empty/compact chip rather than an absent module.
Ask what is actually on screen before treating this as the same fix.

**Also flagged, not edited:** `docs/adr/0026` still points at
`~/.config/omarchy/extensions/menu.sh` for the Toggle Menu override. That file is
deleted; the override now lives in `.config/omarchy/extensions/omarchy-menu.jsonc`
as a reuse of upstream's `trigger.toggle.one-window-ratio` id. ADR-0026 is
bar-owned, so the one-line correction was left to its owner.

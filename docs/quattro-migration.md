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
toggle wrappers (ADR-0004/0011, native now), and the `omarchy-toggle-waybar` line
in `.config/omarchy/extensions/menu.sh`. `packages.txt` also still lists `waybar`,
`omarchy-walker` and `wiremix`; regenerating it sweeps in the whole upgrade's
package churn, so it wants its own commit.

**Port — the behaviour is still wanted, the mechanism changed**

    .config/hypr/{bindings,autostart}.conf  →  the .lua equivalents
    the bar modules (ADR-0013/0026 ratio, ADR-0029 tailscale, ADR-0031 weather)
    the merged app+command palette (ADR-0012/0027)

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

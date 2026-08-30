---
status: proposed
---

# Loaf must re-assert the quattro rice without hands

The quattro port was done by hand — five agents, a day, sixty commits.
omarchy-desktop-on-cachyos ADR-0028's contract is that this never happens twice:
after an upstream update, `loaf heal` re-asserts the rice. The trigger half of
that contract survived the upgrade, measured: quattro's `omarchy-update` line 79
still runs `omarchy-hook post-update`, the hook directory convention is
unchanged, and `10-loaf-heal` is installed. Heal will run.

Heal *running* is no longer heal *sufficing*. The quattro rice contains things a
symlink pass cannot re-assert, and each is a way the next `omarchy update` breaks
the desktop while doctor stays green. In order of blast radius:

1. **The launcher fork drifts silently.** *(2026-08-15: the fork and the
   `weather-icon` script cited below are both gone — ADR-0027 is superseded and
   ADR-0031 is covered by stock. The `forks` check they motivated is what
   survives, now guarding `indicators.qml` and the clock clone.)*
   `shokupan.launcher` is 655 lines copied
   from upstream's `Launcher.qml` and re-ordered (ADR-0027). Upstream fixes never
   reach it, and nothing detects the divergence. `weather-icon --check-icons` is
   the existing pattern for exactly this — a fork that must track its upstream —
   and it caught real drift the day it was needed. Wanted: a doctor `forks` check
   that compares each recorded fork against the upstream file it shadows, so an
   omarchy update that touches `Launcher.qml` turns the board red instead of
   leaving a stale launcher.

2. **Hosted widgets reference upstream QML by absolute path.** The bar modules
   host upstream's real widgets (`Panel.qml` and friends) and re-point
   `activePopout` ownership (the Hosted-widget contract, CONTEXT.md). An upstream
   rename breaks them with no error anywhere, because quickshell's stdout and
   stderr both point at `/dev/null` — measured, it cost three silent failures
   during the port. Wanted: doctor asserts every upstream path our QML references
   still exists.

3. **New bar modules render nothing until the shell restarts.** The shell
   registers files in `bar/modules/` only at startup, so a heal that placed a new
   module symlink has silently not finished. Wanted: heal restarts the shell (or
   says it must be restarted) when its stow pass touched `bar/modules/`.

4. **Heal loses to foreign real files, all or nothing.** One untracked real file
   at a tracked path aborts the entire restow, and heal's reporting then misleads
   ("1 change(s)" for an aborted run; "Nothing to heal" immediately after placing
   links). The port needed the manual fix twice: `cmp` the conflict, remove the
   identical live copy, restow. Wanted: heal adopts identical real files itself
   and reports truthfully — under the hard constraint, learned live, that a real
   file is only cleared if the restow replacing it succeeds in the same breath
   (the running shell lost camera/globe/power on 2026-08-09 when it did not).

Working as designed, listed so nobody "fixes" them: `packages/omarchy.pin` is
updated by hand per verified upgrade — that is the version-lag contract
(omarchy-desktop-on-cachyos ADR-0034), not a gap. And the generated launcher
entries (`shokupan-launcher-cmds`) regenerate on demand rather than on heal,
which is acceptable until upstream churn proves otherwise. *(2026-08-15: the
generator and its entries are deleted with ADR-0027's supersession — no longer
a case.)*

This ADR is the work list for making loaf quattro-complete. It stays proposed
until the four wants above exist and a real `omarchy update` has been survived
without hands.

## Status, 2026-08-10

Measured against the suite (`test/loaf-test.sh`, 95 checks green):

1. **Done.** `packages/forks` records each fork, the upstream file it shadows,
   and that file's SHA-256 at verification. `loaf forks` compares (re-stamp
   with `--record`), and doctor carries a `forks` check. Same by-hand
   re-verification contract as `omarchy.pin`.
2. **Done.** Doctor's `upstream refs` check greps the rice for absolute
   `/usr/share/omarchy/...` references and fails when one is missing. Widened
   2026-08-11 from QML/JS only to every file under `.config/omarchy`,
   `.local/bin`, and `.local/share/applications` — the non-QML couplings
   (claude-usage's upstream scanner, the shokupan-cmd-*.desktop Exec= lines,
   shokupan-launcher-cmds' hardcoded bin dir) broke just as silently.
3. **Done.** Heal tracks whether its restore or stow pass touched
   `bar/modules/` and restarts the shell (or says it must be restarted when no
   session is reachable).
4. **Half done.** Heal now checks stow's exit status — a failed restow is a
   red failure that stops the run, not a green "change". The adopt-identical-
   real-files half is still open, under the learned constraint that a real
   file is only cleared if the restow replacing it succeeds in the same breath.

Still owed before `accepted`: want 4's adoption pass, and a real
`omarchy update` survived without hands.

## Addendum, 2026-08-11 — watched upstream files

The upstream-friction audit found two gaps in want 1 as shipped. First, the
`shell.toml.tpl` template copy (shokupan-plugins ADR-0009) was never recorded
— the one fork `loaf forks` didn't cover. Now recorded.

Second, want 2's existence check was too weak for the hosted-widget couplings.
The bar modules that host upstream QML (`network.qml`, `audio.qml`,
`microphone.qml`, `barcfg.qml`) depend on upstream's *internal structure* — a
direct `WidgetButton` child binding `text: root.icon`, a `TextMetrics` hook,
the hosted-panel pattern, the gear staying render-guarded behind
`moduleName === "omarchy.clock"` in `Bar.qml`. An upstream refactor keeps every
referenced path existing while a rebind silently stops applying.

So `packages/forks` grew a second kind of line: a trailing `watch` field marks
an upstream file the rice *references rather than copies*. Same hash-at-
verification contract, same `--record` re-stamp, same red board on drift — but
the failure message asks to re-verify the coupling still holds, not to re-diff
a copy, because a changed watched file usually still works. The five hosted
couplings (four panels/widgets plus `Bar.qml`'s gear guard) are recorded as
watches.

*(Note 2026-08-12: `audio.qml` and its watch are gone — the wrapper reverted
to stock `omarchy.audio` per shokupan-plugins ADR-0044 after the 2026-08-09
update broke its rebind. Four watched couplings remain: `network.qml`,
`microphone.qml`, and `barcfg.qml`'s two.)*

*(Note 2026-08-15: no watched couplings remain at all — the r1744 upgrade
removed the last hosted widgets, as `packages/forks` records. The watch
mechanism stays for the next deviation; today the file carries two forks,
`indicators.qml` and the clock clone's `Panel.qml`.)*

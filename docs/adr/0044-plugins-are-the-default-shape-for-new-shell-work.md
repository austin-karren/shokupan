# Plugins are the default shape for new shell work

Status: accepted (grilled 2026-08-11/12)

What "fighting Omarchy" actually means here is update breakage: every
`omarchy update` that lands on a fork or a hosted coupling risks silent drift
(ADR-0042 exists because of it). Quattro's own bar widgets, panels and services
are all first-party plugins with manifests — so packaging our shell work the
same way is following upstream's convention, not deviating from it. Decided:

1. **New shell work is born a plugin** under the `shokupan.*` id namespace
   (`omarchy.` is reserved and rejected for third parties). `shokupan-launcher`
   and `shokupan-dpms-guard` already have this shape.
2. **The existing bar QML modules convert in staged waves**, each surviving a
   shell restart and a green `loaf doctor` before the next: (1) calendar,
   omenu, apexshot; (2) indicators; (3) network, microphone; (4) barcfg.
   *Addendum 2026-08-14 (r1744 upgrade): waves 3 and 4 are moot — upstream
   deleted `BarConfigPanel.qml` and moved bar/plugin management into the Setup
   menu, so `barcfg.qml` was deleted rather than converted; the microphone
   wrapper's fixed-width pin became upstream's own `BarIconButton` behaviour
   (absorbed) and the network wrapper lost its hooks to the panel restructure
   (deleted, ADR-0029 globe regressed). `shokupan-launcher` was also deleted
   (see ADR-0027's regression note): a wholesale copy of an upstream file is
   not a durable plugin shape. Wave 2 (indicators) remains a hosted fork,
   re-forked onto the r1744 file — the last bar module standing.*
   The audio wrapper is not converted — it reverts to stock `omarchy.audio`
   instead (quattro's panel made the wrapper's job obsolete, and the Aug 9
   update broke its rebind).
3. **Publishable by default.** Plugins are written portable — configurable via
   the manifest settings schema rather than hardcoded — so they can be shared
   with the community instead of staying a private fork of the ecosystem.
   Exception: a fix for this machine's specific hardware (monitor mode,
   refresh rate) must detect and apply only to that hardware, never become a
   silent default for other people's.
4. **Develop in-repo, publish from a monorepo.** Plugins live in this rice
   under `.config/omarchy/plugins/` (stow delivers them); publishing means
   extracting to a single `shokupan-plugins` monorepo when a plugin is ready.
   Nothing is public until deliberately extracted.
5. **Upstream contributions are vetted drafts.** Proposed issues/PRs to
   Omarchy live as files in `docs/upstream/` for review; issues go first, PRs
   only after upstream's temperature is known, and nothing is posted without
   an explicit per-item go from Austin.

Consequence to keep in view: quattro's full release is imminent and will ship
a screenshot tool that replaces apexshot — and may obsolete more of the rice.
That is fine and expected (ADR-0034's lag-and-adopt posture): we keep shipping
compatibly so any piece upstream obsoletes can be deleted, and only what
upstream doesn't cover stays ours.

*Addendum 2026-08-15: the apexshot deprecation is reversed, same day.
`shokupan.capture` was built on the native `omarchy-capture-*` tools — same
three clicks — and briefly replaced apexshot on the bar, but the user preferred
apexshot and switched back until the native capture flow improves. So
`shokupan.apexshot` holds the bar slot and its six `bindings.lua` chords stay;
`shokupan-capture/` is parked, not deleted — its manifest is marked DORMANT and
it is the drop-in swap when the native flow is good enough.*

*Addendum 2026-08-16 (apexshot theming): apexshot exposes exactly two colour
knobs, both in YAML it owns — `config.yml`'s `wallpaper_plain_color` (the
backdrop behind a capture) and `editor_prefs.yml`'s `color` (the annotation
pen). The backdrop is now repainted from the active theme by
`hooks/theme-set.d/40-theme-apexshot`, a keyed in-place edit so anything else
the user set in that file survives. The pen colour is deliberately left alone:
it is a live user choice, and the file is prefs apexshot rewrites on exit. Its
annotator (`tensaku` 0.26.6) has no documented colour surface at all — a
feature request, not something to patch.*

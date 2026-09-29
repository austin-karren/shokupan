---
status: accepted
---

# Helium profiles follow the Omarchy theme unless chosen

## Context

Helium's profiles are told apart by colour: ShipTrac is teal, Personal is
whatever the desktop is. Omarchy 4.0.4 themes Chromium-family browsers by
writing a **mandatory** enterprise policy on every theme change —
`/etc/chromium/policies/managed/color.json` with `BrowserThemeColor` — as root,
through `omarchy-theme-set-browser-policy` and its sudoers rule. Helium has
Chromium's policy path compiled in, so the day this machine gained
`/etc/chromium/policies/managed/` (Chromium arrived with the ADR-0052
migration's `-Syuu`), every profile locked to Tokyo Night with "Theme is set
by your Organization".

The rice already had an answer — an untracked hook that deleted the policy —
and it broke twice in one day: the file is root-owned now, and the hook was
never in the repo to be noticed.

What was measured on 2026-09-29, because it decides the design:

- Moving the policy to `recommended/` **unlocks** the pickers and Chromium
  then **ignores** the colour: the default profile stayed stock grey
  (`#1e2020`, no blue) against Tokyo Night's `#1a1b26`. `ThemeService` only
  applies `BrowserThemeColor` when the pref is managed. A policy can express
  "everyone locked" or "nobody themed", never "unpinned profiles follow".
- Each profile's colour lives in its `Preferences` as `browser.theme.user_color2`
  (a signed-int32 SkColor) plus `extensions.theme.id = user_color_theme_id`.
  That is the one place a per-profile answer can be written — the existing
  `1786228894` migration proved it.
- Chromium reads `Preferences` at startup only and rewrites it on exit, so a
  patch under a running Helium is lost.

## Decision

Omarchy keeps theming the browser; the rice decides which profiles listen.

1. **What you did in Helium decides.** A profile on the grey default swatch
   follows the desktop; a profile with a picked colour keeps it; picking the
   default again resumes following. Since a following profile carries the
   theme colour and so looks like a pick, every colour written is recorded
   per profile (`~/.local/state/shokupan/helium-theme.json`) and only a
   null/zero colour or the recorded one is ever overwritten.
2. **`helium-theme-apply`** seeds every following profile's `Preferences`
   with the theme's **accent** (`colors.toml`), not the colour Omarchy
   publishes for Chromium (`chromium.theme`, the background): `user_color2`
   is a GM3 seed and Chromium derives the chrome palette from it, so Tokyo
   Night's near-black background produces a chrome indistinguishable from
   stock grey (`#1c1c29` vs `#1e2020`) while its accent gives `#181f30`, the
   theme as a person recognises it. `chromium.theme` is the fallback, and
   `HELIUM_THEME_SEED=background` asks for it. The write carries the full
   shape of a pick — `color_variant2`, `is_grayscale2: false` — because a
   bare colour is cleared on load and the grey "default" swatch is
   Chromium's grayscale mode, which would desaturate the theme. Cold Helium: applied at once. Running
   Helium: a marker is left, and **`helium-launch`** — named as `Exec` by a
   desktop-entry override so Super+B, the launcher and `xdg-open` all pass
   through it — applies the marker before the next cold start.
3. **`theme-set.d/10-helium-theme`** runs both halves after every
   `omarchy-theme-set`: demotes `managed/color.json` to `recommended/` (an
   unlock, nothing more) and calls the apply. It replaces the untracked
   delete-the-policy hook.
4. **`loaf install`** chowns `/etc/chromium/policies/{managed,recommended}` to
   the user so the hook needs no sudo; Omarchy's root-side `install` into a
   user-owned directory still works. **`loaf doctor`** goes red when the
   directory is not writable, warns while a managed policy is present (picker
   locked until the next theme change), and warns while a theme is queued.

## Alternatives rejected

- **Deleting the policy** (the old hook): leaves Omarchy's colour unable to
  reach any profile, which throws away the part of Omarchy theming that is
  wanted.
- **A sudoers rule for the hook**: a second privileged path next to
  Omarchy's, to move one file. Ownership of the directory is the smaller
  change and matches what Omarchy itself did before 4.0.4 (mode 777).
- **Removing Chromium** so the policy directory never exists: fixes the lock
  by accident and breaks the moment Omarchy's package set reinstalls it.
- **Forking `helium.desktop`**: the override is a minimal entry with the same
  id, not a copy of the 200-line translated file; it depends only on
  `helium-browser` and `%U`, so there is nothing to watch for drift.

## Consequences

- A following profile shows a chosen colour in Customize Helium, not the
  grey "default" swatch; choosing grey there is how to hand it back to the
  desktop, and grey itself is never a resting state for a followed profile.
- A theme switch reaches an open Helium at its next cold start, not live. Same
  latency the `1786228894` migration accepted; that migration's hard-coded
  colours are now only a first seed, overridden by the hook.
- Upstream should not lock a personal desktop's theme picker; draft in
  `docs/upstream/browser-theme-policy-opt-out.md` (shokupan-plugins ADR-0044
  rule 5: nothing posted without an explicit go).

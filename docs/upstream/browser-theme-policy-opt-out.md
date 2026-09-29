# Draft issue: the browser theme policy locks the theme picker with no way to opt out

**Status: draft — not posted.** Per shokupan-plugins ADR-0044 rule 5: issue
first, PR only after upstream's temperature is known, nothing posted without an
explicit go.

## Title

`omarchy-theme-set-browser` writes a *mandatory* `BrowserThemeColor` policy —
every Chromium profile shows "Theme is set by your Organization" and there is
no way to keep a per-profile colour

## Body (draft)

`omarchy-theme-set-browser` → `omarchy-theme-set-browser-policy` writes
`{"BrowserThemeColor": ..., "BrowserColorScheme": "device"}` into each
browser's `policies/managed/` directory on every theme change. A managed
policy is mandatory: Chromium greys out the theme picker in every profile with
"Your administrator has set a default theme which cannot be changed".

That is the right default for a fresh install, but it is also absolute. Anyone
who uses profile colours to tell work from personal apart (a common Chromium
pattern) loses that the first time they switch themes, and the only escape is
deleting a root-owned file after every `omarchy-theme-set`. Chromium forks
that read Chromium's policy path — Helium here — are caught too, even though
they are not in the browser list.

Observed on Omarchy 4.0.4 (2026-09-29), Helium 0.18 and Chromium 152.

### Two workable shapes

1. **An opt-out.** A marker file or a setting (for example
   `~/.config/omarchy/browser-theme: off`, or a hook name) that makes
   `omarchy-theme-set-browser` skip the policy write. Cheapest; the user who
   wants their own colours keeps them and everyone else is unchanged.
2. **Make the policy a default rather than a mandate.** Writing to
   `policies/recommended/` unlocks the picker — but Chromium's `ThemeService`
   ignores `BrowserThemeColor` at that level, so the colour stops applying.
   Not viable on its own; noted so nobody retries it.

Shape 1 is the one worth doing. Happy to send a PR if the direction is
welcome.

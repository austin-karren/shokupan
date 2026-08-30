---
status: accepted
---

# The wallpaper pool is a manifest, not a payload

Omarchy ships good wallpapers and keeps deleting them. Themes come and go from
the package, and within a theme upstream prunes images — fifteen are already
gone from the repo's history, including two of Tokyo Night's own. Meanwhile the
installed package carries twenty-one themes' worth of backgrounds that are
invisible outside their theme. This machine runs Tokyo Night (pinned wallpaper
aside, ADR-0007) and wants the whole set in its picker.

## The sanctioned merge point

`omarchy-theme-set` and `omarchy-theme-bg-next` both build the background list
from two dirs: the theme's own `backgrounds/` and
`~/.config/omarchy/backgrounds/<theme-name>/`. The rice's `wallpaper-menu`
(ADR-0040) scans the same two. So a per-theme user dir is upstream's own
extension point — filling `backgrounds/tokyo-night/` widens the pool with no
fork and no patched file. Scope is deliberately Tokyo Night only: under any
other theme the picker stays stock.

## Manifest and bytes, split as usual

Committing images would make the repo a payload: megabytes of JPEGs that are
neither config nor decisions, bloating every clone. Instead the repo tracks
two decisions and `loaf wallpapers` realizes them machine-side:

- **The installed themes' wallpapers** need no manifest at all — the omarchy
  package is the source of truth, so the pool holds symlinks into
  `/usr/share/omarchy/themes/<theme>/backgrounds/`, named `<theme>-<file>`
  (several themes ship the same basename). Symlinks track the installed set
  live: an upstream update that adds an image is one `loaf heal` away from the
  picker, and one that deletes an image leaves a dangling link the same heal
  prunes.
- **The deleted wallpapers** exist nowhere on the machine, so
  `packages/wallpapers` records each one as `<file> <commit> <path>` — the
  commit being the *parent* of the deleting commit, the last point in
  basecamp/omarchy's history where the bytes exist, fetchable from
  `raw.githubusercontent.com`. Files land in
  `~/.local/share/wallpapers/omarchy-history/` and enter the pool as
  `history-<file>` symlinks. Download only when a file is missing; a complete
  machine never touches the network.

This is the same manifest-vs-record posture as `chosen.packages`: the repo
holds the reviewable claim, the machine holds the bytes, and un-choosing a
wallpaper is a one-line revert.

## Heal and doctor close the loop

`loaf heal` runs `loaf-wallpapers --offline` on every pass
(omarchy-desktop-on-cachyos ADR-0028), so the pool re-asserts after upstream
updates without the post-update hook ever touching the network — present files
re-link, missing downloads wait for a manual `loaf wallpapers`. `loaf doctor`
asserts the claim read-only: pool dir exists, every manifest entry's file is on
disk, no dangling symlinks.

## Consequences

- The picker under Tokyo Night shows every wallpaper Omarchy ships or ever
  shipped; every other theme is untouched.
- A fresh machine needs one online `loaf wallpapers` to hydrate the history
  files; everything else reassembles offline from the installed package.
- When upstream deletes another wallpaper, keeping it is one manifest line
  (parent-of-deletion sha, verified with `git cat-file -e`); the sweep command
  is in the manifest header.
- The pool inherits the package's theme set: uninstalling a theme silently
  shrinks the pool (dangling links pruned by heal). If a *theme* deletion ever
  deserves surviving, its images move to the manifest like any other deletion.

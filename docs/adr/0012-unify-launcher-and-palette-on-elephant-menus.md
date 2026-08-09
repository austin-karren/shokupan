---
status: proposed
---

# Unify the Launcher and System Palette on one Elephant menu

> **Mechanism deleted 2026-08-09.** Already superseded by ADR-0027; now the
> substrate is gone too. Walker and Elephant are uninstalled, and
> `.config/elephant/` — the per-provider `*.toml` overrides and `menus/palette.lua`
> — is deleted. Read this ADR for the *why*; the *how* is void. Old files: tag
> `omarchy-v3.8.4-prequattro`.
>
> **Outcome, 2026-08-09.** The two-surface fallback this ADR named — "keep two
> separate menus" — is what quattro enforces, so that is where this ended up, by
> upstream's constraint rather than by choice. But the thing that made the fallback
> a *fallback* is fixed: this ADR kept the System Palette separate because a merged
> 200-entry list is bad at discovery, "you cannot skim it to learn that
> Screensaver exists". Quattro's menu is skimmable **and** searches its whole tree
> from the root, so the browse-versus-search tradeoff this ADR was navigating no
> longer forces a choice. The unresolved question below — whether the empty-query
> list can be ordered at all — is moot: ordering is upstream's now. See the
> addendum to ADR-0027.

Today the System Palette's entries live in a bash `case` statement inside
`~/.local/bin/quick-menu`, invisible to the Launcher. The goal is Raycast's model:
one list where applications and commands are searched together. The proposal is to
define the entries **once** as an Elephant `menus:system` provider (Lua, because
the list is conditional — Sleep only when suspend is enabled, Hibernate only when
available, and the *Switch to Light/Dark* label is dynamic), then expose it twice:

- **Launcher** (`ALT+SPACE`) — `default = ["desktopapplications", "websearch", "menus:system"]`.
  Typing `shut` surfaces Shut Down next to applications. Search-driven.
- **System Palette** (`SUPER+SPACE`) — becomes `walker -m menus:system`, commands
  only. Browse-driven, kept precisely because a merged root list of 200+ entries is
  bad at *discovery*: you cannot skim it to learn that "Screensaver" exists.

Same data, two entry points, no duplicated logic.

Frecency ranking is two lines: `~/.config/elephant/desktopapplications.toml`
currently has `history = false`; setting `history = true` plus
`history_when_empty = true` gives most-used ordering, including on empty input.

## Not available: the two-band layout

The screenshotted Raycast design — a `Favorites` band above a `Suggestions` band —
cannot be built on Walker as it stands. Established, not open:

- Walker's widget tree has **no group-header concept**. The Omarchy-derived theme
  renders a single list with `max_columns = 1`; there is no `Favorites` box to
  render into.
- Elephant has **no pin or favorite primitive**. The nearest knobs are `min_score`,
  `priority` (which fields to weight) and `fixed_order` — none of which express
  "always first, regardless of score".
- Consequently the "rank by most-used *minus* favorites, so nothing appears twice"
  rule has no mechanism: there is no favorites set to subtract.

## Decided: one flat ordered list, no bands

Raycast is the *concept*, not the spec — its UI is not being replicated. The target
is a single scrollable, searchable list, which is precisely what Walker already is,
so the shape is achievable. Favorites-as-a-band is dropped.

Agreed ordering, and the scope of the rule is the important half:

- **Empty search bar** — Toggle Menu commands first, then applications
  alphabetically.
- **Anything typed** — the ordering rule stops applying entirely. Normal scoring
  takes over and ranks commands and applications together on merit.

So "commands first" is a property of the resting state, not a global weighting.
That removes the hard part: no `priority` tuning is needed to keep commands on top
of a query, because they are not meant to stay on top of a query.

Fallback if that ordering cannot be expressed: keep two separate menus, and take
only the other improvements below (Frecency, the shared entry definition, the
`quick-menu` comment fix). Explicitly *not* worth forking Walker's layout over.

### Needs verifying before this is buildable

One thing is genuinely unverified:

- **Can the empty-query list be ordered at all?** Elephant orders by score once a
  query exists; with no query, ordering comes from provider order plus whatever sort
  the provider exposes. A `strings` probe of the `elephant` binary found `priority`
  and `sort` but was inconclusive about a documented alphabetical option — read the
  real config reference rather than trusting that probe. If the empty state cannot
  be ordered, the fallback above applies.

And one either/or to pick, because the two are mutually exclusive for the same slot:

- **Alphabetical or Frecency for the applications in the empty state.** Alphabetical
  is what was asked for here; `history = true` + `history_when_empty = true` would
  instead put most-used first. Both cannot own the resting order. Alphabetical is
  predictable (an app never moves); frecency is fewer keystrokes for the four apps
  actually used, and was the original reason for wanting a "most used" section at
  all. Commands-first is unaffected either way.

The Lua menu pattern itself is proven — `~/.config/elephant/menus/` already holds
`omarchy_themes.lua`, `omarchy_background_selector.lua` and `omarchy_unlocks.lua`
to copy from.

## Also folded in: the Toggle Menu

The Toggle Menu (`SUPER+CTRL+O`, Omarchy's own) overlaps the System Palette —
Screensaver appears in both. Where they overlap, the Toggle Menu's entries and
their ordering win, since they are upstream's and stay correct across updates. The
Palette keeps only what the Toggle Menu lacks (Emoji & Symbols, Clipboard History,
Wallpaper, Theme, Lock, Sleep, Hibernate, Log Out, Restart, Shut Down).

Note the naming hazard here — Omarchy's **Toggle Menu** and our `menu-toggle`
wrapper (ADR-0004) are unrelated. See CONTEXT.md.

## Fix while in here

`quick-menu`'s header comment claims it is bound to `SUPER+CTRL+SPACE`. It is not:
`bindings.conf` binds `SUPER+SPACE` to `quick-menu` and `SUPER+CTRL+SPACE` to
`omarchy-menu`. The comment predates the swap.

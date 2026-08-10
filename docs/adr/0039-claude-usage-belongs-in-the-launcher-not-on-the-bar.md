---
status: accepted
---

# Claude usage belongs in the launcher, not on the bar

> **User-ratified 2026-08-09** ("keep the usage in the launcher, no veto") and
> completed the same day. Of the three options below, **option 1 is what got
> built**: a `Claude Usage` entry in the merged launcher
> (`shokupan-cmd-claude-usage.desktop`, via the `shokupan-launcher-cmds`
> generator) runs `~/.local/bin/claude-usage`, which reuses the model-usage
> plugin's own `claude_usage_scanner.py` and renders the reading as a
> notification: today's tokens, sessions and prompts, per-model split, and a
> seven-day sparkline. Option 2 was measured dead first, as suspected — the
> plugin is `kinds: ["bar-widget"]` only, so without a bar anchor
> `shell toggle omarchy.model-usage` is a silent no-op with no window to show.
> What the notification does not carry is the plan-limit percentages: those came
> from the OAuth side in QML, and re-implementing token refresh in a shell
> script is option-3 territory, declined. Verified live: two invocations minutes
> apart showed advancing numbers, so the reading is current at activation, not
> cached at generation.

The `omarchy.model-usage` widget — Claude Code usage and limits, with a tabbed
popup — is removed from the bar entirely. The intent it served is real and
stays: expose the usage reading from the app/command launcher (the ADR-0012 /
ADR-0027 lineage) instead, as a row you search for when you want it.

## Why it came off

It was placed during the quattro bar port (ADR-0029's addendum), first in the
right cluster, then hover-revealed in the centre's hidden group via a hosted
widget (`bar/modules/model-usage.qml`, the pattern CONTEXT.md documents). Even
hidden, it disrupted the bar's visual balance when revealed: every other member
of the hidden group is a single caption-sized glyph, and the usage chip is a
glyph *plus a live percentage label* — the one text-bearing item in a row of
icons, wider than its neighbours and changing width as the number does. The
hidden group reads as a set of switches; a metric does not belong in it.

The deeper reason is ADR-0029's own rule. The bar answers questions whose
answers are worth glancing at unprompted; usage-remaining is a question asked
deliberately, a few times a day, right before deciding whether to start
something expensive. That is launcher cadence, not bar cadence.

## Where it goes

The launcher (or the Omarchy Menu, whichever surface ends up carrying the
System Palette's row-with-detail idiom) gains a **Claude Usage** entry. Options,
in rising order of effort:

1. A row that fires `omarchy-launch-bar-settings`-style — runs a script that
   renders the same stats the widget's popup showed, via
   `omarchy-notification-send` or a floating TUI. Cheapest; loses the tabs.
2. A row that summons the existing popup through shell IPC —
   `omarchy-shell shell toggle omarchy.model-usage` — *if* the plugin's panel
   can open without its bar widget being mounted. Unverified; the widget owns
   the popup's anchor, so this may need the widget present-but-invisible.
3. A small dedicated panel plugin reusing upstream's `Widget.qml` internals.
   Most work; only worth it if 1 and 2 both disappoint.

Start with 1. The stats live in `~/.claude/stats-cache.json` and the plugin's
own `Model.js` documents the shape.

## What survives the removal

- **The hosted-widget pattern** (CONTEXT.md: *Hosted widget*) — proven by this
  module and reusable; the file is in git history at tag time of this ADR.
- The `providers.codex.enabled: false` preference: whatever surface shows usage
  next shows Claude only.

## Consequences

Until the launcher entry exists, usage is a terminal question (`claude` shows
it in-session). Nothing on the bar answers it, and that gap is this ADR's
deliberate trade: the bar's hidden group goes back to being a uniform row of
switch glyphs, which is what visual balance meant there.

---
status: accepted
---

# The bar stays dark in every theme, at a fixed Tailwind-950

> **Implementation deleted 2026-08-09, intent unported.** Both halves are gone:
> `theme-override.css` was removed with Waybar, and the
> `theme-set.d/20-waybar-theme-override` hook that generated it no longer exists
> anywhere on the system — quattro ships no `theme-set.d` at all. So the bar
> currently follows the theme, which is exactly what this ADR argues against.
> ADR-0033 rates the port "modest work"; it has not been done. Old file: tag
> `omarchy-v3.8.4-prequattro`.

Waybar is pinned to `#0b0c14` — roughly Tailwind's 950 level — regardless of the
active Theme's Appearance. The bar reads as system chrome rather than as part of
the theme, and that only works if it stays put. Implemented as a generated
`~/.config/waybar/theme-override.css`, imported *after* the theme's own
`waybar.css` in `style.css`, and rewritten by the
`theme-set.d/20-waybar-theme-override` hook on every theme change.

This is a deliberate deviation: the obvious thing is to let the bar follow the
theme like every other component, and a future reader would otherwise "fix" it.

## Consequences

A fixed dark bar breaks light themes. A light Theme supplies a **dark**
foreground — Catppuccin Latte's is `#4c4f69` — which is invisible on a near-black
bar. So for light themes the hook also overrides the foreground, reusing the
theme's own background colour (light by definition) to keep the bar tinted to the
theme rather than hardcoding a grey.

Light themes are detected solely by the `light.mode` marker file in the active
theme. Any theme lacking that marker is treated as dark, which is why a generated
theme without one renders dark-on-dark (ADR-0008).

`omarchy-theme-set` restarts Waybar *before* hooks run, so it has already loaded
the previous override by the time the hook writes the new one. The hook restarts
Waybar a second time. That double restart is intentional, not redundant.

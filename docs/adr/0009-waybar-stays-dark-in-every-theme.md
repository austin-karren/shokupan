---
status: superseded
superseded-by: 0033
---

# The bar stays dark in every theme, at a fixed Tailwind-950

> **Ported to quattro 2026-08-09.** The decision stands unchanged — the bar is a
> fixed Tailwind-950 in every theme — but every part of the mechanism below is
> obsolete. See the addendum at the end.
>
> **Scoped to Tokyo Night 2026-08-15.** "In every theme" no longer holds: the
> dark bar is now a Tokyo Night property, and other themes get stock bar
> colors. See the second addendum.
>
> An earlier draft of this note claimed the generating hook "no longer exists
> anywhere on the system". That was wrong: it was looked for at
> `~/.config/omarchy/theme-set.d/`, and the real path is
> `~/.config/omarchy/hooks/theme-set.d/`. The hook was still installed and still
> firing.

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

## Addendum: the quattro port, 2026-08-09

The decision survives; the hook does not. Quattro's bar reads its colours from
`Color.bar.background`, which resolves the `[bar] background` key of
`~/.local/state/omarchy/current/theme/shell.toml` — a file *generated* on every
theme change from a template. User templates in `~/.config/omarchy/themed/`
take priority over `/usr/share/omarchy/default/themed/`, so the port is a tracked
`.config/omarchy/themed/shell.toml.tpl` with two lines changed:

    background       = "#0b0c14"     # was "{{ bg }}"
    text             = "#c0caf5"     # was "{{ fg }}"

That is the sanctioned extension point, so no Omarchy file is patched and no hook
runs. The old `theme-set.d/20-waybar-theme-override` is deleted — it was still
firing and would have recreated `~/.config/waybar/` as untracked junk after the
config deletion.

**Three things changed in the reasoning, not just the syntax:**

1. **Light themes are no longer detected.** The template engine does variable
   substitution with no conditionals, and no single variable is readable on a
   near-black bar in both modes — Catppuccin Latte's `fg` *and* `bright_fg` are
   both `#4c4f69`. So the foreground is a literal too. The consequence section
   above preferred tinting light-theme text with the theme's own background over
   "hardcoding a grey"; that nicety is gone, and light themes now get a fixed
   `#c0caf5`. It is a small loss and it makes the bar more honestly what this ADR
   says it is: fixed chrome.
2. **The `light.mode` marker file is gone.** Appearance is now `mode = "light"`
   in the theme's `colors.toml`. Nothing reads it here yet, but a future template
   engine with conditionals could restore the tinting behaviour from it — and it
   also removes ADR-0008's failure mode, where a generated theme missing the
   marker rendered dark-on-dark.
3. **Transparency is a separate axis.** Quattro's bar has a `transparent` flag,
   toggled by double-left-clicking empty centre-bar space. This ADR governs the
   *solid* state only; transparent mode computes its own contrasting foreground
   against the wallpaper and is left alone.

Verified by rendering, not asserted: after `omarchy-theme-set tokyo-night`, the
generated `shell.toml` carries `[bar] background = "#0b0c14"` while `[popups]`
still carries the theme's own `#1a1b26`, so the override is scoped to the bar.

The one cost: a user template **replaces** the built-in wholesale rather than
merging, so ours will not inherit upstream changes to the other sections. Re-diff
`.config/omarchy/themed/shell.toml.tpl` against
`/usr/share/omarchy/default/themed/shell.toml.tpl` after an Omarchy upgrade.

## Addendum: scoped to Tokyo Night, 2026-08-15

The wholesale template fork is retired, and with it the "every theme" scope.
r1744's `omarchy-theme-set-templates` grew `apply_shell_section_overrides`: a
theme may ship `shell.<section>.toml` files that are spliced over the matching
section of the generated shell.toml — stock tokyo-night already ships
`shell.lock.toml` this way. So the pinned bar now lives in
`.config/omarchy/themes/tokyo-night/shell.bar.toml`, a user-theme overlay that
`omarchy-theme-set` copies over the stock theme into its staging directory.

What that changes:

1. **The decision is per-theme now.** Tokyo Night — the theme this rice
   actually runs — keeps the fixed Tailwind-950 bar. Every other theme,
   light themes included, gets its stock bar colors, which dissolves the
   quattro port's light-theme regression (fixed `#c0caf5` text on a dark bar
   under a light theme) instead of mitigating it.
2. **The full-template copy is gone.** The override carries one section
   instead of all of them, so upstream changes to every other section flow
   through untouched. The fork line leaves `packages/forks`.
3. **The residual coupling is smaller but not zero.** Section overrides
   replace the *whole* `[bar]` section, so the file must carry upstream's
   non-color keys verbatim, and `active` as a literal (overrides are spliced
   after template substitution, so `{{ red }}` would not resolve). Re-check
   the file against upstream's `[bar]` section after an upgrade — a one-section
   diff instead of a whole-template diff.

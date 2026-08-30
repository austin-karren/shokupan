---
status: accepted
---

# Aether may generate themes, but not apply them

> **Verified under quattro, 2026-08-09.** The decision holds and was re-proven by
> use: a theme generated from the pinned wallpaper registered without applying,
> applied cleanly when asked (`omarchy theme set`), rendered live (screenshot),
> and removed cleanly after switching away. `includeGtk` is still `false`.
> Two staleness fixes in the wrapper, one of them real: the `--remove` guard read
> the pre-quattro `theme.name` path, so it compared empty-to-slug and never fired
> — removing the *live* theme was one typo away from an `rm -rf` out from under
> the session. It now reads `~/.local/state/omarchy/current/theme.name` and was
> measured refusing. And the `light.mode` half of "two gaps" below is retired:
> quattro dropped the marker file, the mode is the `mode =` line in `colors.toml`,
> which Aether writes itself. The empty-`backgrounds/` gap also softened — the
> swaybg black-screen fallback died with swaybg — but seeding stays, since a theme
> with no background still visibly does nothing when switched to. Note Aether
> 4.28 emits pre-quattro extras (`waybar.css`, `walker.css`, `hyprland.conf`);
> quattro ignores them and re-renders its own surfaces from `colors.toml`
> templates, so they are clutter, not breakage.

Aether (pacman `aether`) extracts a Palette from an image
and renders a Theme from it. Its own apply path takes over
`~/.config/omarchy/current` directly. We keep the generator and reject the apply
path: `~/.local/bin/aether-theme` generates with `--no-apply` into an ordinary
named theme under `~/.config/omarchy/themes/`, after which it is just another
Omarchy theme — switch to it, switch away, `omarchy theme remove` it.

## Consequences

`includeGtk` is **off** in `~/.config/aether/settings.json`, and must stay off.
Nothing in Omarchy's `bin/` references `~/.config/gtk-3.0` or `gtk-4.0`, so
Omarchy can never reclaim a `gtk.css` that Aether writes there — it is permanent
drift that outlives every subsequent theme change. Aether's CLI defaults `--gtk`
off; its GUI had turned it on.

Two gaps in Aether's output that the wrapper fills:

- A theme applied from a palette-only source (imported base16, a blueprint, the
  GUI with no image picked) has an **empty** `backgrounds/` directory, which
  triggers the black-screen fallback described in ADR-0007. `aether --generate
  <wallpaper>` does copy the image in; the other paths do not. The wrapper
  guarantees a background either way. - Aether never writes the `light.mode`
  marker, so Omarchy cannot tell a generated light theme from a dark one — and
  the Waybar override hook (shokupan-plugins ADR-0009) keys off exactly that
  file, so a light theme would render dark-on-dark. The wrapper reads `mode`
  from the generated `colors.toml` and writes the marker.

`aether upgrade` self-updates outside pacman, so a future version can reintroduce
the GTK write regardless of the setting. Re-check after upgrades.

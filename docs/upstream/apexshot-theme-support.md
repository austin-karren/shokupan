# Draft feature request: let ApexShot's accent colour be configured

**Status: draft — not posted.** Same rule as the other drafts here (ADR-0044
rule 5): written for review, posted only on an explicit go.

Upstream: ApexShot (`apexshot` 0.2.34-1, GTK4).

## Title

Allow the UI accent colour to be configured, so ApexShot can match a themed
desktop

## Body (draft)

ApexShot exposes two colour settings today, and both are useful:

- `config.yml` → `wallpaper_plain_color` — the backdrop behind a capture
- `editor_prefs.yml` → `color` — the annotation pen

On a themed desktop (here: Omarchy on Hyprland, where every app's colours are
generated from one `colors.toml` per theme) those two are enough to make
*captures* match the desktop. What cannot be matched is ApexShot's own UI: the
toolbar and quick-access chrome are a fixed terracotta family — `#b05c38`
appears throughout, alongside `#c06540`, `#9a4c2c`, `#e8764a` and `#f0a07a` —
which reads as an orange app on an otherwise coherent desktop.

As far as I can tell there is no way to change it: no key in `config.yml`, no
stylesheet shipped in `/usr/share/apexshot/`, and the values appear to be
compiled in. The only lever left is a GTK4 user stylesheet
(`~/.config/gtk-4.0/gtk.css`), which loads at a higher priority than
application CSS — but that repaints *every* GTK4 application on the machine to
fix one, which is not a trade worth making.

### What would help, in rough order of preference

1. **An accent colour setting** — one key in `config.yml`
   (e.g. `ui_accent_color: '#f7768e'`), defaulting to today's terracotta so
   nothing changes for existing users.
2. **Honour the system accent** — GNOME exposes
   `org.gnome.desktop.interface accent-color`, and libadwaita apps follow it.
   ApexShot links GTK4 but not libadwaita, so this would need doing by hand,
   but it is the option that requires no configuration at all.
3. **Ship the accent in an overridable stylesheet** under
   `/usr/share/apexshot/`, so a user can point at their own copy — cheapest to
   implement, and enough for scripted theming.

Happy to test a patch on Arch (GTK4, Wayland/Hyprland).

## Notes for us (not part of the issue)

- Whatever upstream does, the machine-side wiring already exists:
  `.config/omarchy/hooks/theme-set.d/40-theme-apexshot` drives the two existing
  keys on every theme change. A third key would be a two-line addition there.
- Two other things noticed while reading `config.yml`, unrelated to theming and
  worth deciding separately: `telemetry_enabled: true` and
  `start_at_login: true` are both on by default.

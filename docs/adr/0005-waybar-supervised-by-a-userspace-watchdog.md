---
status: superseded
superseded-by: 0033
---

# Waybar is supervised by a polling watchdog, not systemd

Waybar is unsupervised under Omarchy: Hyprland's autostart launches it with
`uwsm-app -- waybar`, which lands in a transient systemd **scope**. Scopes carry
no `Restart=` policy, so when Waybar segfaults — GTK3/GDK crashing while reloading
cursors on a theme change is the one we hit — the bar silently disappears until
started by hand. `~/.local/bin/waybar-watchdog` polls for it and brings it back.

Chosen over converting Waybar into a proper systemd user *service*, which would
mean fighting Omarchy's autostart on every update.

## Consequences

The watchdog must respect the `waybar-off` toggle (`SUPER+SHIFT+SPACE`), or it
fights the user's intentional hide. It also gives up after 5 restarts in 300
seconds rather than crash-looping forever.

This is a workaround for an upstream crash, not a fix. If the GDK cursor-reload
crash is fixed upstream, the watchdog becomes dead weight and should be removed.

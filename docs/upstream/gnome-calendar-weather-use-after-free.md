# Draft issue: weather service use-after-free when GeoClue stops shortly after launch

**Status: draft — not posted.** Per ADR-0044 rule 5: issue first, PR only
after upstream's temperature is known, nothing posted without an explicit go.
Target: GNOME Calendar's GitLab (gitlab.gnome.org/GNOME/gnome-calendar).

## Title

Weather service: use-after-free in `on_gclue_client_stopped_cb` — SIGSEGV
when GeoClue idles out ~10s after launch (50.0)

## Body (draft)

GNOME Calendar 50.0 segfaults roughly ten seconds after launch when the
weather feature is enabled. The crash is a use-after-free in the weather
service: `on_gclue_client_stopped_cb`
(`src/weather/gcal-weather-service.c:810`) runs when GeoClue's asynchronous
`Stop` reply lands, and unrefs a `GClueSimple` that has already been freed by
then. GeoClue idling out shortly after the app starts is what delivers the
late reply into the dead object.

Three cores were collected on 2026-08-15 (systemd-coredump, all SIGSEGV in
`/usr/bin/gnome-calendar`); the diagnosis above comes from symbolizing one
against CachyOS's debuginfod (https://debuginfod.cachyos.org). The crash was
initially misattributed to GApplication command-line forwarding because it
followed warm `--date` invocations by ~10s — the symbolized frames put it in
the weather service instead, and the timing matches GeoClue's idle stop, not
the forwarded command line.

### Version

- GNOME Calendar 50.0 (Arch-family package, CachyOS)
- Crashes observed 2026-08-15; cores retained in systemd-coredump storage on
  this machine and available for further symbolization on request.

### Reproduction sketch

1. Enable weather in Calendar's menu (`org.gnome.calendar weather-settings`,
   first tuple element `true`).
2. Launch gnome-calendar and leave it running.
3. Wait for GeoClue to idle-stop, ~10s after launch.
4. SIGSEGV in the primary instance when the async Stop reply reaches
   `on_gclue_client_stopped_cb`.

### Workaround

Disable the weather feature:
`gsettings set org.gnome.calendar weather-settings "(false, true, '', @mv nothing)"` —
no crashes since.

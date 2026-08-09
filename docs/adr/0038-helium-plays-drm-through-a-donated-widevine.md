---
status: accepted
---

# Helium plays DRM through a donated Widevine, and Chrome is gone

Helium is a de-Googled Chromium fork, so it ships without Widevine — the CDM that
DRM streaming (Spotify, Netflix, and anything EME) requires. Google Chrome was
installed once, solely to donate its CDM into Helium's profile; the package has
since been removed. This records why a de-Googled browser plays DRM here, and why
no `google-chrome` package exists despite a `~/.config/google-chrome` directory.

The CDM is the same Google-signed artifact no matter which browser fetched it —
byte-identity between the Chrome and Helium copies proves nothing about
provenance, only that both came from Google's component server. That is also why
the donation is sustainable: Helium's own component updater now keeps it current
at `~/.config/net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm`,
so the donor was needed once, not kept.

Considered and rejected: keeping Chrome installed as a permanent CDM source
(carries a second whole browser for one shared library) and going without DRM
(the machine streams).

Consequences:

- `~/.config/google-chrome/` is a leftover profile, not evidence of an install.
  It still holds the originally-donated CDM; a second copy sits in
  `~/snapshots/pre-omarchy-update-20260808-152759/chrome-WidevineCdm/`. Safe to
  delete once playback is confirmed.
- One verification is still owed: an actual DRM stream in Helium since Chrome's
  removal. Component-updater presence says the CDM is there, not that EME
  negotiates.

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

*Addendum 2026-08-15: the donation is now reproducible.* The mechanism, read
off the live profile: Helium finds the CDM through a JSON pointer file,
`<profile>/WidevineCdm/latest-component-updated-widevine-cdm`, whose `Path`
names a versioned directory holding `manifest.json`, `LICENSE` and
`_platform_specific/linux_x64/libwidevinecdm.so` — the same layout Chrome's
component updater writes, and the same pieces Chrome's package bundles
versionlessly at `/opt/google/chrome/WidevineCdm`. `loaf widevine` performs
that copy idempotently from any Chrome-sourced layout on disk (the bundled
copy, a chrome-profile versioned copy, or the snapshot this ADR mentions), and
`loaf install` runs it as a step — non-fatally, since a fresh machine may lack
a donor. A `loaf doctor` check asserts the donation is present and
version-consistent (pointer, directory name and manifest version agree).

Ownership of drift is split deliberately: **doctor notices, heal does not
redonate.** A donation already present is never touched by `loaf widevine`
either — after the first copy Helium's component updater owns currency, and if
Chrome reappears with a different bundled version doctor warns rather than
fails. Swapping a browser's DRM blob is an attended operation, not something a
post-update hook should do behind anyone's back.

The owed verification above still stands; the README's to-do now points at the
doctor check as the presence half of it.

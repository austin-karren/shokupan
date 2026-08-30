# Draft issue: add Helium to omarchy-default-browser's list

**Status: draft — not posted.** Per shokupan-plugins ADR-0044 rule 5: issue
first, PR only after upstream's temperature is known, nothing posted without an
explicit go.

## Title

`omarchy-default-browser` cannot set Helium — a Chromium fork Omarchy users
install — and its position ahead of `~/.local/bin` means users cannot extend it

## Body (draft)

`bin/omarchy-default-browser` hardcodes seven browsers (chromium, chrome,
brave, brave-origin, edge, firefox, zen). [Helium](https://helium.computer) is
a de-Googled Chromium fork that Omarchy users install (AUR:
`helium-browser-bin`); anyone running it can set it as default only by calling
`xdg-settings` by hand, because the Setup > Default Browser menu rows and the
script both stop at the seven.

It also cannot be fixed user-side by shadowing the script: Omarchy's bin
directory precedes `~/.local/bin` on PATH, so a same-named wrapper is never
reached.

The addition is one case line in each half of the script, mirroring the
existing entries — desktop id `helium.desktop` (what `helium-browser-bin`
installs to `/usr/share/applications`), binary `helium-browser`:

```bash
# in the getter:
helium.desktop) echo "helium" ;;

# in the setter:
helium) desktop_id="helium.desktop"; name="Helium"; glyph=󰖟 ;;
```

plus the matching `setup.default.browser.helium` row in `omarchy-menu.jsonc`,
same shape as the zen row (`when: omarchy-cmd-present helium-browser`).

Happy to send the PR if you'd take it.

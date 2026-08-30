# Draft issue: the network bar widget hardcodes its ethernet glyph

**Status: draft — not posted.** Per shokupan-plugins ADR-0044 rule 5: issue
first, PR only after upstream's temperature is known, nothing posted without an
explicit go.

## Title

Network bar widget: make the connection glyphs configurable (settings schema),
or at least the wired one

## Body (draft)

`shell/plugins/panels/network/Model.js` `connectionIcon()` hardcodes the
wired glyph as U+F0200 (the RJ45 socket). There is no settings-schema entry
to change it, so anyone who prefers a different wired glyph — here, the globe
U+F059F, on the reading that the icon answers "am I on the internet", the
same question the Wi-Fi bars answer, not "which cable is plugged in" — has to
carry a fork.

This rice has now carried that one-glyph delta through three implementations
(a Waybar `format-ethernet` override, a hosted wrapper that re-pointed the
button's text binding and died at the r1744 panel restructure, and currently
a full `omarchy plugin clone` of the network plugin for one changed line). A
`barWidget.settings` entry — `wiredIcon`, or a general glyph map — would end
the fork permanently, exactly the kind of thing the clone/settings machinery
seems built for.

Happy to PR either shape if there's interest.

## Rice context (not for the issue)

Current carrier: `.config/omarchy/plugins/austinkarren.network/`, one `//
SHOKUPAN:` line in Model.js, fork line in `packages/forks` (shokupan-plugins
ADR-0029, "Wired shows a globe, not a port"). If upstream lands a setting, the
clone is deleted and the setting goes in `shell.json`.

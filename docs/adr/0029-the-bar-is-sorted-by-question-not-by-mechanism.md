---
status: accepted
---

# The bar is sorted by the question each module answers

> **Reimplemented on quattro 2026-08-09.** `config.jsonc` and `style.css` are
> deleted. The rule below survives and now lives in
> `.config/omarchy/shell.json`; the whole *Spacing* section is void, because
> quattro lays the bar out natively and there is nothing to measure. See the
> addendum at the foot.

Three changes made together, because they are one decision applied three times:

| Change | Before | After |
|---|---|---|
| Weather moves to the centre | right cluster, after `custom/ratio` | centre, right of the clock |
| Calendar moves left of the clock | right of the clock | left of the clock |
| The `cpu` module is deleted | static chip glyph, click opens btop | gone; btop on `SUPER CTRL + T` |
| Ethernet gets a globe | `󰈀` RJ45 port (U+F0200) | `󰖟` web (U+F059F) |

The rule they share: **a module earns its place by the question it answers, not by
the subsystem it reads from.**

## The centre answers "what day is it, and what is it like out there"

The centre now reads calendar, date, weather — the two things you click to ask about
a day, flanking the day itself. Weather had been filed on the right because it comes
from a network fetch, which is a fact about its plumbing and not about what it tells
you. It is about *now*, exactly as the clock is; the right cluster is about this
*machine*. Grouping by provenance put a "what's it like outside" reading next to a
volume icon.

Calendar moves to the left of the clock rather than staying on its right, so the two
icons bracket the date symmetrically instead of stacking two icons on one side.

## The right cluster is state, so a button did not belong in it

Everything from `bluetooth` rightwards *reports*: connected or not, which network,
what volume, how much battery. `cpu` did not. Its glyph was the static string `󰍛` —
it never showed load, never changed, and existed only to give btop a click target. A
button wearing a status icon's clothes, in a row where every other glyph means
something by changing.

So it is deleted rather than fixed. Making it report load was the other option and
is worse: this is a desktop that is idle most of the time, so the module would spend
its life displaying a number nobody asked for, and Waybar's centre and right groups
are already the crowded ones.

btop moves to `SUPER CTRL + T`, which is Omarchy's own chord for it
(`default/hypr/bindings/utilities.conf`, "Activity") — so nothing has to be learned,
and the keybind list gains an entry that was already there. It is rebound only to
swap `omarchy-launch-tui` for `window-toggle`, giving it the close-on-second-press
behaviour the bar icon had and that `bluetooth` and `network` already use. That
settles the `cpu` half of ADR-0011 by deleting its subject; the `pulseaudio` half
still stands.

`custom/apexshot` and `custom/ratio` remain on the right and remain actions, which
is the one exception, and a deliberate one — ADR-0013 placed them there as the
cluster's action prefix, before the status run begins.

## Wired shows a globe, not a port

`format-ethernet` was `󰈀`, a picture of the RJ45 socket. The socket names the
*cable*. The question the icon actually answers — the same one the wifi bars answer
directly above it in the config — is whether this machine is on the internet, and a
globe says that without asking you to know what a physical layer is.

## Spacing

### The centre trio

Every centre module carries a **left margin only**, so each gap is written in exactly
one place and two adjacent margins can never sum into a double gap. Both icons get
`min-width: 18px` — equal, so the trio stays symmetrical about the date, and fixed, so
the weather glyph's 15..27px swing between sun, moon and cloud cannot slide the clock
sideways underneath it.

The margin is 5.5px, tighter than the 7.5px used by the modules that follow
(`custom/update`, `custom/voxtype`): the trio is one thing, and should bind more
tightly to itself than to the indicators beside it. Measured ink gaps land at 18px
calendar-to-date and 21px date-to-weather — the 18px being exactly what the
date/calendar pair sat at before weather joined them.

The 3px asymmetry between those two gaps is the clock's own right side bearing, the
`M` ending "PM". No margin can fix it, because it changes with the format string:
`format-alt` ends in a digit. Left alone deliberately.

### The right cluster

Removing two modules left the survivors on the same grid, exactly as the uniform-pitch
design (ADR-0013) predicted. That turned out to be the problem rather than the proof.

### Uniform pitch was the wrong invariant

With weather and cpu gone, the gap to the left of the network globe read as a hole.
The boxes were not at fault — painting each module a flat colour showed spans of
exactly 29 physical px, pitch exactly 50.0, inter-box gaps exactly 21. The grid was
perfect. It was the wrong grid.

**Pitch is not what the eye reads; it reads the gap between ink.** The bluetooth rune
is 10.6 physical px wide where its neighbours are 16..19, at the same 16px ink height
— narrow, not small. Centred in a shared 18px box it floated in ~9px of air per side
against its neighbours' ~5, and the surplus pooled beside the globe. Every module
obeyed the rule and the result still looked wrong, which is the signature of an
invariant that was never the goal.

The original comment defended uniform pitch on the grounds that ink changes between
states, so no static margin set could equalise ink gaps. That is true only while every
box is the same width. Size each box to its own glyph and the gap collapses to the
margins, which are static — so the conclusion inverts.

Two measurements were needed before that was usable:

1. **These Nerd Font icons do not advance like text.** Pango allocates them about one
   monospace cell wide regardless of how wide the glyph is drawn, so ink overflows the
   box by a different amount per glyph. The obvious fix — let boxes size to content —
   therefore makes things *worse*: gaps came out 30/23/24/30/28. Only an explicit
   width per glyph works, which is why this ADR ends in a table of measured ink.
2. **Waybar emits state classes to hang those widths on.** Verified by painting
   `#network.ethernet` and `#bluetooth.on` and watching the box change, with
   `#bluetooth.off` correctly not matching while bluetooth was on.

The bluetooth glyph also changed family on the way: `format` was `U+F294`, Font
Awesome's `bluetooth_b`, while the *same module's* other three states were already
Material Design. It is now `U+F00AF`, so all four states are one family.

### What it measures

Every state was forced by patching both the glyph and the width its class would
apply, then measured from a screenshot — not predicted from font metrics.

| state | ink gaps (physical px, 1.67x) | spread |
|---|---|---|
| *before, any state* | 31, 32, **38**, 33 | **7** |
| bt on / ethernet / headphone | 31, 30, 30, 31 | 1 |
| bt connected | 31, 30, 31, 31 | 1 |
| bt off / disabled | 31, 30, 30, 31 | 1 |
| network wifi (all five bars) | 31, 30, 32, 30 | 2 |
| network disconnected | 31, 30, 32, 30 | 2 |
| pulseaudio vol-low | 31, 30, 30, 32 | 2 |
| pulseaudio vol-high | 31, 30, 30, 31 | 1 |
| pulseaudio muted | 31, 30, 30, 31 | 1 |

Because a module's width never depends on a *neighbour's* state, nothing moves when
another module changes.

### The two compromises, stated plainly

**Pulseaudio has no per-state control.** Waybar emits no class we could find — eight
candidate names probed, none matched — and its volume ramp is picked by array index,
which has no class at all. It is pinned to the headphone width. Measured cost: +2px on
the gap to its left at low volume, nothing at high volume or muted. It is the
rightmost module, so a width change there moves only its own left gap instead of
reflowing the cluster; anything with an unclassable ramp belongs on that end.

**Two margin pairs are asymmetric** — `#bluetooth` at 9.6/7.6 and `#bluetooth.connected`
at 8.1/9.1, against the uniform 8.6. These cancel ~1.5px of subpixel rounding, not a
neighbour's state: `custom/ratio` has a single fixed glyph (it carries state by opacity
per ADR-0013, not by a second glyph), so the offset it contributes is constant and safe
to cancel. That is the distinction that makes it legitimate, and it does not generalise
— do not copy the trick onto a module whose neighbour changes glyph.

The wider gap before the tray chevron is neither of these and is left alone:
`#custom-expand-icon` sits inside `group/tray-expander`, whose layout governs it —
`min-width` there changes nothing, swept across four values to confirm — and the gap
reads as the boundary between the drawer and the status run.

## Consequences

`#custom-weather.unavailable` still collapses the module to zero width, which now
matters more than it did — an 18px hole would open between the date and the
indicators rather than at the end of a row of icons.

Nothing checks any of this. `loaf doctor` verifies that the config files are the
repo's, not what they contain, so a future upstream Waybar default that reintroduces
`cpu` would be caught as a displaced symlink but a hand-edit would not.

## Addendum: tailscale sits with the radios, not with network

Added 2026-08-08. The tailscale module landed to the right of `network`, on the reading
that it answers the next question up the same stack — network says whether this machine
is on the internet, tailscale whether it is on the tailnet. That is a defensible
application of the rule above and it is not the one this bar uses.

It now sits **left of bluetooth**, at the head of the radios: `ratio | tailscale |
bluetooth | network | pulseaudio`.

The distinction the rule was missing: the right cluster is not uniformly "state you
read". Bluetooth and tailscale are things you **turn on and off** — one click, an
immediate change to what this machine is connected to. Network and battery you only
read. Sorting by the question alone put a toggle between two readings; sorting by what
you *do* with it keeps the toggles adjacent and the readings adjacent.

So the rule stands, with a tiebreak: **when two modules answer related questions, group
by whether you act on them or only read them.**

No measurement changed — every box in the cluster carries a uniform margin and a width
derived from its own glyph, so reordering moves no gap. Verified after the move.

## Addendum: the layout on quattro, 2026-08-09

The rule and its tiebreak both ported. The bar now reads (⌁ marks the
hover-revealed modules, invisible until the pointer is on their section):

    left    menu(power glyph) · workspaces · ⌁bar-settings
    centre  media · calendar · CLOCK · weather · system-update · ratio(on-face)
            · indicators · ⌁ratio(off-face)
    right   tray · notifications · apexshot · sp2 · tailscale · sp3 · bluetooth
            · sp2 · network · audio · sp9 · monitor · power

The Claude-usage chip was in the hidden group for part of the day and is gone
per ADR-0039: it was the group's one text-bearing member, and a metric is not a
switch. The hosted-widget pattern it proved outlives it.

**The hover tier is new, and it is a third answer to this ADR's question.**
Waybar offered two states: on the bar or not. Quattro's centre reveals quiet
modules on hover, and that changed several placements. `ratio` and
`model-usage` live there, hover-only in every state — `ratio` shows *which*
state by colour while revealed, but earns no resting width either way.
`calendar` is deliberately **not** in the hover tier: it is the left half of
this ADR's bracket around the date, and a bracket that is usually missing is
not a bracket. It is static in the slot quattro's own bar-config control used
to reveal into; that control is suppressed (`centerAnchor: ""` — the built-in
only renders when the anchor is the clock, and restoring it would put a gear
back into the calendar's slot on hover) and rebuilt as a hover module after
the workspaces, so it slides right as workspaces are added.

`media` joins the centre because it answers a *now* question like the clock and
weather. `notifications` and `microphone` are **not** added: the indicators
cluster already answers "did anything happen" and dictation state, and a second
bell and a second mic would be the provenance-sorting mistake this ADR opens
with, applied to new modules.

**One departure worth naming:** giving up `centerAnchor` costs the pinned-clock
guarantee — the centre now centres as a group, so a very wide media label can
shift the date sideways. That trade was accepted to delete the built-in config
button's slot; if it grates, the anchor comes back at the cost of a second gear
appearing on clock hover.

**Tailscale is upstream's now.** `omarchy.tailscale` is a first-party plugin with
a connection switcher and machine browser, so `tailscale-icon` is retired rather
than ported. The addendum above argued about *where* it goes; that answer is
unchanged, only the implementation is upstream's.

**The ink-gap discipline came back, scaled down.** The Spacing section above
exists because Waybar made the author own pixel geometry; quattro mostly does
not, but two imbalances were visible and were fixed the same way — measured
from screenshots, not eyeballed (physical px at scale 1.6):

- *Centre bracket*: calendar→date was 28 against date→weather's 23, because the
  calendar module carried +13 logical padding. Reduced to +8; measured after at
  **23 / 23**.
- *Right cluster*: audio's speaker glyph draws its sound waves into the right
  half of a fixed 27-unit box, leaving ethernet→speaker at 33 while
  speaker→monitor collapsed to 18, and the rest of the cluster ran 27–30.
  Upstream widgets expose no margin settings, so the levers are
  `omarchy.spacer` entries and — for `apexshot`, the one command module —
  its own `horizontalMargin` setting. Worked **right to left**, widening
  each gap to match the immovable 33 (ethernet→speaker, fixed by the audio
  box): margin 9.5 on apexshot, spacers 2/3/2/9. Measured after:
  **34, 33, 33, 33, 33, 33** — uniform within one physical pixel, which is
  the Waybar-era discipline restated: near-uniform ink gaps, a pixel or two
  conceded only where a glyph's own advance forces it.

**The clock is 12-hour** — `"dddd h:mm AP"` ("Sunday 3:42 PM"). Nothing had
recorded a time-format decision before; this line is it. The alt format (click)
stays the ISO-ish date.

**Wired shows the globe again.** Quattro's network widget hardcodes 󰈀 in its
package `Model.js` with no setting, so the "Wired shows a globe, not a port"
section above is re-implemented as a Hosted widget
(`bar/modules/network.qml`): upstream's whole panel, with only the bar button's
text binding re-pointed through a one-glyph map (U+F0200 → U+F059F). Wi-Fi
glyphs pass through untouched. If an upgrade restructures the panel, the map
silently stops applying and the socket comes back — visible, not broken.

**The hidden list is ordered, and the ratio sits second.** The indicators
widget allows multiple instances with `items` subsets, so the cluster is split
around the ratio's off-face: `[Dnd] · ratio · [Reminder, NightLight, StayAwake,
ScreenRecording, Dictation]` — silence-notifications first, the zen toggle
second, upstream's default order for the rest.

**The audio gaps are tuned to the eye, not the ruler — both sides.** The eye
reads the speaker's solid cone as the icon and discounts the wave arcs (even
though their ink is dense — measured at full column weight, so this is
perception, not rendering). Two consequences, fixed right to left with guide
overlays drawn on screenshots at each step:

- *Right of the speaker*: the spacer after audio went 8 → 4, leaving a raw ink
  gap of 24 that reads as ~33 once the discounted waves are added back.
- *Left of the speaker*: upstream's network button carries
  `rightExtraMargin: 5.5`, which lands as the speaker's left margin. The hosted
  wrapper sets it to 2, and the spacer between bluetooth and network was
  removed to keep the bluetooth side even.

Final measured run: **34 · 33 · 33 · 32 · 31 · 24(+waves)** — a smooth drift,
no spike on either side of the speaker. The refinement to the uniform-ink
rule: ink that trails off (wave arcs, ramp glyphs) counts fractionally, and a
glyph with trailing ink needs *both* of its gaps re-judged, not just the
trailing side.

**The menu button wears the rice's power glyph** (`omenu` QML module, U+F011 —
the same glyph `custom/omarchy` carried on Waybar). Upstream's widget hardcodes
its logo in a private icon font with no setting, so the swap is a module that
reuses upstream's own two click actions verbatim.

**`omarchy.notifications` is back** at the head of the right cluster, next to
the tray, where an earlier pass had removed it as duplicating the DND indicator.
The bell is a popup surface (recent notifications, DND toggle), not just a
state light — the indicator answers "am I silenced", the bell answers "what did
I miss", and those are different questions. The microphone module remains the
one quattro widget deliberately not placed.

# Draft issue: the weather bar widget hides itself when its fetch fails

**Status: draft — not posted.** Per shokupan-plugins ADR-0044 rule 5: issue
first, PR only after upstream's temperature is known, nothing posted without an
explicit go.

## Title

Weather bar widget: don't render as "removed" when the fetch fails

## Body (draft)

**System details:** Omarchy 4.0.0.alpha, `/usr/share/omarchy` dated 2026-08-14.

I restarted the shell while wttr.in was returning HTTP 500. The weather pill
never came back — no glyph, no gap, no error, nothing to click. I assumed the
widget had been deleted, not that a third-party service was down.

**The cause: `visible` is bound to the fetch result, not to "is there
anything to show."**

`shell/plugins/panels/weather/BarWidget.qml`:

```
visible: panelLoader.item && panelLoader.item.label !== ""
```

`label` starts empty (`Panel.qml`: `property string label: ""`) and is written
in exactly two places, both on a successful HTTP response — the wttr branch:

```
if (!root.hasConfiguredCoordinates)
  root.label = Model.provisionalCurrentIcon(parsed.current_condition && parsed.current_condition[0], root.label)
```

and the open-meteo branch:

```
root.label = Model.currentIcon(parsedCurrent, root.label)
```

If neither request ever succeeds, `label` stays `""` forever and the widget
never has a nonzero width. Nothing is persisted to disk, so a fresh widget
instance (shell restart, `omarchy restart shell`, logout) starts from that
same empty string every time.

**Every other bar widget hides on semantic absence, not on a failed fetch.**
Surveying `shell/plugins/bar/widgets/`:

```
SystemUpdate.qml:   visible: updateAvailable
Tray.qml:            visible: pinnedItems.length > 0 || drawerCount > 0
Microphone.qml:       visible: source !== null
KeyboardLayout.qml:   visible: layoutLabel !== "" && multipleLayouts
ActiveWindow.qml:      visible: title !== "" && !vertical
Spacer.qml:             visible: span > 0
```

Each of those conditions is a true "there is nothing to show" — no update
pending, no tray items, no microphone, one keyboard layout, no focused
window, a zero-width spacer. None of them can go false because a network
request 500'd. Weather is the only bar widget where "hidden" means "a fetch
failed," and there is never a state that means "there is truly no weather" —
the condition just aliases the two.

**Why it can get stuck this way for a while, not just for a moment.** With no
location configured — or a location set by name only, e.g.
`omarchy-weather-location --set <city>`, which writes `{"name":"<city>"}` and
leaves coordinates unset — the open-meteo request that could otherwise
recover the pill can't fire either. `refreshDailyForecast` in `Panel.qml`:

```
var lat = parseFloat(String(root.configuredLocationState.latitude))
var lon = parseFloat(String(root.configuredLocationState.longitude))
if (isNaN(lat) || isNaN(lon)) {
  var area = sourceReport && sourceReport.nearest_area && sourceReport.nearest_area[0] ? sourceReport.nearest_area[0] : root.areaInfo
  if (!area) return
  lat = parseFloat(String(area.latitude || ""))
  lon = parseFloat(String(area.longitude || ""))
}
if (isNaN(lat) || isNaN(lon)) return
```

Without stored coordinates, `area` comes only from wttr's own
`nearest_area` — so open-meteo is reachable only *after* wttr has already
answered. If wttr is down, open-meteo is never even asked. wttr.in becomes a
hard single point of failure for any widget that hasn't had coordinates
pinned, and the widget self-heals only within `refreshMinutes` (default 15,
`Math.max(1, parseInt(setting("refreshMinutes", 15), 10) || 15)`) of wttr
recovering — which is fine for a blip, but during a longer outage the pill
just isn't there, for as long as the outage lasts.

**Suggested fix, one of several possible shapes:** don't let `visible` alias
fetch failure. Render a fallback/dimmed glyph when `label === ""`, the same
way `Model.iconForCode`'s `switch` already has a real fallback glyph on its
`default:` case for an *unknown* weather code — the widget is already more
forgiving of bad data than it is of absent data. The product also already
has user-facing error text on a different path: right-clicking the widget
runs
`omarchy-notification-send "$(omarchy-weather-status)"`, and
`omarchy-weather-status` prints `Weather unavailable` on a failed fetch. That
string could drive the visible state directly, so the pill degrades to
something clickable instead of disappearing. Happy to take a swing at a PR if
this shape looks right, but the underlying design choice is upstream's.

## Rice context (not for the issue)

Found via `~/backups/shokupan-lanes-2026-08-24/report-weather.md`: a shell
restart during a genuine wttr.in outage today made the weather pill
disappear, and it read as the widget having been deleted rather than a
service being down. No clone exists for this plugin and none is planned —
the fix belongs upstream, not in a fork. Pinning coordinates via
`omarchy-weather-location --set <name> <lat>,<lon>` would remove the
single-point-of-failure half of this for one machine, but the visibility
condition itself would still be wrong for everyone.

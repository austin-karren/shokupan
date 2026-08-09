---
status: accepted
---

# The bar remembers the weather

> **Largely native on quattro 2026-08-09, and ADR-0033 overstated the loss.**
> `omarchy.weather` is a first-party plugin and it is back on the bar in this
> ADR's position, right of the clock. It keeps a stale reading rather than
> blanking, which is this ADR's whole point. The residual gap is narrower than
> "rebuild as a plugin clone" implied — see the addendum.

The weather module reads a cached reading from disk and refreshes it in the background,
rather than fetching wttr.in on every poll. Implemented as
[`weather-icon`](../../.local/bin/weather-icon), replacing
`$OMARCHY_PATH/default/waybar/weather.sh` in the `custom/weather` module.

**A failed fetch now costs accuracy. Before, it cost the icon.**

## The icon did not go stale, it went away

Upstream's module prints `{"text":"","class":"unavailable"}` when its fetch fails, and
Waybar hides a custom module whose text is empty. So a network failure does not date the
reading — it removes the glyph, and it stays removed until some later poll happens to
succeed. That is the failure that prompted this: after a reboot the weather icon was
simply missing from the bar.

Two measured facts make that outcome likely rather than rare.

**Waybar starts before the network exists.** From this machine's boot log:

    12:50:31.0  systemd[1495]: Started waybar
    12:50:33.8  NetworkManager: manager: startup complete

The first poll fires roughly 2.7s before there is any route, so it cannot resolve
wttr.in at all. The bar's first act is guaranteed to be a failure.

**And the retry is fragile for an unrelated reason.** Upstream allows `--max-time 3`.
Measured warm, wttr.in's `j1` endpoint answers in 0.92–0.93s (DNS 0.001s, connect
0.19s) — comfortable. But wttr.in fetches from its own upstream on a cache miss, and a
cold response regularly exceeds three seconds. So the retry a minute later can fail for
a completely different reason than the first one did, and the recovery a human notices
is not one minute but several.

**The defect is not the timeout, it is that every poll is independent.** The module
knows nothing about the reading it drew sixty seconds ago, so it has no answer to a
transient failure other than to render nothing. Raising `--max-time` or shortening the
interval makes the hole rarer without making it impossible. Giving the bar a memory
makes it structurally unreachable: after the first successful fetch on a machine, there
is always something honest to draw.

## What is cached, and what is recomputed

The cache is a single JSON document at
`~/.local/state/omarchy/weather.json` — beside `wallpaper-pin` and
`hypr-logical-size`, which are state of the same kind. It holds the condition code, the
sunrise/sunset pair, and the place, temperature, wind speed and wind direction.

**Day or night is derived at render time, not stored.** The cache keeps sunrise and
sunset; which side of them we are on is computed on every poll. This is the one piece of
the reading that goes wrong *predictably* rather than randomly, and it costs nothing to
get right: with the network down, the glyph still turns from sun to moon at sunset, on
time, from a reading taken hours earlier. Storing the finished glyph instead would have
frozen it as a sun until the network came back.

That is also why the poll interval stays at **60s** while the fetch interval is **900s**.
The interval no longer paces network requests — it paces redrawing, which is what
sunset-following and staleness-marking need to be prompt. The two concerns were welded
together in the stock module and are now separate numbers.

## It also stops hammering a service that rate-limits

Not the motivation, but it fell out of the design and is worth recording, because
rate-limiting is one of the ways the old module failed.

| | stock | `weather-icon` |
|---|---|---|
| Requests per hour, idle | 60 | 4 |
| Requests per click | 3 | 0 |

The click figure is the interesting one. Upstream's `on-click` calls
`omarchy-weather-status`, which fetches wttr.in for the text *and* invokes
`omarchy-weather-icon`, which fetches it again — so a click on the bar was three
requests for information the bar had just drawn. One `j1` document contains all of it,
so the notification is now served from the cache and costs nothing.

## Failures are absorbed, then admitted

**One refresher at a time**, held by `flock` on `weather.lock`. Waybar polls every 60s,
and during an outage each poll would otherwise start its own retry ladder, stacking
overlapping curls against the rate-limiting service whose flakiness caused the outage.

**A refresh retries on a 2/5/10/20/40s ladder** rather than failing once and leaving the
next attempt to the following poll. This exists for the boot case specifically: it
closes the 2.7s gap above, so the first reading lands within a few seconds of the
network arriving instead of up to a minute later.

**A success signals the bar.** `RTMIN+12` (`signal: 12` in `config.jsonc`, the next free
number after Ratio's 11) pushes the new reading straight to the module, so a refresh
that finishes mid-interval is visible immediately.

**Past three hours, the glyph dims** to `opacity: 0.45` via a `stale` class, and
`--status` appends the reading's age. An old glyph beats a hole, but the bar should not
assert that an old reading is current. Opacity rather than colour: the glyph keeps its
meaning, it just stops insisting.

**A cache that will not parse is deleted, not worked around**, so the next poll refetches
instead of the bar being permanently wedged on one bad file. `unavailable` — and with it
the collapse-to-zero-width rule in `style.css` — is now only reachable before the first
successful fetch a machine ever makes.

## The glyph table is copied, and the copy is checked

`weather-icon` carries a byte-for-byte copy of `omarchy-weather-icon`'s condition-code to
glyph `case` block. This is duplication and it is deliberate: upstream's mapping is
welded to upstream's own fetch, so there is no way to ask it for the mapping alone
without paying for a second request and losing the day/night recomputation above.

The copy was made with `sed`, never retyped — these are Nerd Font glyphs where a
transcription error is invisible in review. It is spliced in unindented so that
`weather-icon --check-icons` can diff it against upstream as an exact comparison, and
`loaf doctor` runs that check on the Desktop layer. This is the drift ADR-0028 is about:
`omarchy update` can change the table underneath us, and the failure would otherwise be
silent.

It reports as a **warning, not a failure**, because the consequence is cosmetic — a
condition code we do not know renders as the fallback cloud, not as nothing.

## Verified behaviour

Network failure simulated with `unshare -rn`, which is a real empty network namespace
rather than a stubbed curl:

| Case | Result |
|---|---|
| Stock module, no network | `{"text":"","class":"unavailable"}` — module hidden |
| `weather-icon`, no network, cache present | cached glyph, class `current` — **the icon survives** |
| Glyph parity with upstream, same conditions | identical bytes (`ee8c8d`) |
| Stale cache, sunset already passed | night glyph (`ee8cab`), derived locally with no network |
| 8 simultaneous polls against a stale cache | exactly 1 fetch; cache updated once |
| Cache aged 3h | class `stale`; `--status` appends `1333min old` |
| Cache corrupted to non-JSON | deleted, `unavailable` for that poll, refetched next |
| No cache at all, `--status` | `Weather unavailable`, exit 1 — matches upstream |
| `RTMIN+12` delivered to waybar | pid unchanged — signal is handled, not fatal |
| `loaf doctor` | `✓ weather icons  glyph table matches upstream` |

The second row is the whole ADR. Everything else is what it cost to get there.

## Still open

- **Sunrise/sunset drift on a very old cache.** They are cached from the fetch day, so a
  cache several days old moves the sun/moon boundary by a few minutes per day. Harmless
  at the scale where the reading is dimmed as stale anyway, and fixing it properly means
  computing sunrise locally from latitude, which is a much larger dependency than the
  problem deserves.
- **`STALE_AFTER` is a guess.** Three hours is long enough that a normal suspend/resume
  never trips it and short enough that a genuinely dead network shows up before the
  reading is a day old. Not measured against anything, unlike the timeout.
- **Nothing watches for a permanently failing fetch.** The bar dims and that is all; no
  notification fires the way `waybar-watchdog` (ADR-0005) notifies on a crash loop.
  Deliberate for now — a weather service being down is not something the user can act
  on, and the dimmed glyph already says so.
- **Location is wttr.in's guess from the IP.** Unchanged from upstream, and wrong in the
  usual ways behind a VPN. Worth a pinned location if that starts to matter.

## Addendum: what quattro already does, 2026-08-09

ADR-0033 called this "the one real regression" of the quattro move and proposed
rebuilding `weather-icon` as a plugin clone. Reading the plugin rather than
assuming, that is too strong.

`plugins/panels/weather/Panel.qml` fetches wttr.in itself and comments its own
`report` property: *"Parsed wttr.in j1 response. Kept on failure so stale data
stays visible."* The bar glyph is `panelLoader.item.label`, derived from that
same property. So a failed refresh does **not** blank the bar — the module holds
the last reading, which is exactly the behaviour this ADR exists to guarantee.

What is genuinely missing is narrower: the reading is held **in memory, not on
disk**. The widget is `visible: label !== ""`, so between a shell restart and the
first successful fetch there is no weather at all. Under the old design the
Reading survived on disk, so a cold start showed the last known weather
immediately.

Two further notes, both measured:

- `plugins/panels/weather/status.sh` *does* have the blanking failure mode —
  it prints `{"text":"","class":"unavailable"}` when `omarchy-weather-icon`
  fails, and `omarchy-weather-icon` is a bare `curl --max-time 3 … || exit 1`
  with no cache. But nothing in the widget references `status.sh`; it looks
  vestigial. If a future version wires it back up, the regression returns in
  full.
- `loaf doctor` still warns that our `weather-icon` glyph table has drifted from
  `omarchy-weather-icon`. That check now guards a script the bar no longer calls.
  It is not wrong, just no longer load-bearing.

**Not done, deliberately.** Adding on-disk persistence means either patching a
package-owned QML file or cloning the plugin to own its popup and forecast too.
Neither is worth it for a gap that shows up only in the seconds after a shell
restart. `weather-icon` stays in `.local/bin` — it costs nothing and is the
thing to reach for if the gap ever matters.

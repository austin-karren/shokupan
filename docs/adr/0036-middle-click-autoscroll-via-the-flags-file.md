---
status: accepted
---

# Middle-click autoscroll, set where the browser reads it

Both browsers on this machine now do Windows-style middle-click autoscroll: press
the middle button for the round anchor, move the pointer to scroll continuously,
click to stop. The setting lives in each browser's flags file, both of which are
now tracked, and the default http handler moved from Chromium to Helium so that
the browser doing the scrolling is the one that actually opens.

## The .desktop file is the wrong place, and not only for web apps

The obvious way to pass a browser flag is to append it to the `Exec=` line of a
`.desktop` entry. On this machine that reaches nothing.

`omarchy-launch-webapp` never reads a `.desktop` file at all — it resolves a
browser with `xdg-settings get default-web-browser` and runs `browser --app=<url>`.
That much was known. The part that was not: `omarchy-launch-browser`, behind
`SUPER+SHIFT+RETURN` and `SUPER+SHIFT+B`, has the same shape, and *both* extract
the binary with

    sed -n 's/^Exec=\([^ ]*\).*/\1/p'

which keeps the first whitespace-delimited token and discards the rest of the
line. So a flag appended to `Exec=` is dropped on the main browser bind, on all
17 web apps, and on the 8 Hyprland web-app binds alike. There is no path on this
machine where editing a `.desktop` Exec line would have worked, which is worth
knowing before someone tries it and concludes the flag is broken.

The lever that does work sits one layer lower. Neither `/usr/bin/chromium` nor
`/usr/bin/helium-browser` is the browser; both are wrappers that read a flags
file and splice its contents into `argv` before exec:

| Wrapper | Reads |
|---|---|
| `/usr/bin/chromium` (C launcher) | `/etc/chromium-flags.conf`, `$XDG_CONFIG_HOME/chromium-flags.conf` |
| `/usr/bin/helium-browser` → `helium-wrapper` (bash) | `/etc/helium-browser-flags.conf`, `$XDG_CONFIG_HOME/helium-browser-flags.conf` |

Because that happens inside the binary the launchers invoke, it is indifferent to
*how* the browser was started. Hyprland bind, web app, launcher entry, command
line — all of them go through the wrapper, so all of them get the flag. This is
the general answer to the `.desktop` truncation, not a workaround for it.

## The two browsers need different switches

They are the same Chromium version — 151.0.7922.108 — and they still do not take
the same flag.

Helium ships a first-class one, visible in the binary as a `chrome://flags`
entry: *"Middle Click Autoscroll — Enables autoscroll on middle click. Helium
flag, Chromium feature."* It is a `base::Feature` named
`HeliumMiddleClickAutoscroll`. Stock Chromium has no such entry; the capability
is there, but only as the Blink runtime feature `MiddleClickAutoscroll`, reachable
solely through `--enable-blink-features`. So:

    helium-browser-flags.conf   --enable-features=HeliumMiddleClickAutoscroll
    chromium-flags.conf         --enable-blink-features=MiddleClickAutoscroll

That these are two *different switches* is load-bearing. `chromium-flags.conf`
already carried `--enable-features=TouchpadOverscrollHistoryNavigation`, and
Chromium resolves a repeated switch to its last occurrence rather than merging —
had autoscroll needed `--enable-features` on Chromium too, adding a second line
would have silently disabled touchpad back/forward navigation. It does not, so
the two coexist. A future flag that *does* share a switch name must be folded
into the existing line.

`chrome://flags` was rejected as the mechanism even though Helium offers the
toggle there. It persists into `Local State`, a volatile profile blob that cannot
be stowed — the same problem that forced Helium's theme colours into a migration
rather than a tracked file. A flags file is plain text, diffable, and reverts by
deleting one line.

## Measured, not assumed

Every claim above was checked by driving each browser over the DevTools protocol
against a 20000px page, dispatching a middle-button press followed by pointer
movement, and reading `window.scrollY`:

| Run | scrollY |
|---|---|
| Helium, no flag (control) | 0 → 0 |
| Helium, `--enable-features=HeliumMiddleClickAutoscroll` | 0 → 7273 |
| Chromium, `--enable-blink-features=MiddleClickAutoscroll` | 0 → 7240 |
| Helium via `helium-browser`, flag only from the tracked file | 0 → 7251 |
| Chromium via `/usr/bin/chromium`, flag only from the tracked file | 0 → 7159 |

The last two are the ones that matter: no flag on the command line, the wrapper
picking it up from the stowed file. That is the whole mechanism proven end to end.

The other two Windows behaviours survive, which was not obvious — autoscroll
could plausibly have eaten them. Middle-clicking a *link* still opens it in a new
tab (page targets 1 → 2), because the anchor only arms on background; and a
left-click stops a scroll in progress (4838, then 4838 unchanged). So this adds a
gesture rather than replacing the one already in use.

## The default browser was pointing at the wrong browser

Measuring turned up a mismatch nobody had noticed. `mimeapps.list` registered
`chromium.desktop` for `http`, `https`, `text/html`, `about` and `unknown`, while
the browser actually running on this machine — and the only one with a signed-in
profile — is Helium. Since both `omarchy-launch-browser` and
`omarchy-launch-webapp` resolve through `xdg-settings`, every web app, every
browser bind and every link handed over by another application was opening
Chromium, not the browser in use.

Those five associations now point at `helium.desktop`. `omarchy-launch-webapp`
already has a `helium*` case in its browser whitelist, so web apps follow without
further change. This is a larger behavioural change than a scroll preference and
was made deliberately rather than as a side effect: configuring both browsers
would have made autoscroll work either way, but leaving the mismatch in place
would have meant `SUPER+SHIFT+RETURN` opening a browser with none of the user's
sessions in it.

Chromium keeps its flag regardless. It is still installed and still reachable.

## Tracking is the protection, not a new check

The request behind this was partly "make `loaf` stop Omarchy updates from taking
my preferences away." `loaf` already does that, and needed no new code: `loaf heal`
walks `git ls-files`, and any tracked path that has become a real file — because
an Omarchy migration replaced our symlink with a fresh default — is moved aside as
`.displaced.<epoch>` and re-linked. The protection is a property of being tracked.

So `chromium-flags.conf` and `helium-browser-flags.conf` were brought into the
repo rather than edited in place, and `mimeapps.list` was already tracked. Nothing
under `/usr/share/omarchy` writes or rewrites either flags file — checked, not
assumed — so adopting Omarchy's four existing Chromium flags verbatim costs
nothing and there is no upstream version to drift from. The displaced original is
kept next to the symlink in the usual way.

A one-shot migration was considered and rejected on those grounds. Migrations
exist for state that has nowhere else to live (ADR-0028); a flags file is
ordinary config, and a migration would have run once and then stopped defending
the setting, which is the opposite of what was asked for.

## Firefox: nothing to do, and nothing written

The ask included a `loaf` script covering Firefox-family browsers. There are none
on this machine — no `firefox`, `librewolf`, `zen`, `floorp`, `waterfox` or
`mullvad-browser` as package or Flatpak, and exactly two `.desktop` files claim
`x-scheme-handler/http`: Helium and Chromium. Writing that script now would mean
writing it blind against a browser that could not be tested, so it was not
written.

The shape it would take, for whenever one arrives: Gecko has no flags-file
equivalent, so the wrapper trick above does not transfer. The lever is the
`general.autoScroll` preference, set from a `user.js` stowed into the profile
directory — profile-scoped rather than binary-scoped, which means it needs the
profile to exist first and is therefore closer to the Helium theming migration
than to this decision. **Unverified**, including whether the pref is already on by
default on Linux.

## Consequences

- **Middle-click paste is expected to stop working in these browsers**, and this
  is the real cost. Under Wayland the middle button pastes the primary selection;
  once autoscroll claims that button, the press arms the anchor instead. This
  could **not** be tested here — synthetic DevTools input does not travel the
  native Wayland input path, so the paste path cannot be exercised that way. It
  is reasoning, not a measurement. If middle-click paste matters more than
  autoscroll, delete the one line from the relevant flags file.
- **A restart is required.** Flags files are read once, at process launch. Helium
  is running now and will not pick this up until it is quit and reopened; the
  running instance was deliberately left alone.
- Both flags are unsupported-by-policy in the sense that they are opt-in feature
  switches. Chromium's is a Blink runtime feature with no UI, which means it can
  be removed in a future version without a deprecation path. Helium's is a
  shipped `chrome://flags` entry and is safer, but is also the reason the two
  files differ and cannot be unified.
- Anything else reading `xdg-settings get default-web-browser` now gets Helium.
  That is the intent, but it is a wider blast radius than the browser binds —
  OAuth hand-offs from Online Accounts and any application opening a URL are
  included.

*Addendum 2026-08-15: the menu path now exists too.* The default set here via
`mimeapps.list` was fine, but Setup > Default Browser could not express it:
`omarchy-default-browser` hardcodes seven browsers with no helium case, and a
PATH shim cannot override it (Omarchy's bin outranks `~/.local/bin`). Two
things record the fix: a `setup.default.browser.helium` row in
`.config/omarchy/extensions/omarchy-menu.jsonc` that inlines the upstream
script's two effects — the `env -u BROWSER xdg-settings set` and the
notification — against `helium.desktop`, and a draft upstream issue at
`docs/upstream/omarchy-default-browser-helium.md` (issue-first, ADR-0044 rule
5, not posted) proposing helium in the script's own list. If upstream takes
it, the menu row becomes a duplicate id silently overriding their row
(mechanism 1 in the jsonc) and should then be deleted.

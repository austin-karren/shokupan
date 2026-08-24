# Draft issue: the notification service discards `desktop-entry`, so senders that send no `app_name` get a blank name (and sometimes no icon)

**Status: draft — not posted.** Per shokupan-plugins ADR-0044 rule 5: issue
first, PR only after upstream's temperature is known, nothing posted without an
explicit go.

## Title

Notifications: fall back to the `desktop-entry` hint when `app_name` is empty

## Body (draft)

`shell/plugins/notifications/NotificationLogic.js`, in `snapshotOf()`, stores an
entry's identity as:

```js
    app: n.appName || "",
    appIcon: n.appIcon || "",
```

`n.desktopEntry` is never read — `grep -rn desktopEntry shell/` returns only
audio/media hits — and the persisted history JSON has no field for it. So for any
sender that leaves `app_name` empty on the wire, the app-name slot is blank and
there is nothing downstream that can recover it: by the time a popup card or a
history row is drawn, the one piece of identity the sender did supply is gone.

Two whole classes of sender leave `app_name` empty, and neither is something a
user can configure their way out of:

**1. GLib's freedesktop notification backend.** Ghostty is the visible case,
because agent and shell tooling routes notifications through the terminal (OSC 9
/ OSC 777). Captured on this machine with `dbus-monitor --session`, sender
resolved to `pid = ghostty`, destination to Omarchy's own quickshell server:

```
method call sender=:1.5964 -> destination=org.freedesktop.Notifications member=Notify
   string ""                                     ← app_name
   uint32 0
   string ""                                     ← app_icon
   string "Ghostty"                              ← summary
   string "probe7 osc9 body only NOTIFNAME TEST 7"
   array [ string "default"  string "" ]
   array [
      dict entry( string "desktop-entry"  variant string "com.mitchellh.ghostty" )
      dict entry( string "urgency"        variant byte 1 )
      dict entry( string "image-path"     variant string "com.mitchellh.ghostty" )
   ]
   int32 -1
```

`app_name` is empty; `desktop-entry` is exactly right.
`/usr/share/applications/com.mitchellh.ghostty.desktop` passes
`desktop-file-validate` and contains `Name=Ghostty`, so the hint resolves
straight to the name a user expects to read.

**2. Anything sandboxed, via the notification portal.** `xdg-desktop-portal-gtk`
relays a portal notification to `org.freedesktop.Notifications.Notify` with the
app name **hardcoded empty** and the caller's portal app id in the hint
(`src/fdonotification.c`):

```c
g_variant_new ("(susssasa{sv}i)",
               "", /* app name */
               fdo->notify_id,
               icon_name,
               ...
g_variant_builder_add (&hints_builder, "{sv}", "desktop-entry",
                       g_variant_new_string (fdo->app_id));
```

Captured on this machine as the same shape — `app_name = ""`,
`desktop-entry = <app id>`, no actions:

```
method call sender=:1.40 -> destination=org.freedesktop.Notifications member=Notify
   string ""                                     ← app_name, hardcoded by the portal
   uint32 0
   string ""                                     ← app_icon
   string "NOTIFENTRY TEST 1"
   string "probe1 portal AddNotification unsandboxed"
   array [ ]
   array [
      dict entry( string "desktop-entry"  variant string "" )
      dict entry( string "urgency"        variant byte 1 )
   ]
   int32 -1
```

(`desktop-entry` is empty in that capture only because the probe was an
unsandboxed caller, which the portal has no app id for. A confined sender does
supply one — see the snap note below.)

### What the user sees

Blank app-name slots, on notifications that are otherwise fine. On this machine
every Ghostty record in `~/.local/state/omarchy/notifications/history/` carries
`"app":""`, and a real Slack notification (a snap, so it comes through the
portal) is stored as:

```json
{"id":245,"app":"","appIcon":"","summary":"New message from …","body":"…"}
```

while every non-empty-`app_name` sender on the same machine — `notify-send`,
Helium — renders correctly. So the service is faithful; it is just throwing away
the only recoverable identity these senders have.

Three consequences, not one:

- **The name is blank.** Cosmetic, and the obvious one.
- **The icon can be missing too.** Quickshell already falls back to
  `desktop-entry` for `appIcon` — `notification.cpp`:
  `if (appIcon.isEmpty() && !bDesktopEntry.isEmpty())` then
  `DesktopEntryManager::byId(...)`. That is an exact-id match, so it covers
  Ghostty but not every id shape (see below), and where it misses there is no
  second chance: the popup card and the history row both resolve their icon from
  `appIcon`, never from the name.
- **Click-to-focus becomes a silent no-op.** `Service.qml`'s `focusApp()` opens
  with `if (!entry || !entry.app) return`, and it exists precisely because "chat
  apps (Slack, Discord, Vesktop, etc.) rarely register a `default` libnotify
  action". Those are the same apps that come through the portal with an empty
  `app_name` — so the fallback that makes click-to-jump work is disabled for
  exactly the senders it was written for. (Adjacent to #7369, which is about
  `app_name` not matching the window class; this is `app_name` not being there at
  all.)

### Proposed fix

Read the hint when, and only when, the field it would fill is empty — so no
sender that works today changes behaviour:

```js
    app: n.appName || nameFromDesktopEntry(n) || "",
    appIcon: n.appIcon || iconFromDesktopEntry(n) || "",
```

where both helpers resolve `n.desktopEntry` through `DesktopEntries` and read
`Name=` / `Icon=`, and the name helper falls back to the raw hint value if
nothing resolves — `com.mitchellh.ghostty` is ugly, but it still names the app,
and the alternative is the blank slot.

### One id shape worth handling explicitly

`xdg-desktop-portal` identifies a snap as `snap.<instance>`
(`src/xdp-app-info-snap.c`: `g_strconcat ("snap.", snap_name, NULL)`), while
snapd names the desktop file `<instance>_<app>.desktop`. The id the portal sends
therefore never matches the file it means — and the portal has the right
filename in hand while sending the wrong one. `snap routine portal-info`, the
call the portal itself makes to identify a confined sender, for the running
Slack on this machine:

```
$ snap routine portal-info 1288126
[Snap Info]
InstanceName=slack
AppName=slack
DesktopFile=slack_slack.desktop
```

The portal keeps `DesktopFile` as a separate property and builds its app id from
`InstanceName`, so the hint that goes out is `snap.slack` — not
`slack_slack`. What that resolves to is then measurable; Quickshell 0.3.0 on
this machine:

```
DesktopEntries.byId("com.mitchellh.ghostty")  -> Ghostty | com.mitchellh.ghostty
DesktopEntries.byId("snap.slack")             -> null
DesktopEntries.heuristicLookup("snap.slack")  -> null
DesktopEntries.byId("slack")                  -> null
DesktopEntries.heuristicLookup("slack")       -> Slack   | /var/lib/snapd/snap/slack/current/usr/share/pixmaps/slack.png
```

That is the whole reason Slack arrives with **no icon at all** rather than just
no name: Quickshell's own `byId()` fallback cannot match `snap.slack`. Stripping
a leading `snap.` and trying `heuristicLookup()` resolves both the name and the
icon. Whether Omarchy wants that special case or would rather see it fixed in
Quickshell (or in `xdg-desktop-portal`, which arguably should identify a snap by
the desktop file it knows about — it stores one) is upstream's call; the plain
`desktop-entry` fallback above is useful either way and fixes Ghostty on its own.

### Not asking Omarchy to fix these

For completeness, because they are the other two thirds of the problem and both
are outside this repo: GLib sends an empty `app_name` at all, and the portal
hardcodes `""`. Either being fixed would make part of this fallback dead code.
The case for doing it in Omarchy anyway is that the fallback is three lines and
fixes every such sender at once, including ones that will never be fixed.

## Rice context (not for the issue)

Diagnosed across two lanes on 2026-08-24. The first (`notifname`) established
that Ghostty is what sends `app_name = ""` and recommended a one-line herdr
config change (`[ui.toast] delivery = "system"`) as the cheap fix for Austin's
own case; that remains the cheaper fix for Ghostty specifically and does nothing
for Slack.

This lane carries the service-level fix as `austinkarren.notifications`, an
`omarchy plugin clone` of the notification service in shokupan-plugins, recorded
in `packages/forks` as three fork lines. **It is a fork of a 1,062-line service
for a three-line change, which is a bad trade and is not meant to last** — the
plugin's README says so and tells the reader to drop it if upstream takes the
fallback. If upstream does, delete the clone, its three fork lines, its
`packages/plugins` line and its two test suites.

Two premises from the lane brief were wrong and are corrected above, because
they change what the issue should say: the icon is **not** discarded by Omarchy
(Quickshell recovers it, and only misses on snap ids), and fixing the name
therefore does **not** fix the icon on its own — the snap-prefix strip is what
does.

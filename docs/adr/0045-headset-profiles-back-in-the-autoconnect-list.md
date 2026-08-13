---
status: accepted
---

# Headset profiles go back into the auto-connect list

Google Meet with the Sony WF-1000XM6 was unusable: the moment the page opened
the microphone, the buds started flipping between A2DP and the headset profile
in a loop — a connect chime every cycle, no mic, no output, escalating until
the audio stack hard-failed for the page. The journal signature (2026-08-13)
is repeated `s-device: Could not find valid non-headset profile, not
switching` from wireplumber, interleaved with Bluetooth transport failures.

## Where the loop comes from

Omarchy ships `~/.config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf`
(a real file, also at `/usr/share/omarchy/config/wireplumber/...`), which sets
on **every** bluez card:

```
bluez5.auto-connect = [ a2dp_sink a2dp_source ]
```

Its comment says why: speakers and receivers should expose their audio
profiles without manual PipeWire recovery. Worth knowing what it actually
turns on: `bluez5.auto-connect` **defaults to `[]`** — the mechanism is off
in a stock WirePlumber — and upstream's example enables it with the headset
profiles included (`hfp_hf hsp_hs a2dp_sink …`). Omarchy enabled it with
them excluded.
([Device properties docs](https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html);
`DEFAULT_RECONNECT_PROFILES SPA_BT_PROFILE_NULL`, pipewire
`spa/plugins/bluez5/bluez5-dbus.c:262`; example list in
`src/config/wireplumber.conf.d.examples/bluetooth.conf`.)

What the property drives (pipewire 1.6.8 source): a repeating **2-second
timer** (`reconnect_device_profiles()`, `bluez5-dbus.c:2168`) that, while
the device is connected with only some of the listed profiles up, issues
BlueZ `ConnectProfile()` calls for the missing ones. It is a BlueZ-level
connection knob, not a profile-availability filter (that is `bluez5.roles`).

The counterpart is `bluetooth.autoswitch-to-headset-profile` (default true,
and load-bearing here: calls are the primary use of these buds). Its script,
`/usr/share/wireplumber/scripts/device/autoswitch-bluetooth-profile.lua`,
switches the card to the highest-priority profile with an **Input route**
when a real capture stream links, and restores a non-headset profile when
capture stops. With the headset profiles absent from the auto-connect list,
the two policies fight: the earbuds drop A2DP to run HFP's SCO link, the 2s
timer forces A2DP back behind the autoswitch's back, every profile flip
re-fires the script's evaluate hook, and mid-collapse the restore path finds
no enumerable A2DP route — that is the `Could not find valid non-headset
profile` line (`autoswitch-bluetooth-profile.lua:244`). A chime per BlueZ
reconnect.

Upstream's autoswitch had its own infinite-loop bugs
([wireplumber#617](https://gitlab.freedesktop.org/pipewire/wireplumber/-/issues/617),
fixed in 0.5.4, with more robustness work through 0.5.14) — all already
fixed in the 0.5.15 running here, which leaves the drop-in as the variable,
and the source-level mechanism above as the cause.

Disabling autoswitch would "fix" the loop by amputating the mic. Not an
option.

## The fix

A second drop-in in the same directory, tracked in the rice:

`.config/wireplumber/wireplumber.conf.d/zz-shokupan-bluetooth-headset.conf`

```
bluez5.auto-connect = [ hfp_hf hsp_hs a2dp_sink a2dp_source ]
```

on the same `~bluez_card.*` match. This is upstream's example list, so
Omarchy's speaker/receiver intent survives (`a2dp_source` stays) — the
deviation is only that headsets get their headset profiles back. The broad
match is safe: the reconnect mask is ANDed with the profiles the device
actually has (`bluez5-dbus.c:2172`), so listed-but-unsupported profiles are
no-ops, which is also why upstream's own example doesn't bother scoping.

## Why a `zz-` fragment beats the Omarchy file — measured, not assumed

Fragment merging was verified with `pw-config` (same libpipewire config
loader WirePlumber 0.5 uses) against a fixture holding both files:

- `wireplumber.conf.d` fragments load in **filename order**, so
  `zz-shokupan-…` loads after `bluetooth-a2dp-autoconnect.conf`.
- Duplicate array sections **append**: the merged `monitor.bluez.rules`
  contains both rules, Omarchy's first, ours second.
- Matching rules apply in order and later `update-props` values replace
  earlier ones for the same key, so every bluez card ends up with the
  four-profile list.

What is *not* yet measured: the fix on the buds themselves — they were not
connected when this was written, so the merge mechanics are verified but the
live profile-switch behaviour awaits a real Meet call (procedure in the
branch summary). If that test fails, this ADR gets an addendum, not a silent
edit.

Omarchy's file is not modified. Stow delivers the override cleanly:
`~/.config/wireplumber/wireplumber.conf.d/` is a real directory containing
Omarchy's real file, and `loaf heal` stows with `--no-folding`, so the new
file lands as a single symlink beside it.

## Alternatives considered

- **Scope the rule away from mic-bearing devices.** Rules cannot match on
  profiles (they run at object creation, before profile enumeration); the
  workable proxy is `device.form-factor` (`headset`, `hands-free`, …, from
  the BlueZ device class). Possible, but pointless given unsupported
  profiles are no-ops — and narrowing Omarchy's rule would mean editing
  Omarchy's file. Rejected.
- **Disable `bluetooth.autoswitch-to-headset-profile`.** Kills the loop and
  the mic with it. Rejected outright.
- **Delete Omarchy's rule via a fragment.** Impossible: arrays append on
  merge; a vendor rule can only be out-voted by a later one, never removed.

## Looking further out: LE Audio

The WF-1000XM6 supports LE Audio, which would eventually make this profile
dance obsolete — BAP with LC3 is one bidirectional stream at up to 32/48 kHz
both directions (versus HFP's 16 kHz mSBC), so call audio stops being the
degraded mode. PipeWire 1.6.8 supports all BAP roles and WirePlumber 0.5's
default `bluez5.roles` already includes `bap_sink bap_source`. What it would
take on this machine: kernel 6.4+ for ISO sockets (running 7.1.6 — fine),
BlueZ with `Experimental = true` plus the ISO-socket `KernelExperimental`
UUID in `/etc/bluetooth/main.conf`, an adapter whose firmware does ISO
channels (needs checking), and LE Audio toggled on in Sony's Headphones
Connect app — which on some models is exclusive with classic BT. A follow-up
experiment, deliberately not part of this fix.
([LE Audio in PipeWire](https://www.bluez.org/le-audio-support-in-pipewire/),
[Collabora, 2025-11](https://www.collabora.com/news-and-blog/blog/2025/11/24/implementing-bluetooth-le-audio-and-auracast-on-linux-systems/).)

## Addendum, 2026-08-13 — the fix above was insufficient; A2DP had to go

The live dry-run (buds connected, mic held open by Helium) failed: the new
four-profile list loaded correctly, and the loop continued unchanged. The
measured shape, across ~15 cycles: the card *holds* the headset profile now
(the original chime-flip is gone), but the HFP transport is killed every
~23–33s — the card object itself destroyed and recreated each cycle, audio
ping-ponging between the buds and the fallback devices, and the buds' DSP
resetting audibly (per-ear ANC stutter, uncomfortable enough to force casing
them mid-incident).

The corrected root cause: the WF-1000XM6 firmware cannot sustain an *active*
A2DP stream concurrently with an active SCO/eSCO mic link. Every cycle, the
auto-connect timer re-ConnectProfile()s `a2dp_sink` ~2s after HFP recovers,
Sony auto-starts the AVDTP stream on connect, PipeWire acquires it — and
21±1s later (20.6–22.4s across every observed cycle: a firmware timeout, not
radio flakiness) the buds kill the HFP link. Adding `hfp_hf` to the list
changed nothing because `a2dp_sink` stayed on it, and A2DP was the side doing
the killing.

So the decision inverts: on mic-bearing devices (headset icon/form-factor)
the auto-connect list now holds **only** `[ hfp_hf hsp_hs ]` — nothing forces
A2DP back during a call. Mic-less speakers keep Omarchy's A2DP nudge. The
original section's rejection of form-factor scoping is hereby wrong: the
scoping is load-bearing, just inverted — the win was never adding HFP, it was
removing A2DP.

Open questions carried forward: (1) BlueZ's own policy plugin
(`policy.c:reconnect_timeout`, `ReconnectUUIDs` in /etc/bluetooth/main.conf)
is a second, independent A2DP reconnector observed in the logs — next suspect
if the loop survives this revision. (2) Classic HFP negotiated **LC3-SWB**
here (not mSBC/CVSD); whether SWB coexistence contributes is unresolved — a
codec-exclusion test (`bluez5.codecs` without `lc3_swb`) was defeated by the
loop itself (card recreation resets the profile within one cycle) and needs a
quiet system to run.

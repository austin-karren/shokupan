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
take on this machine: kernel 6.4+ for ISO sockets, BlueZ with
`Experimental = true` plus the ISO-socket `KernelExperimental` UUID in
`/etc/bluetooth/main.conf`, an adapter whose firmware does ISO channels
(needs checking), and LE Audio toggled on in Sony's Headphones Connect app —
which on some models is exclusive with classic BT. A follow-up experiment,
deliberately not part of this fix.

*Corrected 2026-08-21:* the kernel clause originally read "(running 7.1.6 —
fine)". 7.1.6 was the installed **`linux-cachyos`** package version when this
was written (installed 2026-08-03, upgraded to 7.1.8-1 on 2026-08-14) — but
this machine boots the **LTS** series, and the running kernel is
`6.18.42-1-cachyos-lts`. Whether 7.1.6 was ever actually booted is no longer
recoverable: the journal retains one boot, from 2026-08-18. "Fine" survives
either way — 6.18 clears the 6.4 floor by a wide margin — but **7.1.x is not a
precondition**, and no reader should infer that LE Audio here waits on the
mainline series.
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

## Addendum 2, 2026-08-13 — the adapter did it: LC3-SWB on the MT7925

The form-factor revision above also failed Austin's live test (Meet detected
the devices, but the voice link carried nothing either way), which forced the
codec experiment the first addendum deferred. A simulated mic grab
(`pw-record` against the buds' HFP source triggers the autoswitch in <2s — a
faithful WebRTC stand-in) made the failure reproducible without calls, and
the A/B matrix was unambiguous:

- **LC3-SWB (default):** SCO established, carried 95% digital silence, died
  at the ~21s timeout — with **no A2DP reconnect in play at all**.
- **mSBC (lc3_swb excluded):** link held 110s+ with continuous audio, zero
  transport failures — and survived a *forced* `ConnectProfile(A2DP Sink)`,
  the exact operation the first addendum blamed.

Root cause: the Framework Desktop's MediaTek MT7925 (USB 0e8d:0717) cannot
run LC3-SWB's transparent eSCO — kernel: `HCI Enhanced Setup Synchronous
Connection command is advertised, but not supported`. PipeWire's quirk table
already disables LC3-A127 on this adapter family (pipewire#5213) but not
standard `lc3_swb`, which the WF-1000XM6 happily negotiates.

Corrections owed by this ADR: (1) the original chime-flip loop and the first
addendum's "A2DP acquire arms a 21s firmware kill" story were both artifacts
of the same underlying SCO death — A2DP re-acquire and SCO re-establishment
happen ~2s apart every cycle, so the correlation was real and the causation
was not. (2) Omarchy's auto-connect fragment is thereby **exonerated** as the
root cause; the planned upstream report against it is withdrawn. The
worthwhile upstream report is against **PipeWire**: `bluez-hardware.conf`
should add `lc3-swb` to the MT7925 no-features entry alongside `lc3-a127`.

Final shape of the fix (the tracked drop-in): `bluez5.codecs` whitelist
omitting `lc3_swb` (calls run 16 kHz mSBC instead of 32 kHz SWB — the right
trade until MT7925 firmware fixes eSCO or LE Audio makes it moot), plus the
four-profile auto-connect list restored (the form-factor revision is
reverted; it only cost the fast first A2DP attach). Whitelist caveat: absent
property = all codecs; present = only those listed — future codecs must be
added by hand.

Proven by the combined test: 70s grab clean and continuous, autoswitch back
to A2DP (AAC) within 15s of mic release. Sign-off is a real Meet call.

## Amendment, 2026-08-21 — two of Addendum 2's supporting facts were wrong

Addendum 2's decision stands unchanged: the MT7925 cannot run LC3-SWB's
transparent eSCO, and excluding `lc3_swb` from the `bluez5.codecs` whitelist is
what makes calls work. That was proven by the A/B capture tests and nothing
below touches it. Two *supporting* facts in that section were wrong, and both
were load-bearing for how a future reader would act on it, so they are
corrected here rather than edited away.

**1. PipeWire's quirk table does not cover this adapter.** Addendum 2 says the
table "already disables LC3-A127 on this adapter family (pipewire#5213) but not
standard `lc3_swb`", and used that as evidence that upstream already knew about
this silicon. It does not say that. The entry, verbatim from
`/usr/share/spa-0.2/bluez5/bluez-hardware.conf` (pipewire 1.6.8):

```
# Mediatek MT7925, #pipewire-5213
{ bus-type = "usb", vendor-id = "usb:0e8d", product-id = "~(e025)", no-features = [ lc3-a127 ] },
```

The vendor matches; the product-id regex is `e025` and **this adapter is
`0e8d:0717`**. It does not match. Nor is this ambiguous about which ID the
matcher sees: `libspa-bluez5.so`'s `adapter_init_modalias` reads
`/sys/class/bluetooth/%s/device/modalias`, the underlying USB device's sysfs
modalias, which here is

```
usb:v0E8Dp0717d0100dcEFdsc02dp01icE0isc01ip01in00
```

— the real `0E8D:0717`, not BlueZ's D-Bus `Adapter1.Modalias`, which reports the
Linux Foundation virtual ID `usb:v1D6Bp0246d0557`. The table's own rule is
"first match wins", so the next rule that applies to this adapter is the generic
`{ bus-type = "usb", no-features = [ msbc-alt1-rtl ] }`. **LC3-A127 is enabled
here**, not disabled, and pipewire#5213 is not upstream knowledge of `0717`.

What this changes: nothing about the fix, because the fix never relied on the
quirk table — the `bluez5.codecs` whitelist is what excludes SWB, and it is
local, explicit and adapter-independent. What it does change is the shape of the
upstream report, below.

**2. The planned upstream report is not expressible as written.** Addendum 2
says "the worthwhile upstream report is against **PipeWire**:
`bluez-hardware.conf` should add `lc3-swb` to the MT7925 no-features entry
alongside `lc3-a127`." That cannot be filed as a table row, because **there is
no `lc3-swb` feature tag**. `bluez-hardware.conf` in 1.6.8 documents its tags
exhaustively:

```
#     msbc, msbc-alt1, msbc-alt1-rtl, hw-volume, hw-volume-mic,
#     sbc-xq, faststream, a2dp-duplex, lc3-a127
```

and the quirk-driven property set compiled into `libspa-bluez5.so` is exactly as
narrow — `bluez5.enable-sbc-xq`, `enable-msbc`, `enable-hw-volume`,
`enable-faststream`, `enable-a2dp-duplex`, `enable-lc3-a127`. There is no
`bluez5.enable-lc3-swb`. `lc3_swb` exists only as a *codec* name, in
`libspa-codec-bluez5-hfp-lc3-swb.so`; `lc3-a127` is a *feature*. They live in
different namespaces and the quirk table can only reach the second.

So the actual mechanism, in the order it would have to happen upstream:

1. A code change in `spa/plugins/bluez5/` adding an `lc3-swb` feature tag and
   its `bluez5.enable-lc3-swb` property, wired to the HFP codec-selection path
   the same way `lc3-a127` already is.
2. Only then a `bluez-hardware.conf` row can carry it.
3. Separately, and independently useful: the existing MT7925 `lc3-a127` row's
   `~(e025)` product-id does not cover `0717`, so that row wants widening
   regardless of anything SWB-related.

Until (1) lands there is no quirk-table fix available to anyone with this
adapter, which raises the value of the local whitelist rather than lowering it.
Nothing has been filed — upstream reports need Austin's explicit per-item go
(`shokupan-plugins` ADR-0044 rule 5).

## Amendment, 2026-08-21 — LE Audio is not the way out; StreamCam mic, buds output

"Looking further out: LE Audio" above treats BAP/LC3 as the eventual escape from
the profile dance — one bidirectional stream, call audio stops being the
degraded mode. The question was investigated properly on 2026-08-21: **can the
WF-1000XM6 do microphone and full-quality output at the same time on this
machine?** The answer is **no on this hardware**, and it is recorded here so it
is not re-investigated.

**Bluetooth Classic cannot do it, and that is not a Linux limitation.** A2DP is
output-only; HFP/HSP is mono and narrowband. There is no classic profile that
carries a mic and stereo music at once. Every workaround on this machine is a
choice between them, which is what all of this ADR has been about.

**LE Audio would solve it in principle, and every layer here is ready except
the adapter.** Kernel: `bluetooth.ko` exports `iso_init` / `iso_inited` /
`iso_sock_*` in **both** `6.18.42-1-cachyos-lts` and the pending `7.1.8-1-cachyos`
— the `CONFIG_BT_LE_AUDIO` symbol is simply gone, ISO builds unconditionally
under `CONFIG_BT_LE=y`. BlueZ 5.87 is built with the full BAP/BASS/CCP profile
set. PipeWire 1.6.8 ships all four `MediaEndpointLE` roles and an LC3 codec
plugin with a `bluez5.bap.duplex` knob — the stack answers "yes" to the exact
question. (A live `BTPROTO_ISO` socket probe returns `EPROTONOSUPPORT` today;
that is BlueZ's ISO-socket experimental feature being off, **not** evidence the
kernel lacks ISO. It is a trap worth not falling into twice.)

**The adapter is the blocker, in the same way it already is for eSCO.**
`btmgmt info` reports `cis-central cis-peripheral iso-broadcaster sync-receiver`
in *current* settings — the MT7925 claims full ISO support. That claim is
precisely the kind this ADR already proved false once: this is the adapter that
advertises `HCI Enhanced Setup Synchronous Connection` and cannot execute it. An
open upstream report on the same silicon — MT7925, CachyOS kernel, BlueZ —
carries both failures side by side: `Opcode 0x2062 failed: -95` (that is
OGF 0x08 / OCF 0x062 = **HCI LE Set CIG Parameters**, `EOPNOTSUPP`, so no
isochronous group can be created and therefore no LE Audio at all), *and* this
machine's exact eSCO line. See
`https://lists.infradead.org/pipermail/linux-mediatek/2025-October/099857.html`.
One adapter, two advertised-but-absent audio transports, is a pattern rather
than a coincidence.

**The pending 7.1.8 reboot does not change this on best evidence — with a real
caveat.** `btmtk.ko`'s ISO string set is identical across 6.18.42 and 7.1.8. But
the MT7927 upstream-tracking issue reports an unspecified "ISO fix" landing in
7.1.1, with no commit cited, and a logic-only fix would not show up in a string
diff. So: probably unchanged, not certainly. If anyone ever wants the measurement,
the reboot onto 7.1.8 is the cheapest moment to take it.

**And the entry cost is the decisive input, independent of all of the above.**
Sony requires **deleting the pairing and re-pairing** to enter LE Audio mode,
and again to leave it. Testing therefore risks the primary call device in both
directions, for a gain that the adapter evidence says probably will not
materialise. Note also that even if all of that went well, the `bluez5.codecs`
whitelist in the tracked drop-in would silently block BAP — see the warning now
carried in that file.

**The decision, settled: StreamCam for the microphone, the buds for stereo
output.** Austin explicitly rejected the alternative of pinning the buds to A2DP
and giving up their mic entirely — calls are what the buds are for, and work is
what the machine is for. Splitting the two devices costs nothing and keeps both
at their best.

Revisit only if one of these changes: MT7925 firmware or `btmtk` ships a *named*
CIG fix; BlueZ drops the `Experimental` requirement for BAP; or the adapter is
replaced.

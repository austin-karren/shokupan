# Known issues

Problems on this machine that are understood well enough to clean up after
but not yet fixed at the cause. Each entry says what is known, what has been
ruled out, and the cleanup. Move an entry into an ADR once its cause is found
and a decision is made.

## PipeWire leaks duplicate HDMI sinks for the BenQ

**Seen since:** 2026-09-04. **Cause:** unknown.

WirePlumber 0.5.16 / PipeWire 1.6.8 accumulate duplicate
`alsa_output.pci-0000_c2_00.1.hdmi-stereo-extra2` sink nodes for the BenQ
RD280UG, all on the same ALSA device. 39 copies built up between 2026-09-04
and 2026-09-23, roughly two a day, and they fill Google Meet's output picker.

Ruled out on 2026-09-23: system suspend (only one in the window), short and
45 s DPMS cycles (the ELD stays present; the BenQ never drops the HDMI link),
and hypridle (not running). No journal output accompanies a leak. Bluetooth
earbud connects (the ADR-0045 drop-ins) are still a candidate.

**Cleanup:** destroy each stale node with `pw-cli destroy <object.id>`, keeping
the original — the only one with `api.alsa.period-size` props. Get the ids
from `pw-dump`: `pactl list short sinks` prints `object.serial`, not
`object.id`.

To catch the next leak with a timestamp, leave `pw-mon` writing to a file and
compare it with the journal around the moment a new node appears.

# UniFi network

The home network this machine sits on. Not managed by `loaf`; recorded here
because changes to it are made from this machine and have regressed it before.

## Rule: pin everything, no auto modes

Never set a radio to Auto. Channel, channel width and TX power are all pinned
to explicit values. Keep Nightly Channel Optimization, Auto-Optimize Network
and similar self-tuning features off, and keep automatic firmware upgrades
off. UniFi's auto modes have changed the network on their own and regressed
it.

Before any change, check the payload for `"channel": "auto"`, automatic width
or power, or optimization flags, and replace them with explicit values. An
audit treats any existing Auto setting as a finding.

## Topology (as of 2026-08-14)

- **Dream Router 7** (gateway and AP), controller at https://192.168.1.1
  (UniFi OS): 2.4 GHz ch 6 / 20 MHz, 5 GHz ch 48 / 80 MHz, 6 GHz ch 37 /
  160 MHz, all at high power, all pinned.
- **AirWire** (UAPEA07): not an AP. A point-to-point 6 GHz bridge whose radio
  follows the Dream Router's channel (wireless mesh uplink). It carries this
  desktop's connection, over USB-C (ADR-0051). Never pin the AirWire's radios:
  its channel is already fixed by the Dream Router's pinned ch 37.

Logging in to the controller needs ui.com SSO with a TOTP code: ask Austin for
a code, or use an API key if one exists.

---
status: accepted
---

# Reach this machine from the MacBook over Tailscale

This desktop is used *instead of* the work MacBook whenever remote access is not
set up. The intent: Tailscale for the network layer, SSH over it, so the MacBook
becomes the client and this machine keeps being the place the work actually runs.

## Decided and implemented, 2026-08-09

**Tailscale SSH, not sshd.** `tailscale set --ssh` is run and `RunSSH` is true in
the daemon prefs. Authentication moves to the tailnet ACLs; no host keys to
manage, nothing listens on the LAN. `sshd` stays exactly as it has always been —
installed, disabled, inactive — and that is now a decision rather than an
accident: the easy mistake this ADR flagged (exposing sshd broadly) is avoided by
never enabling it at all.

**The tailnet already existed by the time this was written down.** `tailscale`
arrived on 2026-08-06 and the node sits on the personal tailnet as
`framework-desktop` (`austin-karren@`), alongside `macbook-pro` and the phone.
The work-context question this ADR raised — whether a work machine may join a
personal tailnet, and whose account owns the node — was therefore settled by
events, in favour of the personal tailnet. If work policy later disagrees, the
node re-joins elsewhere; nothing here depends on which tailnet it is.

**What "remote" reaches: a shell plus long-running processes.** The multiplexer
question this ADR deferred to ADR-0015 was answered there — herdr replaced tmux —
so a dropped SSH connection orphans nothing that runs under it. No remote
*desktop* is attempted; the Hyprland session stays a local seat.

**Idle must never make the machine unreachable.** Recorded as a standing
requirement in ADR-0019 and verified under quattro: the idle chain is
screensaver → lock only, with no suspend listener anywhere in it.

### Verified on this machine

- `tailscaled` — enabled and active; node visible on the tailnet
- `tailscale debug prefs` — `"RunSSH": true`
- `sshd` — disabled and inactive
- Ghostty's `shell-integration-features = no-cursor,ssh-env` was already in the
  tracked config, and matters on the *client* side (the MacBook's own repo)

### Still to verify, from the client

An actual `ssh austinkarren@framework-desktop` from the MacBook — it was offline
when the server side was enabled, so the end-to-end path is untested. A
same-node `tailscale ssh` cannot stand in for it: it dials the node's own
tailnet IP over plain TCP and never enters tailscaled's inbound intercept, so it
reports `connection refused` from the disabled sshd regardless of whether
Tailscale SSH works. Expect the default tailnet policy to run same-user SSH in
`check` mode (a browser re-auth on first connect).

## Addendum: measured as far as one chair allows, 2026-08-09

The paragraph above claimed a same-node test cannot stand in for the MacBook.
That claim is now measured rather than asserted, from two directions:

- `ip route get 100.124.236.50` resolves through the **local table via `lo`** —
  self-addressed traffic is delivered on loopback and never enters the tun, so
  both `ssh austinkarren@100.124.236.50` and same-node `tailscale ssh` hit the
  deliberately-inactive sshd: `connection refused`, as designed.
- Bypassing that would not help either: Tailscale's own routing table (52)
  carries routes for every **peer** but none for the node's own IP, so there is
  no path into the inbound intercept from this host at all. Loopback
  verification of Tailscale SSH is architecturally impossible in kernel mode,
  not merely inconvenient.

What *is* verifiable server-side all checks out, each item measured:

- `RunSSH: true` in the daemon prefs, and present at every tailscaled start in
  the journal back to **Aug 7 19:09** — meaning Tailscale SSH was already on
  through the quattro upgrade window, and the felt lockout of Aug 8 was a
  client-side gap (no MacBook configured to connect), not a server-side one.
- Control grants this node `https://tailscale.com/cap/ssh` in its CapMap — the
  tailnet policy actually allows SSH to it, which the pref alone cannot prove.
- SSH host keys exist under `/var/lib/tailscale/ssh/` (generated Aug 6).
- The WireGuard data path is live: `tailscale ping` to the phone answers
  direct (LAN endpoint, ~193ms), so packets from a peer do reach the intercept
  layer the SSH server sits behind.

Two dead ends worth recording so nobody re-walks them: `tailscale status
--json`'s `Self` object has **no** `sshHostKeys` field (it exists only on peer
views — reading it as "not advertising" is a bug in the reader, not the node),
and `tailscale debug hostinfo` prints only static fields, so SSH advertisement
cannot be confirmed from either. The one artifact still missing is the SSH
handshake itself, and it can only be produced from a peer: the MacBook check
below stands.

## Where this is recorded

`tailscaled`'s enablement and the `--ssh` flag are systemd/daemon state, not
dotfiles — Stow cannot express them and `loaf doctor` does not currently
assert them. This ADR is the record. If remote access ever breaks silently, the
checks worth adding to doctor are `tailscale debug prefs | grep RunSSH` and
`systemctl is-active tailscaled`; they were left out for now because a check
should earn its slot by a failure actually observed (omarchy-desktop-on-cachyos
ADR-0028), and none has been.

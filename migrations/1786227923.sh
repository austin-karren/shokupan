#!/bin/bash

echo "Let this user drive Tailscale without sudo, so the bar toggle works"

# The custom/tailscale bar module toggles the tailnet by running `tailscale up` /
# `tailscale down` directly (see ~/.local/bin/tailscale-icon). Those are privileged
# operations: the daemon only accepts them from root, or from the account named in
# its OperatorUser preference.
#
# The failure this prevents is a silent one. On a machine where OperatorUser is
# unset, the module still renders and still reports state correctly -- reading
# status needs no privilege -- but clicking it does nothing at all. No error, no
# notification, no change. That reads as a dead icon rather than as a permissions
# problem, which is exactly the kind of thing a rebuilt machine should not make
# anyone rediscover.
#
# Idempotent: reads the current preference first and exits without touching
# anything if it already names this user.

if ! command -v tailscale &>/dev/null; then
  echo "  tailscale not installed — nothing to do"
  exit 0
fi

want="${USER:-$(id -un)}"

current=$(tailscale debug prefs 2>/dev/null |
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("OperatorUser") or "")' 2>/dev/null)

if [[ $current == "$want" ]]; then
  exit 0
fi

# Needs root to change. Non-interactive only: a migration runs inside `loaf heal`,
# which may be running from a post-update hook with no one watching, so it must
# never sit on a password prompt. If it cannot get root, say what to run by hand.
if sudo -n true 2>/dev/null; then
  if sudo -n tailscale set --operator="$want" 2>/dev/null; then
    echo "  operator set to $want"
  else
    echo "  could not set operator — run: sudo tailscale set --operator=$want"
  fi
else
  echo "  needs root — run: sudo tailscale set --operator=$want"
fi

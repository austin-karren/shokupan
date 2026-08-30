---
status: accepted
---

# `OMARCHY_PATH` does not survive `ssh box somecommand`, and that is accepted

`ssh box somecommand` reads no shell startup file on this machine. Not
`~/.bashrc`, not the drop-ins under it, neither tier of the bash seam. So
`OMARCHY_PATH` is unset there, and so is everything else the seam exports.
Measured 2026-08-20 and again 2026-08-21; the evidence pack is
`~/backups/shokupan-grill-ssh-seam/`.

This is recorded as **accepted, not pending**, because the record kept saying
otherwise. A wrong gloss on bash's network-stdin rule propagated into seven
files across three repos, and every handoff re-opened it as a live defect. It is
not one on this machine. This ADR states the mechanism once so the question
stops being re-derived, and states the acceptance so it stops being re-asked.

## The mechanism is two conditions, in two different packages

Both are required. Remove either and `~/.bashrc` *would* be read.

1. **This bash is built without `SSH_SOURCE_BASHRC`.** `bash 5.3.15(1)-release`.
   Confirmed two independent ways: the `#ifdef`'s two string literals
   (`SSH_CLIENT`, `SSH2_CLIENT`) are absent from an unstripped `.rodata`, and
   setting those variables on a pipe-stdin `bash -c` changes nothing. Upstream's
   `config-top.h` ships the define commented out.

2. **This machine's `sshd-session` is built with `USE_PIPES`.** So
   `do_exec_no_pty()` hands the child a *pipe* on fd 0, not the session socket.
   Proven off the shipped binary by branch-unique error strings: `pipe in:`,
   `pipe out:`, `pipe err:` are present; `socketpair #1:` and `socketpair #2:`
   are absent.

`shell.c` tests `run_by_ssh || isnetconn (fileno (stdin))`. Condition 1 kills the
left side; condition 2 kills the right, because `isnetconn()` is `getpeername()`
and a pipe returns `ENOTSOCK`.

**Bash's network-stdin detection is compiled in and works on this exact binary.**
Given a real connected socket on fd 0 — AF_UNIX or AF_INET, `getpeername()` does
not care — this bash sources `~/.bashrc` non-interactively, measured. So "bash
cannot detect ssh" and "`man bash`'s network-connection clause is a dead letter"
are both **false**, and neither belongs in this repo. The clause works; sshd
simply does not present it with a socket.

Austin's framing — Omarchy on CachyOS breaks the ssh thing — is right in
substance. Precisely: it is the distro's **bash** build and the distro's
**OpenSSH** build together, neither one alone, and neither of them Omarchy's
doing. Upstream Omarchy does not rely on the seam for this path at all: its
`install/config/ssh-command-path.sh` routes `PATH` through `pam_env` instead, and
says so correctly. That PAM line is why the old picture looked half-working —
`PATH` arrives over `ssh box somecommand`, `OMARCHY_PATH` does not.

`USE_PIPES`'s provenance is **not established**. It is not in `configure.ac` for
`*-*-linux*`, there is no `--with-pipes`, and `defines.h` ships it commented out,
so it arrives via `CPPFLAGS` in the Arch or CachyOS PKGBUILD — which could not be
fetched. That the shipped binary has it is measured; *why* is open. If it turns
out unintentional, this whole thing is a downstream packaging bug rather than a
design constraint, and that would be grounds to revisit.

## What the two-tier split does and does not buy

The split stays. What was wrong was one justification, not the design.

**It does not** deliver anything over `ssh box somecommand`. Nothing does; the
file is never read, and which side of the interactivity guard a line sits on has
no bearing on that path.

**It does** decide the outcome for every shell that reads `~/.bashrc`
non-interactively — that is, any bash whose fd 0 is a connected socket. That is
not hypothetical: `systemd-run --user --pipe` is the measured live case, and the
clean proof is a single unit run twice, identical but for whether fd 0 is a
socket or `/dev/null`. Socket: tier 1 runs. `/dev/null`: it does not. Tier
placement is exactly what decides what such a shell gets.

**It also buys the ~28 ms** that keeps `mise activate bash`, `zoxide init` and
bash-completion out of shells that cannot use them. The separately measured
26.2 ms → 0.2 ms improvement stands and is unaffected by any of this — it was
never contingent on the ssh path, only on the example the comment used to reach
for.

The trailing-`:` asymmetry between the two tiers (commit `dc533b0`) is likewise
untouched. Its argument needs only "tier 1 runs in shells where a stray `$? = 1`
could escape into crumb's tier-1 loop", which remains true.

## Why accepted rather than fixed

Six options were enumerated in the evidence pack (`pam_env`, `SetEnv`,
`PermitUserEnvironment`, `AcceptEnv`, `BASH_ENV`, and accept-and-correct). All
are workarounds for a build-flag combination this repo does not control.

The deciding fact is the machine, not the mechanism: remote access here is
**Tailscale SSH, not sshd** (ADR-0016) — `sshd` is installed, disabled and
inactive by decision — and `ssh box somecommand` is not a thing Austin runs.
Austin's ruling: *"Worth documenting that omarchy on cachyos breaks the ssh thing
but like I said doesn't affect me."*

So this is a **documentation defect, not a functional one**, and the correct fix
was to correct the record. Three of the six options are `sshd_config` directives
and are inert on a machine whose sshd never starts.

## Consequences

- No behaviour changes. The seam, both tiers, the guard placement and every
  `test/loaf-test.sh` assertion stay exactly as they are — the assertions pin
  tier placement, which is still worth pinning.
- Anything a **socket-stdin** non-interactive shell needs must be in tier 1.
  That is the real requirement the seam serves; it is narrower than the one the
  comments used to claim, and it is measured.
- `OMARCHY_PATH` being set does not prove the seam ran — it has four independent
  provenances on this machine (`/etc/profile.d/omarchy.sh`, uwsm's `env.d`,
  systemd inheritance, tier 1). Any future test that checks only `OMARCHY_PATH`
  will mislead.
- If sshd is ever enabled here, this comes back. The mitigation is already
  installed and is upstream's: the `pam_env` PATH line. Variables with no PAM
  backstop would not be covered.
- **Tailscale SSH has never been measured.** It shares no session code with
  OpenSSH and may well execute a login shell, in which case `OMARCHY_PATH` is set
  over the path actually in use and this ADR describes a path nobody travels.
  That does not change the acceptance — it can only make it more comfortable —
  but it is the open measurement, and ADR-0016 warns a same-node
  `tailscale ssh` may not be a valid stand-in for one from the MacBook.

`crumb ADR-0001` records the bashrc seam itself and carries the original wrong
gloss; correcting it is crumb's to do, not this repo's.

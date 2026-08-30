# Working agreements for this repo

Repo-level instructions for agents working in `shokupan`. The architectural
decisions live in `docs/adr/`; this file holds the rules that govern how work
gets done, not what was decided.

## Cite ADRs repo-qualified, never bare across repos

ADR numbers are one shared, interleaved space across several repos — `shokupan`,
`omarchy-desktop-on-cachyos`, `shokupan-plugins` and `crumb` — and the
2026-08-18 split moved records between them without moving the citations. A bare
`ADR-0044` does not say which repo to look in, and the file is often not in the
one you are standing in.

Write the repo name first:

- `shokupan ADR-0002`
- `omarchy-desktop-on-cachyos ADR-0035`
- `shokupan-plugins ADR-0044`
- `crumb ADR-0001`

Every citation that crosses a repo boundary must carry the repo name — in prose,
in a code comment, and in a commit message. A bare dangling `ADR-0044` cost a
full session an hour on 2026-08-19. Citing an ADR that lives in this repo may
stay bare, but qualifying it is never wrong.

Do not add a relative markdown link to an ADR in another repo — the path will
not resolve from here. Name the repo and the number instead.

## Never post upstream without an explicit go

Proposed issues and PRs to Omarchy and other upstreams live as drafts in
`docs/upstream/`. They are written for review and posted only on Austin's
explicit, per-item go — never automatically, never as a side effect of finishing
the draft. The same applies to marketplace and plugin-directory submissions.

This is the operational half of **shokupan-plugins ADR-0044 rule 5**, restated
here because agents read this file every session and that ADR now lives in
another repo. The ADR remains authoritative for the reasoning.

## A lane's teardown includes whatever it spun up

If your work starts a VM, a container or a server, **say so explicitly in your
report and say whether you stopped it**. The orchestrator owns stopping
lane-spawned resources **at delivery, not at merge** — a lane that is never
merged has still left the thing running.

The gap this closes: `/workflow`'s teardown enumerates worktrees, multiplexer
agents, branches, tracking and the main checkout — everything the *harness*
created, and nothing a *lane* created. Three lab VMs from 2026-08-18 were found
still running on 2026-08-21, noticed only because Austin asked why his CPU was
pegged.

The operational facts, because they are why this gets missed:

- libvirt is at `qemu:///system`. A bare `virsh list` reads like there is no VM;
  use `virsh -c qemu:///system list --all`.
- `virsh shutdown` is graceful and **a wedged guest ignores it**. Snapshots
  survive either way, so stopping a lab loses nothing.
- **`virsh destroy` is blocked by the auto-mode permission classifier** — for
  lanes *and* for the orchestrator. A hard stop has to go to Austin as a command
  for him to run, not attempted.
- `ps %CPU` is a **lifetime average, not a current rate**. Use `top -bn2`. On
  2026-08-21 the same guest read 230% under `ps` and ~1% under `top`; the error
  runs both ways, and reading it wrong is what let a wedged guest look idle.

The VM harness itself (`lab/` in `omarchy-desktop-on-cachyos`) has no stop
script, so there is nothing to call — the teardown is manual and therefore has
to be reported rather than assumed.

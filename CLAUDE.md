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

## Stock first, then own boldly

Stock Omarchy wins unless a deviation earns its keep today. When an Omarchy
update breaks a deviation, the default answer is to go back to stock and mark
the ADR regressed, not to re-port the fork. Waybar-era carryovers (bar spacers,
ADR-0029's question-grouped layout, glyph nudges) are the canonical example:
they regressed on every upgrade and were dropped.

When a deviation does earn its keep, don't stop at "that's upstream's file".
Use the lowest rung that works — our own value, a sanctioned extension point
(settings, hooks, plugins, Herdr mods), a hosted wrapper, a full fork as an
overlay. The one hard rule is update-compatibility: never edit a file the
`omarchy` package owns, and anything forked or wrapped carries a
re-diff-after-updates duty (`loaf forks`).

## Derive UI values, don't hand-measure them

When a visual value is needed — an offset, a width, an underline position —
compute it from metrics (TextMetrics, implicitWidth chains, expressions)
instead of tuning a constant until it looks right. Hand-measured constants rot
when fonts, scale or upstream change; ADR-0029's measured CSS is the repo's own
example.

## Edit only the task Austin names

Work only on the thing the current message names. A finished task mentioned as
context ("same as the audio thing") is a reference point, not a work order:
read its code if it helps diagnosis, but don't edit, "improve" or revert it
unless Austin says it is broken. On 2026-08-10 an approved audio fix was
patched and then half-reverted because a complaint about a different tool was
misattributed to it.

If the target is ambiguous, ask one pointed question. If the ask is general
enough to risk a regression, grill it (`/grilling` with `/domain-modeling`)
until it names a specific component.

## Herdr sub-agents get worktrees, never split panes

Every Herdr sub-agent gets its own worktree-backed workspace (`herdr worktree
create --label "Task" --no-focus`), even a read-only diagnosis agent — use a
`debug/*` branch and delete it at cleanup. Never `herdr pane split` to host an
agent: panes carve up the workspace Austin is looking at.

## System details in public posts

The machine runs Omarchy on Arch (ADR-0052). It has not been CachyOS since
2026-09-29, whatever the `omarchy-desktop-on-cachyos` repo name or leftover
files suggest. In upstream issues and comments, give the Omarchy version
(`pacman -Q omarchy`) and the hardware — Framework Desktop, BenQ RD280UG over
USB-C — and check before naming a distro.

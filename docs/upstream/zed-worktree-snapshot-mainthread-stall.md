# Draft upstream issue — zed-industries/zed

Status: DRAFT — not posted. Needs Austin's review and explicit go (ADR-0044
decision 5). Target: new GitHub issue; reference #39269, #32686, #57705 and
discussion #53626 as adjacent reports.

---

Title: **Worktree snapshot application blocks the main thread for 20s+ on
large node_modules trees (worktree.rs:1363), causing compositor ANR dialogs**

## Summary

On a project with ~1.1M files (13 GB pnpm monorepo; only ~4,200 git-tracked,
~1.06M under 38 `node_modules` trees), Zed's foreground worktree-snapshot
applier (`worktree.rs:1363` in v1.14.2 — the `set_snapshot` task inside
`start_background_scanner`) blocks the main thread for 20–25 seconds at a
time. While blocked, Zed cannot answer Wayland pings, so Hyprland shows its
"application is not responding" dialog. The editor feels laggy the rest of
the time.

Zed's own hang telemetry identifies the site: hang density **1.4** at
`worktree.rs:1363` (next-worst site: 0.0006), mean main-thread hang **4.7s**,
p95 **13.7s**. Hang traces were auto-saved to
`~/.local/share/zed/hang_traces/`.

## Environment

- Zed 1.14.2, Wayland, Hyprland (Omarchy), CachyOS (Arch), kernel 7.1.6
- AMD Radeon 8060S (Strix Halo iGPU), Mesa 26.1.6, RADV only — GPU ruled out:
  clean wgpu adapter selection every launch, zero GPU errors in any log
- vtsls (TypeScript) registers auto-import file watchers over `node_modules`,
  which forces the scanner over those trees

## Reproduction / A-B measurement

150-second monitored runs, same project, opening 30 files via CLI:

| Config | Result |
|---|---|
| defaults | one continuous **25s** main-thread stall at worktree.rs:1363; **4** hang traces |
| `file_scan_exclusions` += `**/node_modules`, `**/.turbo`, `**/.next`, `**/.sst` (scanned tree drops 1.1M → ~54k files) | **zero** hang traces, no hang log lines |

## Why report it despite the workaround

- Applying scan snapshots on the foreground thread means UI responsiveness
  degrades linearly with tree size — the workaround just shrinks the input.
- The stock `file_scan_exclusions` default does not include `node_modules`,
  so any large JS/TS monorepo hits this out of the box, and the setting
  REPLACES rather than merges defaults, making the workaround easy to get
  wrong (see also #21018).
- Several existing reports look like undiagnosed instances of this
  (#39269 was closed for lack of a repro; this one has telemetry + A/B data).

## Suggested directions (upstream's call)

- Chunk or debounce foreground snapshot application so no single apply
  exceeds a frame budget.
- Consider excluding `node_modules` from the scan by default (or auto-suggest
  exclusions for pathological trees, as discussion #53626 proposes), while
  keeping LSP go-to-definition working as it does today with exclusions.

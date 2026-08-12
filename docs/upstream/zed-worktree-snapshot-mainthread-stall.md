# Draft upstream issue — zed-industries/zed

Status: DRAFT — not posted. Austin reviews, edits, and posts from his own
account (ADR-0044 decision 5; Zed's CONTRIBUTING.md expects the human in the
loop to own the report, so the submit click is his).

Structured to match Zed's bug template (`10_bug_report.yml`). Before posting:
run `zed: copy system specs into clipboard` in Zed's command palette and
paste into the specs section, and optionally paste the tail of Zed.log.

Title: **Worktree snapshot application blocks the main thread for 20s+ on
large node_modules trees (worktree.rs:1363), causing compositor ANR dialogs**

---

## Reproduction steps

1. Open a large pnpm monorepo in Zed with default settings. Mine is 13 GB,
   ~1.1M files — ~4,200 git-tracked, ~1.06M under 38 `node_modules` trees.
   (vtsls registers auto-import file watchers over `node_modules`, so the
   scanner walks those trees.)
2. Work normally, or just open a few dozen files.
3. Within minutes the window stops responding for long stretches; on
   Wayland/Hyprland the compositor shows its "application is not responding"
   dialog because Zed can't answer pings while the main thread is blocked.

Measured A/B on the same project, 150-second monitored runs, 30 files opened
via the CLI:

| Config | Result |
|---|---|
| defaults | one continuous **25s** main-thread stall; **4** hang traces saved |
| `file_scan_exclusions` = defaults + `**/node_modules`, `**/.turbo`, `**/.next`, `**/.sst` (scanned tree drops to ~54k files) | **zero** hang traces, no hang log lines |

Zed's own hang telemetry points at a single site: hang density **1.4** at
`worktree.rs:1363` (next-worst site: 0.0006), mean main-thread hang **4.7s**,
p95 **13.7s**. That line is the foreground task that applies each background
scan snapshot (`set_snapshot` inside `start_background_scanner`). Traces were
auto-saved to `~/.local/share/zed/hang_traces/`.

## Current vs. Expected behavior

**Current:** applying worktree-scan snapshots happens on the main thread, so
UI responsiveness degrades with tree size — on a tree this large the window
freezes for 20–25s at a time and the compositor declares the app hung. The
editor feels laggy even between the big stalls.

**Expected:** scanning a large tree may take as long as it takes, but the UI
thread should never be blocked past a frame budget — snapshot application
chunked/debounced, or `node_modules` excluded from the scan by default (or
auto-suggested for pathological trees, as discussion #53626 proposes).

The `file_scan_exclusions` workaround is effective but is a workaround: it
shrinks the scanner's input rather than fixing the blocking apply, it hides
excluded dirs from the project panel/file finder/search, and the setting
REPLACES the defaults rather than merging (see #21018), so it's easy to get
wrong. Possibly related undiagnosed reports: #39269, #32686, #57705.

## Zed version and system specs

<!-- TODO(austin): run `zed: copy system specs into clipboard` and paste here -->
Zed: v1.14.2
OS: CachyOS (Arch), kernel 7.1.6, Wayland (Hyprland)
GPU: AMD Radeon 8060S (Strix Halo iGPU), Mesa 26.1.6, RADV via wgpu/Vulkan —
GPU ruled out: clean adapter selection every launch, no GPU errors in logs

## Attach Zed log file

<details><summary>Zed.log</summary>

```log
<!-- TODO(austin, optional): paste relevant tail of ~/.local/share/zed/logs/Zed.log -->
```

</details>

## Relevant Zed settings

<details><summary>settings.json (workaround applied)</summary>

```json
"file_scan_exclusions": [
  "**/.git", "**/.svn", "**/.hg", "**/.jj", "**/CVS",
  "**/.DS_Store", "**/Thumbs.db", "**/.classpath", "**/.settings",
  "**/node_modules", "**/.turbo", "**/.next", "**/.sst"
]
```

</details>

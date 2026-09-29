---
status: accepted
supersedes: 0034
---

# Omarchy on Arch, not CachyOS

## Context

ADR-0034 made CachyOS the base and Omarchy a desktop layer on top of it, with
the kernel and the znver4 builds as the reason. Two months of running that
split showed what it cost:

- Every Omarchy channel operation was a hazard. `omarchy-channel-set` and
  `omarchy-refresh-pacman` overwrite `pacman.conf` and the mirrorlist and run
  `-Syyuu`; on a CachyOS base that is a full downgrade of 1,100+ packages, so
  `loaf doctor` grew checks whose job was to detect Omarchy having done what
  Omarchy is designed to do (ADR-0035's mirrorlist skew, the `repos` check).
- The boot contract broke once (ADR-0047) because Omarchy's initramfs hooks
  assume an Omarchy-shaped install, and the recovery took a live USB.
- The rice carried a parallel updater (`system-update`) so the base and the
  desktop could be updated separately and blamed separately.
- Omarchy 4.0 ships its own kernel (`linux-omarchy`) from the `[omarchy]`
  repo, so "the kernel is the reason" no longer favours CachyOS: both bases
  now mean a distro-built kernel from a repo the desktop controls.

The in-place migration was audited on 2026-08-31 (`lane/cachyos-blast-radius`)
and run on 2026-09-29: `omarchy-refresh-pacman stable`, Arch kernels installed
beside the CachyOS ones, reboot, CachyOS-only set removed, then
`omarchy-channel-set stable`, which installed `linux-omarchy` and made it the
default boot entry.

## Decision

The base is stock Arch on an Omarchy channel. `pacman.conf` and the mirrorlist
are whatever `omarchy-channel-set` writes; the kernel is `linux-omarchy`; the
limine menu header is Omarchy's default. The rice does not maintain a second
updater — `omarchy-update` is the updater.

What the rice still guards, because it is machine state rather than channel
state:

1. **The boot contract (ADR-0047) stays.** This install was made by the
   CachyOS installer and boots with `rd.luks.uuid=`; Omarchy's hooks still
   select the busybox `encrypt` flavour. The `cryptdevice=` drop-in is
   load-bearing on every kernel, `linux-omarchy` included. The 2026-08-31
   audit called that parameter "stale" — it was wrong, and following it would
   have bricked the machine at the first rebuild.
2. **`loaf doctor`'s base checks inverted** rather than disappearing:
   `repos` fails on a leftover `[cachyos*]` section or a missing `[omarchy]`
   one, `mirrorlist` warns when the mirror is not the channel's, `kernel`
   expects `linux-omarchy` installed and running.
3. **`loaf install`** requires the `[omarchy]` repo and installs
   `linux-omarchy` if absent, mirroring what it did for CachyOS.

## What the migration taught

- `cachyos-snapper-support`'s remove scriptlet **deletes the snapper root
  config and the `.snapshots` subvolume** — every snapshot, not just its
  template. The audit said the live configs would survive. Omarchy's
  `install/config/snapper.sh` recreates the config; the history is gone.
- `pacman -Rns` of `cachyos-settings` cascades to `zram-generator`, `snap-pac`
  and `ananicy-cpp`. The first two are load-bearing (swap after reboot;
  pre/post snapshots) and were reinstalled.
- `cachyos-settings` owns the only `zram-generator.conf` plus sysctl, udev,
  modprobe and NetworkManager drop-ins under `/usr/lib`. Copies now live in
  `/etc` (`/etc/systemd/zram-generator.conf`, `/etc/sysctl.d/70-cachyos-settings.conf`,
  `/etc/udev/rules.d/{20-audio-pm,30-zram,40-hpet-permissions,50-sata,60-ioschedulers,69-hdparm,99-cpu-dma-latency}.rules`,
  `/etc/modprobe.d/cachyos-{amdgpu,blacklist}.conf`, `/etc/modules-load.d/ntsync.conf`,
  `/etc/NetworkManager/conf.d/cachyos-dns.conf`, `/etc/systemd/journald.conf.d/00-journal-size.conf`).
  Machine-side, untracked; they are the CachyOS tuning kept on purpose.
- CachyOS's patched pacman stamps `%INSTALLED_DB%` into every local package
  record; Arch's pacman warns on each one until the key is stripped.
- `r8152-dkms` (ADR-0051) needs the new kernel's headers in the same
  transaction, or the dock's NIC is dead on the first boot.

## Consequences

- ADR-0034 is superseded. ADR-0035's install path now starts from an Omarchy
  channel, not a CachyOS ISO. ADR-0047's guard is unchanged.
- `system-update` and its menu row are deleted; `omarchy-update` runs the
  rice's post-update hooks (`10-loaf-heal`, `20-forks-drift`) as before.
- The repo name `omarchy-desktop-on-cachyos` and this repo's CachyOS-era
  prose (README, CONTEXT, ADR-0001, ADR-0034) describe a base that no longer
  exists. Citations stay as written — they are history — but a new reader
  should start here.
- Kept snapshots and backups after the migration: snapper `root` #1
  ("baseline: Omarchy stable on linux-omarchy") and
  `/root/boot-backup-omarchy-baseline-2026-09-29`.

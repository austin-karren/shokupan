# 0051 — The AirWire runs r8152-dkms, not cdc_ncm

Date: 2026-09-02
Status: accepted

## Context

The UniFi AirWire bridge connects to framework-desktop over USB-C and
enumerates as a Realtek RTL8157 USB 5GbE NIC (0bda:8157). The in-kernel
r8152 driver on linux-cachyos-lts 6.18 has no RTL8157 support, so the
kernel bound the generic `cdc_ncm` driver. Under receive load cdc_ncm
generated RX errors (~1% of packets), which collapsed bulk TCP: ~40 Mbps
LAN ceiling, single-digit Mbps to many WAN destinations, while ping and
low-rate traffic (gaming) stayed fine. Measured, not asserted: LAN bulk
test 42 Mbps with +106 rx_errors in 1.5 s before; 477 Mbps single-stream
(kernel.org) with +0 rx_errors after.

## Decision

Install `r8152-dkms` (AUR, Realtek driver v2.21.4.20260427, which carries
the 0x8157 device ID). Its udev rule (50-usb-realtek-net.rules) switches
the device out of CDC/NCM mode so r8152 claims it. DKMS builds for both
installed kernels (6.18 LTS and 7.2 cachyos), so the fix survives kernel
switches. Note: linux-cachyos 7.2.2's in-kernel r8152 also supports the
8157; the DKMS module shadows it, which is fine.

## Consequences

- The interface renamed `enp196s0f4u1c2` → `enp196s0f4u1` (NCM's extra
  USB function suffix disappeared). Anything keyed on the old name
  (firewall rules, scripts) must use the new name.
- Link now negotiates 5000 Mb/s full duplex.
- Removing r8152-dkms without a kernel that supports the 8157 regresses
  to cdc_ncm and the crawl comes back.

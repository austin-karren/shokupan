-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all
-- Ported from monitors.conf at the quattro migration (ADR-0033).

-- ACTIVE: 28" 3840x2560 (3:2) panel, ~165 physical PPI.
--
-- Written as 1.666667 rather than 1.8 on purpose. Wayland quantises fractional
-- scale to 1/120 steps, and Hyprland additionally requires a whole-pixel logical
-- size, so a valid scale n/120 needs n to divide gcd(3840*120, 2560*120)=153600.
-- The only values that qualify anywhere near here are:
--
--     1.600000 -> 2400x1600 logical
--     1.666667 -> 2304x1536 logical   <-- this one
--     2.000000 -> 1920x1280 logical
--
-- So 1.8 was never actually in effect: Hyprland silently snapped it to 1.666667.
-- There is nothing between 1.6 and 1.666667, and 1.5/1.75 are invalid here too.
-- Declaring the real value keeps `hyprctl monitors` matching this file. Quattro's
-- stock template says "auto", which resolved to 1.6 - a whole rung smaller UI
-- than this desktop is tuned for.
--
-- Known cosmetic effect: the bar's monitor panel highlights NO scale preset on
-- this machine. Its presets are 1/1.25/1.6/2/3/4 and the highlight needs an
-- exact normalized match; 1.666667 normalizes to 1.67 and 1.6 stays 1.6, so
-- nothing lights. Expected, not a bug in this pin — see ADR-0029's final
-- addendum and docs/upstream/monitor-panel-off-preset-scale.md.
--
-- For UI sizing between the two rungs, use fractional TEXT scaling instead of
-- surface scale (gsettings org.gnome.desktop.interface text-scaling-factor).
--
-- NOTE: GDK_SCALE must be an INTEGER. GTK parses "1.75" as 1, which renders GTK3
-- apps at 1x. Do not set a fractional GDK_SCALE.
hl.env("GDK_SCALE", "2")
-- "highres" = highest resolution at its best refresh rate. On this panel that
-- is 3840x2560@119.99 (verified) — and unlike a hardcoded mode it adapts to
-- whatever monitor is plugged in. "preferred" was wrong here: the EDID
-- preferred mode is the 59.98Hz one, not 120.
hl.monitor({ output = "", mode = "highres", position = "auto", scale = 1.666667 })

-- Alternative: one rung smaller UI, 2400x1600 logical.
-- Gives ~48 more CSS px per half-width tile, which is not enough to matter for
-- sites with hardcoded min-widths (the Chrome Web Store wants 1280).
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.6 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

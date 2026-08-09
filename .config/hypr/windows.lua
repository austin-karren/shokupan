-- Personal window rules, loaded from hyprland.lua after Omarchy's defaults.
-- Ported from windows.conf at the quattro migration (ADR-0033). Quattro's stock
-- config has no user windows file - hyprland.lua requires this one explicitly.
--
-- The calendar-popup rules that used to live here (ADR-0006) are deliberately
-- absent: quattro's clock popup ships a month grid, so whether that special
-- workspace still exists is ADR-0006's call, and that ADR is not this file's.

-- GNOME Settings (gnome-control-center) -------------------------------------
-- Floated because it is a dialog-shaped app that tiles badly, but left on the
-- normal workspace: Online Accounts hands off to a browser for OAuth, and a
-- special workspace would hide the window mid-flow when focus moved to the
-- browser (hide_special_on_workspace_change = true).
--
-- Size is in LOGICAL pixels: 1500x1000 is a bit under two-thirds of the
-- 2304x1536 logical desktop (see monitors.lua).
o.window("org.gnome.Settings", { float = true })
o.window("org.gnome.Settings", { center = true })
o.window("org.gnome.Settings", { size = { 1500, 1000 } })

-- The About TUI ---------------------------------------------------------------
--
-- Omarchy's Menu > About is fastfetch wrapped in `bash -c 'fastfetch; read'`,
-- which inherits Omarchy's generic floating-window size of 875x600 - too narrow
-- for fastfetch, so every value wrapped mid-word. Measured in the .conf era: a
-- cell is ~9.94 x ~23.08 logical px and fastfetch needs 116 columns and 30 rows,
-- so 1200x740 gives ~120x31 with slack.
--
-- The class is org.omarchy.bash, not something About-specific: the launcher
-- derives the app-id from the first word of the command, and About's starts with
-- `bash`. Any other TUI launched as `bash -c ...` takes this size too.
--
-- `tag = "floating-window"` in the match is load-bearing and NOT decoration.
-- Quattro still sizes these windows with a tag-matched rule
-- (default/hypr/apps/system.lua: size 875x600 against the tag), and a tag-matched
-- rule beats a class-matched one no matter the load order - tags resolve in their
-- own pass. Matching the tag as well puts this rule in the same pass, where
-- loading later is what makes it win.
o.window({ tag = "floating-window", class = "org.omarchy.bash" }, { size = { 1200, 740 } })

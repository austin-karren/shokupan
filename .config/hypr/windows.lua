-- Personal window rules, loaded from hyprland.lua after Omarchy's defaults.
-- Ported from windows.conf at the quattro migration (ADR-0033). Quattro's stock
-- config has no user windows file - hyprland.lua requires this one explicitly.
--
-- GNOME Calendar as the clock popup's engine (ADR-0006) ----------------------
--
-- Restored with the r1744 calendar-clone work: the quattro port dropped these
-- rules on the (wrong) assumption the clock's month grid replaced the app, and
-- without them a cold gnome-calendar opened as a normal tiled window.
--
-- `silent`, UNLIKE the .conf era: autostart.lua now preloads gnome-calendar at
-- login, and a non-silent rule would reveal the popup over whatever boots
-- first. The cost is that calendar-toggle's cold branch must reveal the
-- special workspace itself after launch, which it does.
--
-- Size is monitor-relative via rule EXPRESSIONS, not percent strings. In the
-- lua config provider a size string feeds Hyprland's math-expression parser
-- (variables monitor_w/monitor_h/window_w/... — see the Meet popup rule below
-- and upstream's default/hypr/apps/webcam-overlay.lua, the sanctioned idiom
-- for monitor-relative geometry). That grammar has NO percent syntax: the
-- earlier `"72%"` hit "failed to parse expression" and the size effect was
-- dropped SILENTLY — float/center/workspace still applied (separate rules),
-- `hyprctl configerrors` stayed empty, and the window kept gnome-calendar's
-- own remembered size (gsettings org.gnome.calendar window-size, 768x600).
--
-- 3/5 and 18/25 are 60% and 72% of the LOGICAL monitor: 1382x1106 on the
-- 2304x1536 desktop, a 1.25:1 frame — SLIGHTLY wider than tall, which is what
-- was asked for. The first cut used 72%x62% (1658x952, 1.74:1): wider than
-- tall, but not slightly. Height stays off full-height on purpose. Written as
-- fractions because the expression grammar is plain arithmetic. Expressions evaluate at
-- map time against the window's monitor, so no pixels are hardcoded and the
-- rule beats the client's remembered size: DefaultFloatingAlgorithm warps the
-- floating window to its DESIRED geometry first, then applies the size rule
-- on top (same v0.56.2 order the Meet rule below relies on).
o.window("org.gnome.Calendar", { float = true })
o.window("org.gnome.Calendar", { center = true })
o.window("org.gnome.Calendar", { size = { "(monitor_w*3/5)", "(monitor_h*18/25)" } })
o.window("org.gnome.Calendar", { workspace = "special:calendar silent" })

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

-- Google Meet: the call popup is Meet's, the main window keeps its border ------
--
-- Omarchy's Meet PiP rule (default/hypr/apps/pip.lua) matches
-- { tag = chromium-based-browser, title = "^Meet - .+" }. During a call TWO
-- windows wear that title: the popup Meet spawns, and the main browser window,
-- whose title becomes "Meet - <code> - Helium" while the call tab is focused.
-- Dynamic effects re-evaluate on every title change, so the main window loses
-- its border (border_size 0) and browser opacity mid-call. Its static effects
-- (float/pin/size/move) never hit the main window, because statics match
-- against initial_title - which is why only decorations broke.
--
-- initial_title is therefore also the discriminator: the popup maps already
-- titled "Meet - ..." (observed - upstream's static float/size do land on it),
-- while the main window maps as "New Tab - Helium". Both rules below match the
-- tag as well, for the same reason the About rule above does.

-- Main window: re-assert the standard chromium-based-browser look that pip.lua
-- strips during a call. border_size reads the value looknfeel has set by this
-- point rather than repeating it (snapshot at load: the no-gaps toggle changes
-- the global afterwards, and this rule lags it until the next reload - the
-- toggle's own reload included). opacity mirrors default/hypr/apps/browser.lua.
-- Over-matching is harmless by construction: the effects ARE the default look.
o.window({ tag = "chromium-based-browser", title = "^Meet - .+", initial_title = "negative:^Meet - .+" }, {
  border_size = hl.get_config("general.border_size"),
  opacity = "1.0 0.985",
})

-- The popup: let Meet pick its own geometry. `size` is static and has no
-- unset, but its expressions evaluate against the window's own size, which
-- Hyprland warps to the client's DESIRED geometry just before computing them
-- (DefaultFloatingAlgorithm.cpp, v0.56.2: "set this here so that expressions
-- can use it") - so { window_w, window_h } is an identity override that
-- cancels pip.lua's 600x338 while keeping whatever Meet asks for. The forced
-- horizontal frame was the wallpaper bleed: Meet prefers a vertical
-- document-PiP aspect and left the rest of the 600x338 frame undrawn.
-- keep_aspect_ratio would freeze that shape against Meet-driven resizes, so it
-- goes too. pip.lua's float/pin/move/border 0/opacity survive on purpose:
-- they are the useful part (opaque borderless popup, follows across
-- workspaces, parked bottom-right - move computes from the real size).
o.window({ tag = "chromium-based-browser", initial_title = "^Meet - .+" }, {
  size = { "window_w", "window_h" },
  keep_aspect_ratio = false,
})

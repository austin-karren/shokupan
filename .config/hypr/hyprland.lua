-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Personal overrides, loaded after Omarchy's defaults so package updates can
-- improve the defaults without rewriting these files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")

-- Single-window ZEN aspect ratio (ADR-0026): 6:5, not Omarchy's 1:1 square.
--
-- The toggle mechanism is quattro's own: SUPER+CTRL+BACKSPACE (and the Toggle
-- Menu) run omarchy-hyprland-toggle, which copies Omarchy's flag file - which
-- hardcodes { 1, 1 } - into ~/.local/state/omarchy/toggles/hypr/ and reloads.
-- That flag loads with the toggles above, i.e. after every one of our files,
-- so no earlier file can win by ordering. This runs later still and corrects
-- the VALUE while leaving the on/off mechanism entirely Omarchy's.
--
-- This replaces the .conf era's polling repair: ratio-toggle rewrote the flag
-- file's contents and the bar re-checked it every 3 seconds. Now the value is
-- fixed at config time, in the same reload the toggle itself issues - nothing
-- polls, and the flag file's contents stop mattering.
--
-- 6:5 and not wider because Hyprland silently ignores the setting unless it
-- would shrink the window to <= 80% of the available width (measured; see
-- ADR-0026 and ratio-toggle). Raising it past ~1.23 on this display makes the
-- toggle appear to do nothing at all.
do
  local paths = require("default.hypr.paths")
  local flag = io.open(paths.state_home .. "/omarchy/toggles/hypr/single-window-aspect-ratio.lua", "r")
  if flag then
    flag:close()
    hl.config({ layout = { single_window_aspect_ratio = { 6, 5 } } })
  end
end

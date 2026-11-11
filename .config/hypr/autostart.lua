-- Extra autostart processes, loaded from hyprland.lua after Omarchy's defaults
-- (which already require this module name — stock ships a commented template at
-- /usr/share/omarchy/config/hypr/autostart.lua; this file shadows it via the
-- ~/.config/?.lua entry bootstrap.lua puts first on package.path).

local paths = require("default.hypr.paths")
local home = paths.home



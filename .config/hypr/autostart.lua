-- Extra autostart processes, loaded from hyprland.lua after Omarchy's defaults
-- (which already require this module name — stock ships a commented template at
-- /usr/share/omarchy/config/hypr/autostart.lua; this file shadows it via the
-- ~/.config/?.lua entry bootstrap.lua puts first on package.path).

local paths = require("default.hypr.paths")
local home = paths.home


-- ApexShot daemon: the tray icon (recording indicator + stop controls in the
-- bar), the recording UI, and the `record stop` D-Bus endpoint the
-- CTRL+ALT+SHIFT+S bind calls — none of which exist without it. ApexShot
-- installs an XDG autostart entry, but Hyprland does not run XDG autostart,
-- so the daemon had never started on this desktop: record attempts failed
-- silently and stop had nothing to talk to (diagnosed 2026-09-01). Requires
-- show_menu_bar_icon: true in ~/.config/apexshot/config.yml — with the tray
-- disabled the daemon exits at startup by design.
o.launch_on_start("/usr/bin/apexshot daemon")

-- Extra autostart processes, loaded from hyprland.lua after Omarchy's defaults
-- (which already require this module name — stock ships a commented template at
-- /usr/share/omarchy/config/hypr/autostart.lua; this file shadows it via the
-- ~/.config/?.lua entry bootstrap.lua puts first on package.path).

local home = os.getenv("HOME")

-- GNOME Calendar preload (ADR-0006): warmed at login so the first calendar
-- click is an instant popup instead of a seconds-long evolution-data-server
-- cold start. The windows.lua rule parks it on special:calendar SILENT, so
-- nothing flashes during boot; calendar-toggle owns the reveal.
o.launch_on_start("gnome-calendar")

-- Click-outside dismissal for that popup: hide special:calendar when focus
-- moves to a non-calendar window (ADR-0006 addendum).
o.launch_on_start(home .. "/.local/bin/calendar-autohide")

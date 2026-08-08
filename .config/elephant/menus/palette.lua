--
-- System palette for Walker: Omarchy's Toggle Menu plus this rice's own commands,
-- merged into the SAME list as the application launcher. See ADR-0027.
--
-- GENERATED - do not hand-edit the glyphs. Every label carries a Nerd Font glyph, and
-- pasting those through an editor is lossy: a dropped glyph leaves an entry that renders
-- as nothing, with no error anywhere.
--
-- TWO NON-OBVIOUS MECHANISMS
--
-- 1. `FixedOrder = true` IS WHAT PUTS THESE ENTRIES FIRST. With an empty query Walker
--    merges every provider into one list sorted by text, and provider order in the query
--    has no effect. FixedOrder overrides that for this provider: the entries stay
--    contiguous, in the order defined below, ahead of the applications. Measured at
--    positions 0-22 of 86, with the first application at 23.
--
--    An earlier revision added a leading space to every `Text` believing THAT was what
--    sorted them first. It was not - it only broke the row alignment. Do not add it back.
--
-- 2. THE GLYPH GOES IN `Icon`, NOT IN `Text`. item.xml ships an ItemImageFont label
--    (width-chars 2) in the same column as the image widget, for exactly this. Putting
--    the glyph in the label instead indents each row by its own glyph's advance width,
--    so rows do not line up with the applications - or with each other.
--    The matching `.item-image-text` rule in the walker theme gives that slot the same
--    box as an application icon, so both row types put their label at the same x.
--
-- Neither is documented; both were established by querying elephant and measuring
-- screenshots of the rendered list.
--
-- ORDER AND NAMING: Omarchy's Toggle Menu entries come first, in Omarchy's order and under
-- Omarchy's names, because those are canonical. This rice's own commands follow. Where
-- both had an entry, Omarchy's name wins - hence "Start Screensaver" for the one that
-- launches it, since Omarchy's "Screensaver" is the on/off toggle.
--
Name = "palette"
NamePretty = "System"
-- No Icon: the label already carries a Nerd Font glyph, and setting a provider icon makes
-- every entry render an application-style image beside it, which reads as a broken app
-- entry rather than a command. Omarchy's own menus set no icon for the same reason.
HideFromProviderlist = true
FixedOrder = true
Description = "System commands and toggles"
-- Rank a match on the label above a match on the keywords, and both above the subtext.
-- Without this, a query like "the" matches "End the session" / "Skip the boot menu" and
-- buries the applications under commands that merely contain a common word.
-- PRIORITY-REMOVED-FOR-TEST

local function cmd_ok(c)
  local ok = os.execute(c .. " >/dev/null 2>&1")
  return ok == true or ok == 0
end

local function toggle_enabled(name)
  local f = io.open(os.getenv("HOME") .. "/.local/state/omarchy/toggles/" .. name, "r")
  if f then f:close() return true end
  return false
end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close() return true end
  return false
end

function GetEntries()
  local entries = {}
  local function add(e) table.insert(entries, e) end

  -- Omarchy Toggle Menu, in Omarchy's order and under Omarchy's names.
  add({
    Text = "Screensaver",
    Icon = "󱄄",
    Keywords = {"screensaver", "idle"},
    Actions = { activate = "omarchy-toggle-screensaver" },
  })
  add({
    Text = "Nightlight",
    Icon = "󰔎",
    Keywords = {"night", "blue light", "warm"},
    Actions = { activate = "omarchy-toggle-nightlight" },
  })
  add({
    Text = "Idle Lock",
    Icon = "󱫖",
    Keywords = {"idle", "lock", "sleep"},
    Actions = { activate = "omarchy-toggle-idle" },
  })
  add({
    Text = "Notifications",
    Icon = "󰂛",
    Keywords = {"dnd", "do not disturb", "silence"},
    Actions = { activate = "omarchy-toggle-notification-silencing" },
  })
  add({
    Text = "Top Bar",
    Icon = "󰍜",
    Keywords = {"waybar", "bar", "panel"},
    Actions = { activate = "omarchy-toggle-waybar" },
  })
  add({
    Text = "Workspace Layout",
    Icon = "󱂬",
    Keywords = {"tiling", "dwindle", "master"},
    Actions = { activate = "omarchy-hyprland-workspace-layout-toggle" },
  })
  add({
    Text = "Window Gaps",
    Icon = "",
    Keywords = {"gaps", "spacing"},
    Actions = { activate = "omarchy-hyprland-window-gaps-toggle" },
  })
  add({
    Text = "1-Window Zen Ratio",
    Icon = "",
    Keywords = {"zen", "aspect", "ratio", "single window"},
    Actions = { activate = "ratio-toggle" },
  })
  add({
    Text = "Monitor Scaling",
    Icon = "󰍹",
    Keywords = {"scale", "hidpi", "resolution"},
    Actions = { activate = "omarchy-hyprland-monitor-scaling-cycle" },
  })
  add({
    Text = "Direct Boot",
    Icon = "",
    Keywords = {"boot", "grub"},
    Actions = { activate = "omarchy-launch-floating-terminal-with-presentation omarchy-config-direct-boot" },
  })
  add({
    Text = "Passwordless Sudo",
    Icon = "󰟵",
    Keywords = {"sudo", "password"},
    Actions = { activate = "omarchy-launch-floating-terminal-with-presentation omarchy-sudo-passwordless" },
  })

  -- Appearance is dynamic: label it with where it will take you, not where you are.
  if file_exists(os.getenv("HOME") .. "/.config/omarchy/current/theme/light.mode") then
    add({
      Text = "Switch to Dark",
    Icon = "󰖔",
      Keywords = {"dark", "appearance", "mode"},
      Actions = { activate = "toggle-appearance" },
    })
  else
    add({
      Text = "Switch to Light",
    Icon = "󰖨",
      Keywords = {"light", "appearance", "mode"},
      Actions = { activate = "toggle-appearance" },
    })
  end

  add({
    Text = "Emoji & Symbols",
    Icon = "󰇲",
    Keywords = {"emoji", "symbol", "unicode"},
    Actions = { activate = "omarchy-launch-walker -m symbols" },
  })
  add({
    Text = "Clipboard History",
    Icon = "󰅍",
    Keywords = {"clipboard", "paste", "history"},
    Actions = { activate = "omarchy-launch-walker -m clipboard" },
  })
  add({
    Text = "Wallpaper",
    Icon = "󰸉",
    Keywords = {"background", "wallpaper"},
    Actions = { activate = "omarchy-menu background" },
  })
  add({
    Text = "Theme",
    Icon = "󰏘",
    Keywords = {"theme", "colours", "appearance"},
    Actions = { activate = "omarchy-menu theme" },
  })

  -- Omarchy's Install / Remove / Update menus, surfaced directly in the palette so they
  -- are reachable by name instead of by walking the Omarchy Menu tree. Each jumps to the
  -- same submenu `omarchy-menu` would show. Names and glyphs are Omarchy's, per the rule
  -- above, and were extracted from omarchy-menu rather than retyped.
  add({
    Text = "Install",
    Icon = "󰉉",
    Keywords = {"install", "add", "package", "software", "app"},
    Actions = { activate = "omarchy-menu install" },
  })
  add({
    Text = "Remove",
    Icon = "󰭌",
    Keywords = {"remove", "uninstall", "delete", "package"},
    Actions = { activate = "omarchy-menu remove" },
  })
  add({
    Text = "Update Omarchy Desktop",
    Icon = "",
    Keywords = {"update", "upgrade", "omarchy", "desktop", "shell", "bar"},
    Actions = { activate = "omarchy-menu update" },
  })
  add({
    Text = "Update System",
    Icon = "",
    Keywords = {"update", "upgrade", "cachyos", "arch", "pacman", "aur", "flatpak", "system"},
    Actions = { activate = "omarchy-launch-floating-terminal-with-presentation system-update" },
  })
  add({
    Text = "Start Screensaver",
    Icon = "󱄄",
    Keywords = {"screensaver", "blank"},
    Actions = { activate = "omarchy-launch-screensaver force" },
  })
  add({
    Text = "Lock",
    Icon = "󰌾",
    Keywords = {"lock", "secure"},
    Actions = { activate = "omarchy-system-lock" },
  })
  if not toggle_enabled("suspend-off") then
    add({
      Text = "Sleep",
    Icon = "󰒲",
      Keywords = {"suspend", "sleep"},
      Actions = { activate = "systemctl suspend" },
    })
  end
  if cmd_ok("omarchy-hibernation-available") then
    add({
      Text = "Hibernate",
    Icon = "󰤁",
      Keywords = {"hibernate"},
      Actions = { activate = "systemctl hibernate" },
    })
  end
  add({
    Text = "Log Out",
    Icon = "󰍃",
    Keywords = {"logout", "sign out"},
    Actions = { activate = "omarchy-system-logout" },
  })
  add({
    Text = "Restart",
    Icon = "󰜉",
    Keywords = {"reboot", "restart"},
    Actions = { activate = "omarchy-system-reboot" },
  })
  add({
    Text = "Shut Down",
    Icon = "󰐥",
    Keywords = {"shutdown", "power off", "poweroff"},
    Actions = { activate = "omarchy-system-shutdown" },
  })

  return entries
end

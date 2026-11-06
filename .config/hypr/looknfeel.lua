-- Change the default Omarchy look'n'feel. Ported from looknfeel.conf at the
-- quattro migration (omarchy-desktop-on-cachyos ADR-0033). Loaded after
-- Omarchy's defaults, so every hl.config() call here overrides theirs.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    -- Uniform 8px of background everywhere: at the screen edge you see gaps_out,
    -- between two windows you see gaps_in twice. Keep gaps_out = 2 x gaps_in.
    -- Quattro's defaults are 10/5, which breaks the rule by a pixel and widens
    -- every gap. Load-bearing for extend_border_grab_area below, not cosmetic.
    gaps_out = 8,
    gaps_in = 4,

    -- Border-drag resize is Omarchy's default on every layout (omarchy-settings
    -- 4.5.0+). Austin wants it on scrolling and floating workspaces only, so it
    -- is switched per active workspace below. ADR-0025 is retired.

    -- Snap DRAGGED floating windows to screen edges and to each other. This is
    -- Drag snap, distinct from the Keyboard snap in ADR-0024 - it only applies
    -- while dragging with the mouse. Hyprland ships it disabled.
    --
    -- Both gaps set to 8 so a mouse-snapped window lands on the same margins
    -- float-snap produces, rather than Hyprland's default 10.
    snap = {
      enabled = true,
      window_gap = 8,
      monitor_gap = 8,
    },
  },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
--
-- Slightly rounded corners are a Tokyo Night choice, not a global one: every
-- other theme keeps Omarchy's default of 0. The theme is read from the
-- theme.name state file omarchy-theme-set writes; a load-time read is correct
-- because Hyprland reloads its config on every theme change, so this file
-- re-runs and re-decides with the new name.
do
  local paths = require("default.hypr.paths")
  local f = io.open(paths.state_home .. "/omarchy/current/theme.name", "r")
  if f then
    local theme = f:read("*l")
    f:close()
    if theme == "tokyo-night" then
      hl.config({ decoration = { rounding = 6 } })
    end
  end
end

-- The shadow block that used to live here is gone, and that is the intended
-- outcome rather than an omission. It disabled shadows because Omarchy set
-- range = 2, too short for the shadow to fade out - it rendered as a hard
-- near-black line around every window instead of a shadow. Quattro's
-- default/hypr/looknfeel.lua now ships `shadow { enabled = false }` itself, so
-- restating it would be a no-op pretending to be a decision.

-- The single-window zen aspect ratio lives here in spirit but NOT in this file:
-- ratio-toggle writes it to ~/.local/state/omarchy/toggles/hypr/ so it can be
-- switched off. Setting it here would make it permanent. See shokupan-plugins
-- ADR-0026.

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.

-- Border-drag resize (resize cursor included) only on scrolling and floating
-- workspaces. Hyprland has one global switch and no per-window or per-workspace
-- form, so it follows the active workspace, the way Omarchy's
-- workspace-modes.lua switches follow_mouse. Every mode change (saved modes,
-- the default, SUPER+L via hyprctl eval) goes through o.workspace_mode, so it
-- is wrapped to learn each workspace's mode; a floating workspace still reports
-- tiled_layout "dwindle", so the layout alone cannot tell. Like Omarchy, only
-- workspace ids >= 1 carry a mode.
do
  require("default.hypr.workspace-modes") -- defines o.workspace_mode
  local modes, default_mode, current = {}, nil, nil

  local function wants_border_resize()
    local workspace = hl.get_active_workspace()
    if not workspace then return false end
    local id = tonumber(workspace.id)
    local mode = (id and id >= 1) and (modes[tostring(id)] or default_mode) or nil
    if mode == "floating" then return true end
    return (mode or workspace.tiled_layout) == "scrolling"
  end

  local function update()
    local on = wants_border_resize()
    if on == current then return end
    current = on
    hl.config({ general = { resize_on_border = on } })
  end

  local workspace_mode = o.workspace_mode
  function o.workspace_mode(spec)
    workspace_mode(spec)
    if spec.default then
      default_mode = spec.default
    else
      modes[tostring(spec.workspace)] = spec.mode
    end
    update()
  end

  update()
  hl.on("workspace.active", update)
  hl.on("monitor.focused", update)
end

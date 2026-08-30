-- Personal keybinding overrides, loaded after Omarchy's defaults. Ported from
-- bindings.conf at the quattro migration (omarchy-desktop-on-cachyos ADR-0033).
-- Unbind a default before replacing it; hl.unbind of a key that is not bound is
-- an error.

-- The launcher chords are STOCK again (2026-08-17). ADR-0027's merged
-- apps+commands list is fully retired: upstream deleted the launcher plugin
-- shokupan.launcher forked, and the generated shokupan-cmd-*.desktop entries
-- went with it, so commands are reached through the Omarchy Menu now.
-- SUPER+SPACE (root menu) and SUPER+ALT+SPACE (apps) are left exactly as
-- upstream binds them — no unbind, no replacement.
--
-- The one deviation is ADDITIVE: bare ALT+SPACE, ours since before the merge,
-- also opens the apps menu. Additive is the whole point — it collides with no
-- upstream chord, so upstream can keep moving its own and this survives
-- untouched. That is why there is no hl.unbind here: unbind pairs with
-- replacement, and nothing is being replaced.
o.bind("ALT + SPACE", "Launch apps", "omarchy-menu toggle apps")

-- The Close ladder (ADR-0020) ------------------------------------------------
--
-- W closes the smallest unit, Q closes the whole thing - the axis macOS and
-- GNOME share. Four keys, one ladder:
--
--   SUPER+W        close the innermost pane/tab, else the window
--   CTRL+Q         close this window (compositor-level)
--   SUPER+Q        ask the app to quit itself (retypes CTRL+Q into it)
--   SUPER+SHIFT+Q  SIGKILL, last resort
--
-- New under quattro: all of W/Q first close an open Omarchy shell surface (the
-- Omarchy Menu, the Launcher, the emoji picker...). Those are layers, not
-- windows, so killactive never touched them and the close reflex died on them.
-- The compositor still sees binds while a quickshell layer holds keyboard
-- focus, which is what makes this reachable at all.

-- Omarchy shell surfaces are layers named omarchy-<plugin>. These are the
-- permanent ones; anything else with the prefix is a popup someone is looking
-- at and wants rid of. lock is excluded on purpose: SUPER+W must never
-- dismiss the lock screen (it cannot - but do not even ask).
local persistent_layers = {
  ["omarchy-bar"] = true,
  ["omarchy-background"] = true,
  ["omarchy-osd"] = true,
  ["omarchy-notifications"] = true,
  ["omarchy-lock"] = true,
}

-- Close the topmost transient Omarchy surface, if one is open. Returns true if
-- it did. The layer namespace omarchy-menu maps to the plugin id omarchy.menu;
-- `omarchy-shell shell hide` is the sanctioned way to dismiss one (it is what
-- `omarchy-menu close` runs).
local function close_omarchy_popup()
  for _, layer in ipairs(hl.get_layers()) do
    local ns = layer.namespace or ""
    if ns:sub(1, 8) == "omarchy-" and not persistent_layers[ns] then
      hl.exec_cmd("omarchy-shell -q shell hide " .. (ns:gsub("^omarchy%-", "omarchy.")))
      return true
    end
  end
  return false
end

-- Retype a shortcut into the focused window, the way upstream's Universal
-- copy/paste does it (default/hypr/bindings/clipboard.lua): send_key_state
-- down, then up 50ms later. Not hl.dsp.send_shortcut, which sometimes leaves
-- the synthetic key stuck and repeating - the .conf-era close-surface had that
-- bug and did not know it. https://github.com/hyprwm/Hyprland/discussions/14099
local function retype(mods, key)
  hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down", window = "activewindow" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up", window = "activewindow" }))
  end, { timeout = 50, type = "oneshot" })
end

-- The whitelist from ADR-0020, class -> that app's own close-smallest-unit
-- shortcut. Deliberately a whitelist: an unknown class falls through to
-- killactive (the old behaviour), whereas a wrong guess in a blacklist makes a
-- window silently unclosable. Patterns are Lua patterns, anchored.
--
-- ctrl+w inside a terminal is readline's delete-word, so Ghostty puts
-- close_surface on ctrl+shift+w - that one exception is why this is a table
-- and not a one-line bind. chrome%- is every omarchy-launch-webapp window:
-- chromium --app names the class after the host (chrome-chatgpt.com__-Profile_1),
-- not after the browser.
local close_shortcuts = {
  { pattern = "^com%.mitchellh%.ghostty$", mods = "CTRL SHIFT", key = "W" },
  { pattern = "^helium$", mods = "CTRL", key = "W" },
  { pattern = "^chrome%-", mods = "CTRL", key = "W" },
  { pattern = "^dev%.zed%.Zed$", mods = "CTRL", key = "W" },
  { pattern = "^org%.gnome%.", mods = "CTRL", key = "W" },
}

local function close_smallest()
  if close_omarchy_popup() then
    return
  end

  local window = hl.get_active_window()
  local class = window and window.class or ""

  for _, entry in ipairs(close_shortcuts) do
    if class:find(entry.pattern) then
      retype(entry.mods, entry.key)
      return
    end
  end

  hl.dispatch(hl.dsp.window.close())
end

-- Exposed so `hyprctl repl` can drive the LIVE handlers for verification -
-- nothing on this machine can synthesise a real key press (wtype's virtual
-- keyboard delivers nothing under this compositor, ydotool is not installed),
-- so measurement means calling the same closures the binds hold.
shokupan = shokupan or {}
shokupan.close_smallest = close_smallest
shokupan.close_omarchy_popup = close_omarchy_popup
shokupan.retype = retype

hl.unbind("SUPER + W")
o.bind("SUPER + W", "Close pane or window", close_smallest)

-- Compositor-level "close this window". TRADE-OFF, unchanged from the .conf
-- era: a compositor bind consumes the key before the app sees it, so no
-- application can receive CTRL+Q from the keyboard - in a terminal that means
-- CTRL+Q closes the terminal, shell and all. SUPER+Q is the escape hatch.
o.bind("CTRL + Q", "Close window", function()
  if not close_omarchy_popup() then
    hl.dispatch(hl.dsp.window.close())
  end
end)

-- macOS Cmd+Q: deliver an app-level quit by retyping CTRL+Q into the window.
o.bind("SUPER + Q", "Quit app", function()
  if not close_omarchy_popup() then
    retype("CTRL", "Q")
  end
end)

-- Last resort for windows that ignore both: SIGKILL. No save prompt.
o.bind("SUPER + SHIFT + Q", "Force kill window", hl.dsp.window.kill())

-- The arrow modifier scheme (ADR-0023) -----------------------------------------
--
-- The modifier says what you are acting on; count carries intensity, the letter
-- carries the axis:
--   SUPER             navigate - move focus, change nothing
--   SUPER+SHIFT/ALT   act on the window        (SHIFT swaps it, ALT resizes it)
--   SUPER+CTRL        leave the window         (switch workspace)
--   SUPER+CTRL+ALT    floating placement       (a different mode, ADR-0024)
--   SUPER+SHIFT+ALT   move a whole workspace to another monitor (Omarchy default)
--
-- macOS-Spaces-style workspace switching. Quattro binds SUPER+CTRL+left/right to
-- group focus cycling, the same collision the .conf era had: groups lost arrow
-- navigation then (ADR-0023) and nothing in use is lost now. e-1/e+1 hop between
-- workspaces that actually have windows, same as SUPER + mouse wheel.
hl.unbind("SUPER + CTRL + LEFT")
hl.unbind("SUPER + CTRL + RIGHT")
o.bind("SUPER + CTRL + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("SUPER + CTRL + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "e+1" }))

-- Shared plumbing for the Size ladder and floating placement --------------------

local paths = require("default.hypr.paths")

local function outer_gap()
  local gap = hl.get_config("general.gaps_out")
  if type(gap) == "table" then
    gap = gap.top or gap[1]
  end
  return tonumber(gap) or 8
end

-- The usable area (see CONTEXT.md): the logical monitor minus what the bar
-- reserved, minus the outer gap. Under quattro this is pure arithmetic - the Lua
-- API hands over the true scale (hyprctl rounds it; the API does not) and the
-- reserved edges by name, so the .conf era's probe-and-cache dance
-- (~/.local/state/omarchy/hypr-logical-size) is deleted, not ported.
local function usable_area(mon)
  local gap = outer_gap()
  local logical_w = math.floor(mon.width / mon.scale + 0.5)
  local logical_h = math.floor(mon.height / mon.scale + 0.5)
  local r = mon.reserved
  local x0 = mon.position.x + r.left + gap
  local y0 = mon.position.y + r.top + gap
  local uw = logical_w - r.left - r.right - 2 * gap
  local uh = logical_h - r.top - r.bottom - 2 * gap
  return x0, y0, uw, uh, gap
end

-- The Size ladder (ADR-0022) -----------------------------------------------------
--
-- Step the focused window through 1/3, 1/2, 2/3 of the usable area. The arrow says
-- where the SHARED EDGE goes, not whether the window grows: RIGHT moves the divider
-- right whichever window is focused - widening the left one, narrowing the right
-- one - which matches dragging that border with a mouse. Floating windows have no
-- shared edge, so there left/up shrink and right/down grow unconditionally.
--
-- Tiled and floating share the ladder and the keys but almost no machinery: a tiled
-- window has no size of its own - it holds a share of a split, so resizing it means
-- moving a boundary. Everything difficult below is the tiled case.

local LADDER = { 1 / 3, 1 / 2, 2 / 3 }
-- Wide enough to absorb gaps and rounding, narrow enough that adjacent rungs
-- (1/3 and 1/2 are 0.167 apart) never collide.
local EPS = 0.04
-- A landing within this many px of target is close enough to skip correcting.
local TOL_PX = 12
local MIN_PX = 40

-- Wrap/clamp at the ladder ends. Same flag file as the .conf era, so a future
-- Toggle Menu entry needs only to create/remove it (present = clamp). Wrap is
-- the default: it reaches every size from a single key. The window-resize
-- script and its --toggle-mode are deleted; this file is the whole interface.
local function clamp_mode()
  local flag = io.open(paths.state_home .. "/omarchy/toggles/window-resize-clamp", "r")
  if flag then
    flag:close()
    return true
  end
  return false
end

-- The next rung strictly in the direction of travel, rather than an advanced
-- index: a border dragged with the mouse leaves the split off-ladder entirely,
-- where an index has no meaning but "next rung below where I am" still does.
local function next_rung(current, usable, going_up)
  local fraction = current / usable
  local best
  if going_up then
    for _, rung in ipairs(LADDER) do
      if rung > fraction + EPS and (not best or rung < best) then
        best = rung
      end
    end
    if not best then
      best = clamp_mode() and LADDER[#LADDER] or LADDER[1]
    end
  else
    for _, rung in ipairs(LADDER) do
      if rung < fraction - EPS and (not best or rung > best) then
        best = rung
      end
    end
    if not best then
      best = clamp_mode() and LADDER[1] or LADDER[#LADDER]
    end
  end
  return best
end

local function window_resize(dir)
  local window = hl.get_active_window()
  if not window or not window.monitor then
    return
  end

  local axis = (dir == "left" or dir == "right") and "w" or "h"
  local going_up = (dir == "right" or dir == "down")

  local x0, y0, uw, uh = usable_area(window.monitor)

  -- FLOATING: the easy case. The window owns its geometry, so there is no split
  -- to move and no sign to work out - just tell it what size to be.
  -- resize without `relative` is exact and resizes about the window's own centre,
  -- which is wanted (stepping a size should not relocate the window), but growing
  -- near an edge can push part of it off screen - so clamp back inside the usable
  -- rect. Dispatches are synchronous in the config VM, so the re-read is honest.
  if window.floating then
    local rung
    if axis == "w" then
      rung = next_rung(window.size.x, uw, going_up)
      hl.dispatch(hl.dsp.window.resize({ x = math.floor(rung * uw), y = window.size.y }))
    else
      rung = next_rung(window.size.y, uh, going_up)
      hl.dispatch(hl.dsp.window.resize({ x = window.size.x, y = math.floor(rung * uh) }))
    end

    local now = hl.get_active_window()
    local nx, ny = now.at.x, now.at.y
    nx = math.min(nx, x0 + uw - now.size.x)
    ny = math.min(ny, y0 + uh - now.size.y)
    nx = math.max(nx, x0)
    ny = math.max(ny, y0)
    if nx ~= now.at.x or ny ~= now.at.y then
      hl.dispatch(hl.dsp.window.move({ x = nx, y = ny }))
    end
    return
  end

  -- TILED. One tiled window has no split to move - the single-window zen aspect
  -- ratio owns that case, and resizing would just fight it.
  local tiled = hl.get_windows({ workspace = window.workspace, floating = false, mapped = true })
  if #tiled < 2 then
    return
  end

  -- Which side of the split boundary we are on. Used twice: the ladder direction
  -- here, and the sign of the delta below. The test: a tiled window abuts our low
  -- edge (left for width, top for height) and overlaps us on the other axis, so
  -- we are the SECOND child. +8 absorbs the gap. Right for two windows, a 2x2
  -- grid and one window beside a stack; wrong only for a window in the middle of
  -- a nested run of columns - which the measure-and-flip loop below absorbs.
  local second_child = false
  for _, other in ipairs(tiled) do
    if other.address ~= window.address then
      if axis == "w" then
        if
          other.at.x + other.size.x <= window.at.x + 8
          and other.at.y < window.at.y + window.size.y
          and other.at.y + other.size.y > window.at.y
        then
          second_child = true
        end
      else
        if
          other.at.y + other.size.y <= window.at.y + 8
          and other.at.x < window.at.x + window.size.x
          and other.at.x + other.size.x > window.at.x
        then
          second_child = true
        end
      end
    end
  end

  -- The flip that makes the key describe the boundary: a second child's shared
  -- edge is its low edge, so its ladder runs the other way (ADR-0022).
  if second_child then
    going_up = not going_up
  end

  local current = (axis == "w") and window.size.x or window.size.y
  local usable = (axis == "w") and uw or uh
  local target = math.floor(next_rung(current, usable, going_up) * usable)
  if math.abs(target - current) <= TOL_PX then
    return
  end

  -- Hyprland's resize delta always grows the FIRST child of the split, whoever
  -- has focus (measured, ADR-0022) - a second child needs the sign inverted.
  local sign = second_child and -1 or 1

  local function measure()
    local w = hl.get_active_window()
    return (axis == "w") and w.size.x or w.size.y
  end

  -- Converge instead of computing one perfect delta, because two Hyprland quirks
  -- make a single dispatch unreliable: the delta is bounds-checked against the
  -- focused window's size but applied to the boundary inverted (so a second child
  -- can only grow by about its own size per call - large moves need chunking),
  -- and the sign guess is a heuristic. The same loop absorbs both: request the
  -- remainder, measure, flip once if the window travelled away from the target.
  -- In-process dispatches apply synchronously, so no settle delays are needed -
  -- the .conf era's 96ms per keypress is gone.
  local flipped = false
  for _ = 1, 5 do
    local now = measure()
    local remaining = target - now
    if math.abs(remaining) <= TOL_PX then
      break
    end

    local request = sign * remaining
    -- Keep the request inside what Hyprland will accept, or it is dropped.
    if now + request < MIN_PX then
      request = MIN_PX - now
    end
    if request == 0 then
      break
    end

    if axis == "w" then
      hl.dispatch(hl.dsp.window.resize({ x = request, y = 0, relative = true }))
    else
      hl.dispatch(hl.dsp.window.resize({ x = 0, y = request, relative = true }))
    end

    local after = measure()
    if after == now then
      -- Refused: either the sign is wrong, or the target is unreachable.
      if flipped then
        break
      end
      sign = -sign
      flipped = true
    elseif (after - now) * remaining < 0 then
      sign = -sign
      flipped = true
    end
  end
end

-- SUPER+ALT+arrows: two modifiers because it acts on the window, ALT because it
-- resizes rather than moves. Takes the chords from quattro's "move window into
-- group" - groups keep SUPER+G, SUPER+ALT+G, SUPER+ALT+TAB and the scroll bind,
-- so they remain reachable, just without arrows (ADR-0023).
hl.unbind("SUPER + ALT + LEFT")
hl.unbind("SUPER + ALT + RIGHT")
hl.unbind("SUPER + ALT + UP")
hl.unbind("SUPER + ALT + DOWN")
o.bind("SUPER + ALT + LEFT", "Resize left", function() window_resize("left") end)
o.bind("SUPER + ALT + RIGHT", "Resize right", function() window_resize("right") end)
o.bind("SUPER + ALT + UP", "Resize up", function() window_resize("up") end)
o.bind("SUPER + ALT + DOWN", "Resize down", function() window_resize("down") end)

-- Floating placement (ADR-0024) --------------------------------------------------
--
-- Keyboard snap: halves, fill, centre. A different MODE, not a different
-- intensity, so it gets its own modifier set - SUPER+CTRL+ALT was left free by
-- ADR-0023 for exactly this. All five no-op on tiled windows.
--
-- UP fills rather than taking the top half - the one asymmetry, and the more
-- useful action on this display. DOWN keeps the bottom half reachable.
-- Centre is not SUPER+C: that is Universal copy, and taking it would break copy
-- in every application.
local function float_snap(dir)
  local window = hl.get_active_window()
  if not window or not window.floating or not window.monitor then
    return
  end

  -- centerwindow needs no help: it keeps the size and already offsets by the
  -- reserved area rather than centring on the raw monitor.
  if dir == "center" then
    hl.dispatch(hl.dsp.window.center())
    return
  end

  local x0, y0, uw, uh, gap = usable_area(window.monitor)
  local half_w = math.floor((uw - gap) / 2)
  local half_h = math.floor((uh - gap) / 2)

  local geometry = {
    left = { x = x0, y = y0, w = half_w, h = uh },
    right = { x = x0 + half_w + gap, y = y0, w = half_w, h = uh },
    up = { x = x0, y = y0, w = uw, h = uh },
    down = { x = x0, y = y0 + half_h + gap, w = uw, h = half_h },
  }
  local g = geometry[dir]
  if not g then
    return
  end

  -- Resize first: exact resize is about the window's own centre, so the position
  -- it leaves behind is meaningless until the move lands.
  hl.dispatch(hl.dsp.window.resize({ x = g.w, y = g.h }))
  hl.dispatch(hl.dsp.window.move({ x = g.x, y = g.y }))
end

o.bind("SUPER + CTRL + ALT + LEFT", "Float left half", function() float_snap("left") end)
o.bind("SUPER + CTRL + ALT + RIGHT", "Float right half", function() float_snap("right") end)
o.bind("SUPER + CTRL + ALT + UP", "Float fill screen", function() float_snap("up") end)
o.bind("SUPER + CTRL + ALT + DOWN", "Float bottom half", function() float_snap("down") end)
o.bind("SUPER + CTRL + ALT + C", "Float centre", function() float_snap("center") end)

-- Exposed for repl-driven verification, like the close family above.
shokupan.window_resize = window_resize
shokupan.float_snap = float_snap
shokupan.usable_area = usable_area

-- ApexShot. Its own docs say "add these lines to your hyprland.conf", and until
-- the quattro port they lived in apexshot.conf sourced from exactly there — a
-- file the Lua config manager never reads, which silently killed all six
-- shortcuts. The .conf pair is retired; these are the same chords verbatim.
-- Kept through the 2026-08-15 stock-first audit at the user's word: apexshot is
-- back over the native capture flow until that flow improves (shokupan-plugins
-- ADR-0044).
--
-- Area capture is the one that toggles. Fired while the selector is already up
-- it takes that selector down instead of stacking a second one on the first,
-- which is no use to anybody. The selector is a layer-shell surface (namespace
-- apexshot-area-selector), not a window, so nothing in the close ladder at the
-- top of this file sees it and killactive cannot reach it either -- ending the
-- process that owns it is the way to close it.
--
-- The pattern has no spaces in it on purpose: it goes through a shell, and it
-- must not match /usr/bin/apexshot-capture --worker, the long-lived helper that
-- outlives every capture and that captures stop working without. Matching on
-- `area` is what separates the two, the worker's command line having no such
-- word in it.
local function apexshot_area()
  for _, layer in ipairs(hl.get_layers()) do
    if (layer.namespace or "") == "apexshot-area-selector" then
      hl.exec_cmd("pkill -f apexshot.capture.area")
      return
    end
  end

  hl.exec_cmd("/usr/bin/apexshot capture area")
end

-- Exposed for repl-driven verification, like the close family above: nothing
-- here can synthesise a real key press, so measuring means calling the closure
-- the bind holds.
shokupan.apexshot_area = apexshot_area

-- Both chords reach the same toggle. SUPER+SHIFT+4 is the macOS muscle memory;
-- SUPER+A is what a left click on the bar widget does (BarWidget.qml: left is
-- capture area, middle record, right full screen) and is the one hand can find
-- without looking. SUPER+A was the last bare-SUPER A chord free -- CTRL+A is
-- Audio, SHIFT+A ChatGPT, ALT+SHIFT+A Grok, CTRL+SHIFT+A Agent.
o.bind("SUPER + SHIFT + 4", "Screenshot area", apexshot_area)
o.bind("SUPER + A", "Screenshot area", apexshot_area)
o.bind("CTRL + ALT + X", "Screenshot crosshair", "/usr/bin/apexshot capture crosshair")
o.bind("SUPER + CTRL + ALT + S", "Screenshot screen", "/usr/bin/apexshot capture screen")
o.bind("CTRL + ALT + P", "Show last screenshot", "/usr/bin/apexshot show-last-preview")
o.bind("CTRL + ALT + R", "Record screen", "/usr/bin/apexshot record ui")
o.bind("CTRL + ALT + SHIFT + S", "Stop recording", "/usr/bin/apexshot record stop")

-- Workspace name (jankeesvw.workspace-name) ----------------------------------
--
-- The plugin's own docs bind this to a `hyper` chord this config does not
-- define, so it gets a real one. SUPER+R is free: every stock R chord carries
-- CTRL (SUPER+CTRL+R set reminder, +ALT show, +SHIFT clear), and CTRL+ALT+R is
-- ApexShot's recorder above. Bare SUPER+R is bound by nothing.
--
-- The panel is otherwise only reachable by clicking the workspace button you
-- are already standing on, which is a mouse trip to rename the thing you are
-- looking at. It opens as layer omarchy-keyboard-panel, so it is transient by
-- the close ladder's reckoning and SUPER+W dismisses it like any other popup.
o.bind("SUPER + R", "Name workspace", "omarchy-shell shell toggle jankeesvw.workspace-name")

-- Notification centre (jankeesvw.notification-center) ------------------------
--
-- Same shape as the workspace-name bind above: an omarchy-shell panel that is
-- otherwise only reachable by clicking its bar widget. SUPER+N is free -- the
-- stock N chords both carry a second modifier (SUPER+CTRL+N nightlight,
-- SUPER+SHIFT+N editor).
o.bind("SUPER + N", "Notification centre", "omarchy-shell shell toggle jankeesvw.notification-center")

-- Tailscale (omarchy.tailscale) ----------------------------------------------
--
-- Third of the same family. T is crowded -- SUPER+T floats a window,
-- SUPER+CTRL+T is Activity, SUPER+CTRL+ALT+T shows the time -- so this takes
-- SUPER+ALT+T, which nothing holds. ALT+SPACE already opens the apps menu, so
-- SUPER+ALT plus a letter reading as "open a thing" is the reading this
-- config already has.
o.bind("SUPER + ALT + T", "Tailscale", "omarchy-shell shell toggle omarchy.tailscale")

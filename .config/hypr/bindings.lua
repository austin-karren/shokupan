-- Personal keybinding overrides, loaded after Omarchy's defaults.
-- Ported from bindings.conf at the quattro migration (ADR-0033). Unbind a
-- default before replacing it; hl.unbind of a key that is not bound is an error.

-- ADR-0027: the merged app+command list is withdrawn under quattro, and the SPACE
-- chords adopt upstream's (SUPER+SPACE launcher, SUPER+ALT+SPACE Omarchy Menu).
-- This one addition keeps the older Launcher reflex alive: bare ALT+SPACE was the
-- app search since before the merge, and it should land on apps, not on nothing.
o.bind("ALT + SPACE", "Launch apps", "omarchy-shell shell toggle omarchy.launcher \"{}\"")

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

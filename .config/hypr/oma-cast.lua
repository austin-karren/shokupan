-- Written by `oma-cast setup hyprland`, then edited: rerunning setup overwrites it.
-- oma-cast takes Super+Space in place of the Omarchy menu (oma-cast opens that
-- menu itself), so Alt+Space goes back to Omarchy's dictation toggle.
hl.unbind("SUPER + SPACE")
o.bind("SUPER + SPACE", "oma-cast launcher", hl.dsp.global("oma-cast:toggle"))

-- Alt+Space goes to Hex through its own registered global shortcut, not
-- Omarchy's `omarchy-dictation toggle` bind: the global passes press AND
-- release, so Hex's Shortcut mode setting (hold vs tap) decides the behaviour.
-- Hex cannot grab the key itself on Wayland; without this bind it gets nothing.
-- Right Alt, Super+Ctrl+X and F9 still go through omarchy-dictation.
hl.unbind("ALT + SPACE")
o.bind("ALT + SPACE", "Dictation (Hex)", hl.dsp.global("anomaly.hex:dictation-ALT-space"))

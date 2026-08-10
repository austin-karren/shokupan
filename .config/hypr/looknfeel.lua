-- Change the default Omarchy look'n'feel.
-- Ported from looknfeel.conf at the quattro migration (ADR-0033). Loaded after
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

    -- Drag any window edge to resize it, with no modifier held (ADR-0025).
    -- Works on tiled windows too, where it moves the Parent split - the same
    -- thing the SUPER+ALT arrow Size ladder does, but continuously.
    -- Omarchy sets this to false explicitly; it is not merely unset.
    resize_on_border = true,

    -- border_size is 2, which is not a mouse target. This extends the draggable
    -- strip OUTWARD from the border into the gap.
    --
    -- 10 rather than Hyprland's default of 15, because the gaps here are small:
    -- 8px at the screen edge and 8px between windows (gaps_in twice). At 15 the
    -- strip reaches well past the gap and into the neighbouring window. If edge
    -- clicks still feel grabby, lower this - it is the only knob that matters,
    -- and do not compensate by raising border_size.
    extend_border_grab_area = 10,

    -- Swap the cursor to a resize arrow over a draggable edge, so the strip above
    -- is discoverable instead of invisible. Default is already true; stated
    -- because it is what makes resize_on_border usable rather than surprising.
    hover_icon_on_border = true,

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
hl.config({
  decoration = {
    -- Slightly round window corners (Omarchy's default is 0).
    rounding = 6,
  },
})

-- The shadow block that used to live here is gone, and that is the intended
-- outcome rather than an omission. It disabled shadows because Omarchy set
-- range = 2, too short for the shadow to fade out - it rendered as a hard
-- near-black line around every window instead of a shadow. Quattro's
-- default/hypr/looknfeel.lua now ships `shadow { enabled = false }` itself, so
-- restating it would be a no-op pretending to be a decision.

-- Special workspaces drop in from the TOP and retract back up into the bar,
-- instead of the default of rising from the bottom. Makes the calendar popup
-- (ADR-0006, special:calendar) read as emerging from the bar that launched it.
-- Ported from looknfeel.conf on request, 2026-08-10 — the earlier revision of
-- this file deferred it to ADR-0006, which kept GNOME Calendar, so the popup
-- exists and deserves its motion back.
--
-- THE DIRECTION ARGUMENT MEANS OPPOSITE THINGS ON THE TWO TREES (measured in
-- the .conf era by slowing the animation to 5s and tracking the bounding box):
-- `top` on In slides DOWN from the top; on Out it also slides DOWN. So the
-- retract-upward exit needs `bottom` on Out. Do not "fix" this to match.
--
-- These are global animation trees — no per-workspace override exists, so the
-- SUPER+S scratchpad moves the same way. Speed 3 (=300ms) and easeOutQuint
-- kept from Omarchy's default so the popup matches the desktop's motion.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slidevert top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slidevert bottom" })

-- The single-window zen aspect ratio lives here in spirit but NOT in this file:
-- ratio-toggle writes it to ~/.local/state/omarchy/toggles/hypr/ so it can be
-- switched off. Setting it here would make it permanent. See ADR-0026.

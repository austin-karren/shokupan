---
status: accepted
---

# The About window is sized to fastfetch, by measuring the terminal cell

Omarchy's About window opened too small to hold its own content: fastfetch needs
116 columns and 29 rows, and the stock floating size gave it 88. The fix is a
window rule pinning it to 1200×740 — derived by measuring the terminal cell at
this font size (~9.94 × 23.08 logical px), not by eyeballing until it fit. The
arithmetic and its quattro port live with the rule in
[`windows.lua`](../../.config/hypr/windows.lua); this records the two decisions
behind it.

**The rule matches a class shared by every floating Omarchy terminal**, because
`org.omarchy.bash` is all the About window offers — there is no About-specific
handle. That is the trade-off: any other floating Omarchy TUI inherits 1200×740.
Accepted, because those surfaces want roughly this much room anyway, and a
per-surface handle upstream does not exist to match on.

**The rule must match the tag as well as the class.** Omarchy's own floating rule
matches `tag:floating-window`, and Hyprland resolves competing rules in favour of
the more specific match regardless of source order — a class-only override
silently loses. This is the non-obvious half, and the reason a casual reader will
find `match:tag` in a rule that seems to need only a class.

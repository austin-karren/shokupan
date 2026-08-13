---
status: accepted
---

# Meet controls its own PiP popup, and the main window keeps its border

Omarchy's Google Meet rule (`default/hypr/apps/pip.lua`) matches
`{ tag = chromium-based-browser, title = "^Meet - .+" }` and forces
float/pin/600×338/`keep_aspect_ratio`/`border_size 0`. Two windows wear that
title during a call, and the rule damages both differently: the **main**
browser window (whose title becomes `Meet - <code> - Helium` while the call
tab is focused) loses its border and browser opacity, because dynamic effects
re-evaluate on title changes; the **popup** gets a horizontal 600×338 frame
that Meet's vertical document-PiP content never fills, rendering as wallpaper
bleed. The fix is two counter-rules in
[`windows.lua`](../../.config/hypr/windows.lua); the upstream file stays
untouched. This records the three decisions behind them.

**`initial_title` is the discriminator, because it is also the mechanism of
the bug.** Static effects (float/size/pin/move) match against `initial_title`,
dynamic ones against the live title — that split is exactly why only the main
window's decorations broke while only the popup got resized. The popup maps
already titled `Meet - ...`; the main window maps as `New Tab - Helium`. So
`initial_title = "negative:^Meet - .+"` selects the main window in any state
(a `float = false` match would stop working the moment the window is floated
by hand), and the plain `initial_title` match selects the popup.

**The popup's forced size is cancelled with an identity expression, not a
better constant.** Hyprland has no unset for a static effect, and picking our
own size would repeat upstream's mistake. But `size` expressions evaluate
against the window's own size, which Hyprland warps to the client's *desired*
geometry immediately before computing them (`DefaultFloatingAlgorithm.cpp`,
v0.56.2: "set this here so that expressions can use it") — so
`size = { "window_w", "window_h" }` resolves to whatever Meet asked for.
`keep_aspect_ratio` goes with it; upstream's float/pin/bottom-right move and
borderless-opaque look stay, because they are the useful part and `move`
computes from the real size.

**The main window's repair re-asserts values the config already defines.**
`border_size` is read back via `hl.get_config("general.border_size")` at load
rather than repeated (caveat: the no-gaps toggle changes the global *after*
`windows.lua` loads, so the rule lags it until the next reload); opacity
mirrors `browser.lua`'s `"1.0 0.97"`. Over-matching is harmless by
construction, since the effects are the default look.

The generic `Picture-in-Picture` rule at `pip.lua:2` is left alone — it keys
on a title only real PiP windows carry and causes neither symptom. The Meet
rule's title match is a candidate for an upstream report (`docs/upstream/`):
matching a live title that the main window also adopts mid-call is the root
defect.

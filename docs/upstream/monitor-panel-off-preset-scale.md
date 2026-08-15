# Draft issue: the monitor panel shows no scale when the current scale is off-preset

**Status: draft — not posted.** Per ADR-0044 rule 5: issue first, PR only
after upstream's temperature is known, nothing posted without an explicit go.

## Title

Monitor panel: display the current scale even when it matches no preset

## Body (draft)

The monitor panel's scale row offers the presets `["1", "1.25", "1.6", "2",
"3", "4"]` and highlights the active one via
`Model.matchingScaleIndex()`, which requires the monitor's current scale to
normalize (two-decimal string, after `cleanScale()` snapping) onto a
preset's effective value. A monitor running a valid but off-preset scale
matches nothing, so the row renders with no selection and no indication of
what the current scale actually is.

Concrete case: a 3840×2560 panel at `scale = 1.666667` (200/120 — a scale
Hyprland itself accepts and produces, e.g. by snapping a requested 1.8;
2304×1536 logical). It normalizes to `1.67`; the nearest preset `1.6` is
itself representable at this resolution and stays `1.6`. Nothing lights, and
the panel gives the user no way to see the 1.666667 without dropping to
`hyprctl monitors`.

Suggestion: when `activeScaleIndex()` returns -1, show the normalized current
scale — either as a transient extra chip in the row (selected, positioned by
value) or as a plain "current: 1.67" label beside the presets. Clicking a
preset would still move to it; the panel would just stop implying that no
scale is set.

## Rice context (not for the issue)

This is the deliberate 200/120 rung documented in `.config/hypr/monitors.lua`;
snapping the pin to 1.6 was rejected (a whole rung smaller UI), and cloning
the monitor panel for a cosmetic highlight was rejected (durability bar,
ADR-0044). ADR-0029's final addendum records the investigation. Until
upstream shows off-preset scales, the panel showing no selection on this
machine is expected behaviour.

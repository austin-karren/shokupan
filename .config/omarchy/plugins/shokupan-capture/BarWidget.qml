// The capture button on the bar — muscle-memory clone of the deprecated
// shokupan.apexshot button (same glyph, same slot, same three clicks) on
// omarchy's native capture tools. `omarchy-capture-screenshot` is the
// user-facing entry; a bare `omarchy-capture-screenrecording` toggles.
//
// BarIconButton, not a hand-sized WidgetButton: since r1744 upstream's icon
// widgets all ride BarIconButton, which owns the slot width and optical glyph
// centering — pinning fixedWidth here would fight the bar's own spacing
// (measured: the first cut did, and the right cluster went ragged).
//
// The glyph is an escaped codepoint, never a literal: a literal Nerd Font
// glyph silently becomes "" in editors that can't render it — the same
// editor-loss trap palette.lua and shokupan-launcher-cmds document. An empty
// glyph is worse than a missing button: the slot stays clickable while
// showing nothing.
//
// NOTE: third-party plugin (ADR-0044) — enabled by `shokupan.capture`
// appearing in bar.layout; a new/changed plugin dir needs omarchy-restart-shell
// to register.

import QtQuick
import qs.Ui

BarIconButton {
  id: root
  moduleName: "shokupan.capture"

  text: "\uf030"
  tooltipText: "Capture\n\nLeft: capture area\nMiddle: record screen\nRight: capture full screen"

  onPressed: function(b) {
    if (!root.bar) return
    if (b === Qt.RightButton) root.bar.run("omarchy-capture-screenshot fullscreen")
    else if (b === Qt.MiddleButton) root.bar.run("omarchy-capture-screenrecording")
    else root.bar.run("omarchy-capture-screenshot region")
  }
}

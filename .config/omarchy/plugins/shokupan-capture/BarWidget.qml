// The capture button on the bar — muscle-memory clone of the deprecated
// shokupan.apexshot button (same glyph, same slot, same three clicks) on
// omarchy's native capture tools. `omarchy-capture-screenshot` is the
// user-facing entry; a bare `omarchy-capture-screenrecording` toggles.
//
// Root is a plain Item with DECLARED bar/moduleName/settings, the shape the
// plugin loader injects into (same as the old apexshot widget). It cannot be
// upstream's BarWidget component: this file is itself named BarWidget.qml, so
// that type name resolves to this file and shadows qs.Ui's — the "cannot
// assign to non-existent property moduleName" load error that silently drops
// the widget from the bar.
//
// BarIconButton owns the slot width and optical glyph centering — no
// hand-pinned sizes (the first cut pinned fixedWidth and broke the right
// cluster's pitch). The glyph is an escaped codepoint, never a literal: a
// literal Nerd Font glyph silently becomes "" in editors that can't render
// it — the editor-loss trap palette.lua and the cmd-entry generator document.
//
// NOTE: third-party plugin (ADR-0044) — enabled by `shokupan.capture`
// appearing in bar.layout; a new/changed plugin dir needs omarchy-restart-shell
// to register.

import QtQuick
import qs.Ui

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  implicitWidth: button.implicitWidth
  implicitHeight: bar ? bar.barSize : 26

  BarIconButton {
    id: button
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: "\uf030"
    tooltipText: "Capture\n\nLeft: capture area\nMiddle: record screen\nRight: capture full screen"
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("omarchy-capture-screenshot fullscreen")
      else if (b === Qt.MiddleButton) root.bar.run("omarchy-capture-screenrecording")
      else root.bar.run("omarchy-capture-screenshot region")
    }
  }
}

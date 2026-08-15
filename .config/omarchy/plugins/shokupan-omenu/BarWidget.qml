// The Omarchy Menu button, wearing the rice's power glyph (U+F011, written
// escaped — raw glyphs have been lost to editors before) instead of
// upstream's omarchy logo. The Waybar rice used this glyph for the same button
// (custom/omarchy in the old config.jsonc), and quattro's plugins/menu/
// BarWidget.qml hardcodes its logo (U+E900 in the private "omarchy" icon
// font) with no setting to change it — so the swap is this module, not
// configuration.
//
// Interactions are upstream's own, verbatim: left opens the Omarchy Menu via
// shell IPC, right opens a terminal. Static, like the built-in. The two run
// commands are copied from upstream's BarWidget.qml — a WATCH coupling in
// packages/forks; if upstream renames the IPC route the button goes dead.
//
// Re-verified against r1744, 2026-08-15: the plain-Item widget contract
// (bar/moduleName/settings injected; implicitWidth/Height) is still the
// documented plugin shape (shell/plugins/bar/README.md), WidgetButton still
// exposes text/tooltipText/horizontalMargin and `signal pressed(int button)`,
// and bar.run/bar.barSize are unchanged.
//
// NOTE: third-party plugin (ADR-0044) — enabled by `shokupan.omenu`
// appearing in bar.layout; a new/changed plugin dir needs omarchy-restart-shell
// to register. Plugin hot-reload differs from the old bar/modules mechanism.

import QtQuick
import qs.Ui

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  implicitWidth: btn.implicitWidth
  implicitHeight: bar ? bar.barSize : 26

  WidgetButton {
    id: btn
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: "\uf011"
    tooltipText: "Omarchy Menu\n\nSuper + Alt + Space"
    horizontalMargin: 7.5
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}

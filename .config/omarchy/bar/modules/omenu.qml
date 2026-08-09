// The Omarchy Menu button, wearing the rice's power glyph (U+F011) instead of
// upstream's omarchy logo. The Waybar rice used this glyph for the same button
// (custom/omarchy in the old config.jsonc), and quattro's plugins/menu/
// BarWidget.qml hardcodes text: "" in its private icon font with no
// setting to change it — so the swap is this module, not configuration.
//
// Interactions are upstream's own, verbatim: left opens the Omarchy Menu via
// shell IPC, right opens a terminal. Static, like the built-in.
//
// NOTE: the shell registers new files in bar/modules/ only at startup. Editing
// this file hot-reloads; *adding* a module file needs omarchy-restart-shell.

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
    text: ""
    tooltipText: "Omarchy Menu\n\nSuper + Alt + Space"
    horizontalMargin: 7.5
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}

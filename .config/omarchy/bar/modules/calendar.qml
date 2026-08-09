// The calendar affordance, in the slot quattro's bar-config button vacated:
// immediately left of the clock, hidden until the centre of the bar is hovered.
//
// ADR-0006 stands — quattro's clock is a 66-line label with no popup and no
// month grid (verified by the menus agent, commit ef2cdab), and GNOME Calendar
// is the synced calendar with the actual meetings in it. This module restores
// the bar entry point that died with config.jsonc.
//
// It sits where the built-in bar-config control used to reveal. That control is
// suppressed by `centerAnchor: ""` in shell.json (it only renders when the
// anchor is omarchy.clock) and relocated to the barcfg module after the
// workspaces. Same reveal behaviour as ratio.qml, minus the active state: a
// calendar has no on/off, so it is hover-only.
//
// NOTE: the shell registers new files in bar/modules/ only at startup. Editing
// this file hot-reloads; *adding* a module file needs omarchy-restart-shell.

import QtQuick

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property bool revealed: bar && bar.centerSectionRevealHeld === true

  implicitWidth: revealed ? label.implicitWidth + 13 : 0
  implicitHeight: bar ? bar.barSize : 26

  visible: implicitWidth > 0
  Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  Text {
    id: label
    anchors.centerIn: parent
    text: "󰃭"
    color: root.bar ? root.bar.foreground : "white"
    font.family: root.bar ? root.bar.fontFamily : "monospace"
    font.pixelSize: 12
    opacity: root.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: true
    enabled: root.revealed
    onEntered: if (root.bar) root.bar.showTooltip(root, "Calendar\n\nClick to show or hide")
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function(mouse) {
      if (!root.bar) return
      if (mouse.button === Qt.RightButton)
        root.bar.run("env XDG_CURRENT_DESKTOP=Hyprland:GNOME gnome-control-center online-accounts")
      else
        root.bar.run("$HOME/.local/bin/calendar-toggle")
    }
  }
}

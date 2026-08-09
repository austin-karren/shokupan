// The single-window zen aspect-ratio toggle, as a bar module (ADR-0013, ADR-0026).
//
// A plain `type: "command"` entry would work, but it would always be visible.
// This is a `type: "qml"` module instead so it can join the centre section's
// hover-reveal group — the same behaviour the built-in indicators have, driven
// by the same `bar.centerSectionRevealHeld` property that
// plugins/bar/widgets/Indicators.qml binds to.
//
// Hover-only in BOTH states, like its neighbours in the hidden group: the
// toggle should not be seen unless the centre is hovered, on or off. State
// still shows while revealed — the glyph takes the theme's active colour when
// the constraint is on. (An earlier revision kept the glyph visible while on,
// mirroring the indicators; the deliberate choice is uniformity with the
// hover group instead.)
//
// State still comes from `ratio-toggle --status`, whose Waybar-style JSON
// contract survived that script's rewrite for the Hyprland port (it now reads
// the .lua flag's existence; see ADR-0026). The absolute path is deliberate:
// quickshell runs these through `bash -lc`, whose PATH does not include
// ~/.local/bin (see .config/uwsm/env, not currently installed).

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  property string glyph: ""
  property bool active: false
  property string tip: ""

  readonly property bool revealed: bar && bar.centerSectionRevealHeld === true

  implicitWidth: revealed ? label.implicitWidth + 13 : 0
  implicitHeight: bar ? bar.barSize : 26

  visible: implicitWidth > 0
  Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.glyph
    color: root.active && root.bar ? root.bar.urgent : (root.bar ? root.bar.foreground : "white")
    font.family: root.bar ? root.bar.fontFamily : "monospace"
    font.pixelSize: 12
    opacity: root.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.revealed
    onEntered: if (root.bar && root.tip) root.bar.showTooltip(root, root.tip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: {
      if (root.bar) root.bar.run("$HOME/.local/bin/ratio-toggle")
      statusTimer.restart()
      Qt.callLater(function() { statusProc.running = true })
    }
  }

  Process {
    id: statusProc
    command: ["bash", "-lc", "$HOME/.local/bin/ratio-toggle --status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.glyph = d.text || ""
          root.tip = d.tooltip || ""
          root.active = d.class === "active"
        } catch (e) {
          // Leave the last good reading in place rather than blanking the
          // module on one failed poll (the ADR-0031 principle).
        }
      }
    }
  }

  Timer {
    id: statusTimer
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: statusProc.running = true
  }
}

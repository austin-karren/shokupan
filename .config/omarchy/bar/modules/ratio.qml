// The single-window zen aspect-ratio toggle, as a bar module (ADR-0013, ADR-0026).
//
// A plain `type: "command"` entry would work, but it would always be visible.
// This is a `type: "qml"` module instead so it can join the centre section's
// hover-reveal group — the same behaviour the built-in indicators have, driven
// by the same `bar.centerSectionRevealHeld` property that
// plugins/bar/widgets/Indicators.qml binds to.
//
// It mirrors the indicators' semantics rather than hiding unconditionally:
// when the zen ratio is ON the glyph stays visible, and when it is OFF the
// module collapses until you hover the centre of the bar. That keeps ADR-0013's
// point — the toggle is out of a menu and legible at a glance when it is doing
// something — while keeping the bar quiet the rest of the time. To make it
// hover-only in both states, drop `|| active` from `revealed` below.
//
// State still comes from `ratio-toggle --status`, which emits Waybar-style JSON
// and is unchanged from the Waybar era. The absolute path is deliberate:
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

  readonly property bool revealed: active || (bar && bar.centerSectionRevealHeld === true)

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

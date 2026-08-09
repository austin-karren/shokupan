// The single-window zen aspect-ratio toggle, as a bar module (ADR-0013, ADR-0026).
//
// Lives in the centre's hover tier, immediately before the Claude-usage chip,
// and dresses exactly like the built-in indicators (Dnd, NightLight …): same
// WidgetButton base, same caption font size, same 5px margins, same muted
// treatment — full-opacity foreground glyph when the constraint is on, dimmed
// 0.45 when off, never the urgent colour. The one deliberate departure from
// BarIndicator is visibility: indicators show unprompted while active, this is
// hover-only in BOTH states (the user's call — nothing in the hidden group
// should be seen without hovering).
//
// State still comes from `ratio-toggle --status`, whose Waybar-style JSON
// contract survived that script's rewrite for the Hyprland port (it now reads
// the .lua flag's existence; see ADR-0026). The absolute path is deliberate:
// quickshell runs these through `bash -lc`, whose PATH does not include
// ~/.local/bin (see .config/uwsm/env, not currently installed).
//
// NOTE: the shell registers new files in bar/modules/ only at startup. Editing
// this file hot-reloads; *adding* a module file needs omarchy-restart-shell.

import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  property string glyph: ""
  property bool ratioOn: false
  property string tip: ""

  readonly property bool revealed: true // DIAG

  // Collapse entirely at rest so no hole sits between the indicators and the
  // usage chip. The WidgetButton below carries the indicators' own opacity
  // ladder (1 active / 0.45 dimmed / 0 concealed) — nothing custom.
  implicitWidth: revealed ? btn.implicitWidth : 0
  implicitHeight: bar ? bar.barSize : 26
  visible: implicitWidth > 0
  Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  WidgetButton {
    id: btn
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: root.glyph
    tooltipText: root.tip
    fontSize: Style.font.caption
    horizontalMargin: 5
    verticalPadding: 5
    useActiveColor: false
    dimmed: !root.ratioOn
    concealed: !root.revealed
    interactive: root.revealed

    onPressed: function(b) {
      if (!root.bar) return
      root.bar.run("$HOME/.local/bin/ratio-toggle")
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
          root.ratioOn = d.class === "active"
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

// The zen-ratio toggle's ACTIVE face (ADR-0013). This module and ratio.qml are
// one control rendered as a pair, mimicking the built-in indicators' block
// behaviour: when an indicator goes active it jumps to the left of the cluster
// and shows unprompted; inactive ones sit to the right and only hover-reveal.
// Indicators.qml loads its blocks solely from the package's indicators/
// directory — there is no user search path — so an outside module cannot
// interleave. The pair is the workaround: this file sits immediately BEFORE
// omarchy.indicators in the layout and renders only while the constraint is ON
// (full opacity, always visible, indicator dress); ratio.qml sits after the
// cluster and renders only while OFF and hovered (dimmed 0.45).
//
// Both faces probe `ratio-toggle --status` independently, but neither polls:
// a FileView watches the toggles directory (upstream's stay-awake idiom) and
// the probe runs on change, at startup, and immediately on click. The two
// faces cannot disagree for longer than one inotify delivery.
//
// NOTE: module FILES are read at startup only — both adding one and editing
// one need omarchy-restart-shell (measured 2026-08-10: edits do not hot-reload,
// despite what this note used to claim; only shell.json hot-reloads).

import QtQuick
import Quickshell
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

  readonly property string togglesDir: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr"

  implicitWidth: ratioOn ? btn.implicitWidth : 0
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
    concealed: !root.ratioOn
    interactive: root.ratioOn

    onPressed: function(b) {
      if (!root.bar) return
      root.bar.run("$HOME/.local/bin/ratio-toggle")
      // The watcher covers the flag change; probe immediately anyway so the
      // face swap tracks the click.
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
          // Keep the last good reading (the ADR-0031 principle).
        }
      }
    }
  }

  // See ratio.qml's note: fires on any toggles-directory change; the probe is
  // cheap and idempotent, so over-firing on sibling toggles is fine.
  FileView {
    path: root.togglesDir
    watchChanges: true
    printErrors: false
    onFileChanged: statusProc.running = true
  }

  Component.onCompleted: statusProc.running = true
}

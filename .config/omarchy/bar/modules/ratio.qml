// The single-window zen aspect-ratio toggle, as a bar module (ADR-0013, ADR-0026).
//
// This is the toggle's INACTIVE face; ratio-on.qml (see its header for the
// pair design) is the active one, placed before the indicators cluster the way
// active indicators jump left. This face renders only while the constraint is
// OFF and the centre is hovered, in full indicator dress: WidgetButton, caption
// font, 5px margins, dimmed 0.45, foreground colour.
//
// State still comes from `ratio-toggle --status`, whose Waybar-style JSON
// contract survived that script's rewrite for the Hyprland port (it now reads
// the .lua flag's existence; see ADR-0026). The absolute path is deliberate:
// quickshell runs these through `bash -lc`, whose PATH does not include
// ~/.local/bin (see .config/uwsm/env, not currently installed).
//
// EVENT-DRIVEN, NOT POLLED. This used to re-run --status on a 3-second timer,
// a leftover of the Waybar command-module contract — ~40 shell spawns a minute
// between the two faces, to learn whether one file exists. Now a FileView
// watches the toggles directory (upstream's own idiom — the idle service
// watches its stay-awake flag the same way) and the probe runs only when
// something in it actually changes, plus once at startup and once on click.
// SUPER+CTRL+BACKSPACE and the Toggle Menu are covered by the watcher, since
// both ultimately create or delete the flag file.
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
  readonly property bool revealed: bar && bar.centerSectionRevealHeld === true

  // Collapse entirely at rest so no hole sits between the indicators and the
  // usage chip. The WidgetButton below carries the indicators' own opacity
  // ladder (0.45 dimmed / 0 concealed) — nothing custom. When the constraint is
  // ON this face vanishes and ratio-on.qml takes over on the cluster's left.
  implicitWidth: (revealed && !ratioOn) ? btn.implicitWidth : 0
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
    dimmed: true
    concealed: !(root.revealed && !root.ratioOn)
    interactive: root.revealed && !root.ratioOn

    onPressed: function(b) {
      if (!root.bar) return
      root.bar.run("$HOME/.local/bin/ratio-toggle")
      // The watcher will fire when the flag lands, but probe immediately too
      // so the face swap tracks the click rather than the filesystem event.
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

  // Fires on any change in the toggles directory — the flag file being copied
  // in or deleted by ANY entry point (bar click, SUPER+CTRL+BACKSPACE, the
  // Toggle Menu all converge on omarchy-hyprland-toggle). The probe is cheap
  // and idempotent, so over-firing on sibling toggles is fine.
  FileView {
    path: root.togglesDir
    watchChanges: true
    printErrors: false
    onFileChanged: statusProc.running = true
  }

  Component.onCompleted: statusProc.running = true
}

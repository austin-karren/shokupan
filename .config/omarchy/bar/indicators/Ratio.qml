// The single-window zen aspect-ratio toggle, as a FIRST-CLASS indicator in
// our forked cluster (bar/modules/indicators.qml) — replacing the old
// ratio.qml/ratio-on.qml twin-module workaround (ADR-0013, ADR-0026).
// BarIndicator gives it the natives' exact dress and reveal behaviour: active
// jumps left at full opacity, inactive hover-reveals dimmed with the cluster's
// 140ms fade — no width animation of our own, so it appears in step with the
// others.
//
// EVENT-DRIVEN, NOT POLLED. A FileView watches the toggles directory
// (upstream's own idiom — the idle service watches its stay-awake flag the
// same way); the status probe runs only on directory change, at startup, and
// immediately on click. SUPER+CTRL+BACKSPACE and the Toggle Menu are covered,
// since every entry point converges on omarchy-hyprland-toggle creating or
// deleting the flag file.
//
// Glyph and tooltips stay single-sourced in `ratio-toggle --status` (its
// Waybar-style JSON contract; see the script's header for why the glyph is an
// escape, not a literal). The absolute path is deliberate: quickshell runs
// commands through `bash -lc`, whose PATH does not include ~/.local/bin.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  property string glyph: ""
  property string tip: ""
  property bool ratioOn: false

  readonly property string togglesDir: Quickshell.env("HOME") + "/.local/state/omarchy/toggles/hypr"

  active: ratioOn
  activeText: glyph
  inactiveText: glyph
  activeTooltipText: tip
  inactiveTooltipText: tip

  onPressed: function() {
    if (!root.bar) return
    root.bar.run("$HOME/.local/bin/ratio-toggle")
    // The watcher will fire when the flag lands, but probe immediately too so
    // the indicator tracks the click rather than the filesystem event.
    Qt.callLater(function() { statusProc.running = true })
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
          // Keep the last good reading rather than blanking the indicator on
          // one failed probe (the ADR-0031 principle).
        }
      }
    }
  }

  // Fires on any change in the toggles directory — cheap and idempotent, so
  // over-firing on sibling toggles is fine.
  FileView {
    path: root.togglesDir
    watchChanges: true
    printErrors: false
    onFileChanged: statusProc.running = true
  }

  Component.onCompleted: statusProc.running = true
}

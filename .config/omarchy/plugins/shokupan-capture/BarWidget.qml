// The capture button on the bar, wearing the native right-cluster convention.
//
// Every upstream panel widget in the right cluster pins the same box —
// `fixedWidth: Style.space(27)` (audio Panel.qml:531, network:715,
// bluetooth:477, monitor:346, power:257) — and the bar row itself has
// spacing: 0, so that shared box IS upstream's spacing mechanism.
//
// Muscle-memory clone of shokupan.apexshot (now deprecated): same glyph, same
// slot, same three clicks — but on omarchy's native capture tools instead of
// the apexshot binary. `omarchy-capture-screenshot` is the user-facing entry
// (`omarchy-capture-region` is its hidden geometry picker, not a screenshotter),
// and a bare `omarchy-capture-screenrecording` toggles: stops a running
// recording, otherwise starts one with the region picker.
//
// NOTE: third-party plugin (ADR-0044) — enabled by `shokupan.capture`
// appearing in bar.layout; a new/changed plugin dir needs omarchy-restart-shell
// to register.

import QtQuick
import qs.Commons
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
    text: ""
    tooltipText: "Capture\n\nLeft: capture area\nMiddle: record screen\nRight: capture full screen"
    fixedWidth: root.bar && root.bar.vertical ? -1 : Style.space(27)
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("omarchy-capture-screenshot fullscreen")
      else if (b === Qt.MiddleButton) root.bar.run("omarchy-capture-screenrecording")
      else root.bar.run("omarchy-capture-screenshot region")
    }
  }
}

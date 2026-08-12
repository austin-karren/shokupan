// ApexShot on the bar, wearing the native right-cluster convention.
//
// Every upstream panel widget in the right cluster pins the same box —
// `fixedWidth: Style.space(27)` (audio Panel.qml:531, network:715,
// bluetooth:477, monitor:346, power:257) — and the bar row itself has
// spacing: 0, so that shared box IS upstream's spacing mechanism. The old
// command-module version of this entry carried a hand-tuned horizontalMargin
// instead, which is why it needed spacer shims to sit evenly among natives.
// This module adopts the box and deletes the shims.
//
// Same three actions as the Waybar module and the command entry it replaces.
//
// NOTE: third-party plugin (ADR-0044) — enabled by `shokupan.apexshot`
// appearing in bar.layout; a new/changed plugin dir needs omarchy-restart-shell
// to register. Kept minimal: quattro's full release is expected to ship a
// screenshot tool that replaces this widget outright.

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
    text: ""
    tooltipText: "ApexShot\n\nLeft: capture area\nMiddle: record screen\nRight: capture full screen"
    fixedWidth: root.bar && root.bar.vertical ? -1 : Style.space(27)
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("apexshot capture screen")
      else if (b === Qt.MiddleButton) root.bar.run("apexshot record ui")
      else root.bar.run("apexshot capture area")
    }
  }
}

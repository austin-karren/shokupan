// The bar-config button, moved out of the centre to sit after the workspaces.
//
// Quattro puts this button to the left of the centred clock and reveals it when
// the centre of the bar is hovered. Wanted here instead: same hidden-until-hover
// behaviour, but positioned after the workspaces so it slides right on its own as
// workspaces are added.
//
// It cannot be the built-in one relocated. `BarConfigControl` is instantiated
// inside Bar.qml at `anchors.right: centerAnchorModule.left`, guarded by
// `centerAnchorModule.moduleName === "omarchy.clock"` — neither is reachable from
// shell.json, so moving it would mean owning the bar engine.
//
// It also cannot borrow the reveal signal. `bar.centerSectionRevealHeld` is set
// only by HoverHandlers on the *centre* module list; there is no left- or
// right-section equivalent, so hovering the left of the bar tells us nothing.
//
// So this module owns its own reveal: it always occupies a narrow strip, which is
// what makes it hoverable at all, and paints the glyph only while that strip is
// under the pointer. The strip reads as a gap in the bar rather than as a
// control, which is the intended resting state.
//
// The one behavioural difference from the built-in group worth knowing: the
// indicators and the stock config button reveal together when you hover anywhere
// in the centre, so the clock acts as a large, discoverable target. This one has
// only its own strip. Widen `hiddenWidth` if it turns out to be fiddly to hit.

import QtQuick

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property int hiddenWidth: 14
  readonly property bool revealed: hover.hovered

  implicitWidth: revealed ? label.implicitWidth + 13 : hiddenWidth
  implicitHeight: bar ? bar.barSize : 26

  Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  HoverHandler { id: hover }

  Text {
    id: label
    anchors.centerIn: parent
    text: ""
    color: root.bar ? root.bar.foreground : "white"
    font.family: root.bar ? root.bar.fontFamily : "monospace"
    font.pixelSize: 12
    opacity: root.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (root.bar) root.bar.run("omarchy-launch-bar-settings")
  }
}

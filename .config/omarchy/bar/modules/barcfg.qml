// The bar-config button, in the centre cluster to the left of the calendar.
//
// Quattro's built-in gear sits to the left of the clock — exactly where it
// crowded our calendar icon — and it cannot be relocated: `BarConfigControl`
// is instantiated inside Bar.qml at `anchors.right: centerAnchorModule.left`,
// guarded by `centerAnchorModule.moduleName === "omarchy.clock"` — neither is
// reachable from shell.json, so moving it would mean owning the bar engine.
// Hence this module; the built-in stays hidden because it only renders when
// the clock is the centre anchor, and our shell.json sets centerAnchor: "".
//
// An earlier revision lived in the LEFT section after the workspaces and
// owned its own reveal: a 14px always-present strip that painted the glyph
// only under its own pointer. Undiscoverable in practice — it read as
// removed. Now it lives in the centre list, so it participates in the centre
// hover group and reveals with the indicators and everything else via
// `bar.centerSectionRevealHeld` — one large, discoverable hover target, the
// way the stock gear behaved.
//
// No width animation of our own: width snaps and the WidgetButton's 140ms
// opacity fade carries the reveal, matching the native indicators (the same
// lesson as the ratio indicator's late-appearance fix).
//
// NOTE: module FILES are read at startup only — adding or editing one needs
// omarchy-restart-shell; only shell.json hot-reloads.

import QtQuick
import qs.Ui

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property bool revealed: bar
    && bar.centerSectionRevealHeld === true
    && bar.centerHoverRevealSuppressed !== true

  // Collapse entirely at rest so no hole sits in the centre cluster.
  implicitWidth: revealed ? btn.implicitWidth : 0
  implicitHeight: bar ? bar.barSize : 26
  visible: implicitWidth > 0

  // WidgetButton so the revealed gear carries the same hover highlight,
  // pressed state and tooltip chrome as every clickable built-in.
  WidgetButton {
    id: btn
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    // U+F013 gear as an escape, not a literal: a pasted private-use glyph was
    // lost in an edit once, and an empty text renders the button at opacity 0
    // with no error anywhere (same lesson as ratio-toggle's header).
    text: "\uf013"
    tooltipText: "Bar settings"
    dimmed: true
    concealed: !root.revealed
    interactive: root.revealed
    onPressed: function(b) {
      if (root.bar) root.bar.run("omarchy-launch-bar-settings")
    }
  }
}

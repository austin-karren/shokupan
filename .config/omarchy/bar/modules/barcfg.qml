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
// THE PANEL IS HOSTED HERE, NOT LAUNCHED. `omarchy-launch-bar-settings` is a
// dead end on this layout: it IPCs openBarConfig, whose openConfigPanel()
// skips every BarConfigControl with visible !== true — and with no clock
// anchor they are ALL invisible, so the shell answers "unknown" and nothing
// opens. So this module loads BarConfigPanel.qml itself (the same hosted-
// panel pattern as audio.qml) and anchors it to the gear; the click toggles
// it directly, no IPC involved.
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

  // Read by Bar.qml's openPanelIndicator: shift the underline from the
  // advance's centre to the INK's centre, computed from TextMetrics — the
  // same programmatic fix as audio.qml, no measured pixels. The FA gear's
  // ink sits slightly right of its advance centre, which reads as the
  // underline hanging left.
  readonly property real openIndicatorInlineOffset: {
    if (!bar || bar.vertical) return 0
    var r = metrics.tightBoundingRect
    if (!r || r.width <= 0) return 0
    return (r.x + r.width / 2) - metrics.advanceWidth / 2
  }

  TextMetrics {
    id: metrics
    text: btn.text
    font.family: btn.fontFamily
    font.pixelSize: btn.fontSize
  }

  // open/close/opened make this slot quack like a panel for findPanelWidget,
  // so `omarchy-shell shell toggle barcfg` works (same forwarding as audio.qml).
  readonly property bool panelOpen: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool opened: panelOpen
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  readonly property bool revealed: panelOpen || (bar
    && bar.centerSectionRevealHeld === true
    && bar.centerHoverRevealSuppressed !== true)

  // Collapse entirely at rest so no hole sits in the centre cluster. NO
  // `visible: implicitWidth > 0` here: QML visibility is effective down the
  // tree, so hiding root would also hide configControlProxy below — and
  // openConfigPanel() skips invisible controls, which would break
  // omarchy-launch-bar-settings exactly while the gear is at rest. Zero
  // width already removes it from layout and hit-testing.
  implicitWidth: revealed ? btn.implicitWidth : 0
  implicitHeight: bar ? bar.barSize : 26

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
    dimmed: !root.panelOpen
    concealed: !root.revealed
    interactive: root.revealed
    onPressed: function(b) {
      if (b === Qt.LeftButton && panelLoader.item) panelLoader.item.toggle()
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: "file:///usr/share/omarchy/shell/plugins/bar/BarConfigPanel.qml"
    // anchorItem FIRST, and bar guarded: at load time the host has not
    // injected `bar` yet, and assigning undefined to a QObject* property
    // throws — which would abort this handler before anchorItem is set,
    // leaving the panel unable to open (its open gate is anchorItem !== null).
    onLoaded: {
      item.anchorItem = btn
      if (root.bar) item.bar = root.bar
      // Re-point the panel's popout registration at this wrapper, so the
      // bar's `activePopout === slot.activeItem` identity check — which is
      // what shows the open-panel underline — holds under hosting (same as
      // audio.qml). The KeyboardPanel is a layer-shell WINDOW, not a visual
      // child, so it lives in `data` rather than `children`.
      for (var i = 0; i < item.data.length; i++) {
        var p = item.data[i]
        if (p && "owner" in p && "anchorItem" in p && "open" in p) {
          p.owner = root
          break
        }
      }
    }
  }

  // Registered into bar.configControls so openConfigPanel() — the target of
  // `omarchy-launch-bar-settings` — finds a control to open. It must be a
  // separate always-visible Item: openConfigPanel skips controls with
  // visible !== true, and root itself hides at rest.
  Item {
    id: configControlProxy
    visible: true
    width: 0
    height: 0
    function openPanel() { root.open() }
  }

  onBarChanged: {
    if (panelLoader.item) panelLoader.item.bar = root.bar
    if (bar && typeof bar.registerConfigControl === "function")
      bar.registerConfigControl(configControlProxy)
  }

  Component.onDestruction: {
    if (bar && typeof bar.unregisterConfigControl === "function")
      bar.unregisterConfigControl(configControlProxy)
  }
}

// The network widget, with ADR-0029's globe restored: wired shows 󰖟 (U+F059F,
// "am I on the internet"), not upstream's 󰈀 (U+F0200, a picture of the RJ45
// socket — the socket names the cable, not the question).
//
// A Hosted widget (CONTEXT.md): upstream's Panel.qml is loaded whole — popup,
// Wi-Fi scan, DNS picker, everything — and only the bar button's text binding
// is replaced. The glyph is computed by the package's Model.connectionIcon(),
// which takes no settings, so the override rebinds the one property where the
// glyph lands. Wi-Fi strength glyphs pass through untouched; only the ethernet
// glyph is mapped.
//
// The rebinding depends on Panel.qml keeping its bar button as a direct
// WidgetButton child binding `text: root.icon` (checked against
// plugins/panels/network/Panel.qml:710). If an upgrade restructures that, the
// map silently stops applying and the socket comes back — visible, not broken.
//
// NOTE: the shell registers new files in bar/modules/ only at startup. Editing
// this file hot-reloads; *adding* a module file needs omarchy-restart-shell.

import QtQuick

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  implicitWidth: inner.item ? inner.item.implicitWidth : 0
  implicitHeight: bar ? bar.barSize : 26

  // --- popout identity -------------------------------------------------------
  // The bar lights a module slot's open-panel underline when
  // `bar.activePopout === slot.activeItem` (Bar.qml, openPanelIndicator). In a
  // native slot the panel root IS the slot item; here the slot item is this
  // wrapper, while the hosted panel registers ITSELF as popout owner
  // (KeyboardPanel: coordinatorKey = owner || root). Identity never matches and
  // the underline never lights — the one parity gap the hosted-widget pattern
  // introduces. `activePopout` is a writable var, so the fix is to re-point
  // ownership at this wrapper the moment the inner panel claims it, and carry
  // the coordinator's close contract so popout-switching still works.
  readonly property bool opened: inner.item ? inner.item.opened === true : false

  function open() {
    var w = inner.item
    if (!w) return
    if (typeof w.openFromHotkey === "function") w.openFromHotkey()
    else if (typeof w.open === "function") w.open()
  }
  function close() {
    var w = inner.item
    if (w && typeof w.close === "function") w.close()
  }
  function closeForPopoutSwitch() {
    var w = inner.item
    if (w && typeof w.closeForPopoutSwitch === "function") w.closeForPopoutSwitch()
    else close()
  }

  Connections {
    target: root.bar
    ignoreUnknownSignals: true
    function onActivePopoutChanged() {
      if (root.bar && inner.item && root.bar.activePopout === inner.item)
        root.bar.activePopout = root
    }
  }

  Connections {
    target: inner.item
    ignoreUnknownSignals: true
    function onOpenedChanged() {
      // The inner panel's releasePopout(inner) no-ops once ownership moved to
      // the wrapper, so drop it here when the panel closes.
      if (root.bar && inner.item && inner.item.opened === false && root.bar.activePopout === root)
        root.bar.activePopout = null
    }
  }

  function mapped(icon) {
    return icon === "\u{F0200}" ? "\u{F059F}" : icon
  }

  function inject() {
    var w = inner.item
    if (!w) return
    if ("bar" in w) w.bar = root.bar
    if ("moduleName" in w) w.moduleName = "omarchy.network"
    if ("settings" in w) w.settings = root.settings || ({})
    // Find the bar button (the one direct WidgetButton child) and re-point its
    // glyph through the map. `icon` is readonly on the panel root, so the
    // rebinding happens where the glyph is consumed, not where it is computed.
    for (var i = 0; i < w.children.length; i++) {
      var c = w.children[i]
      if (c && "tooltipText" in c && "fixedWidth" in c && "text" in c) {
        c.text = Qt.binding(function() { return root.mapped(w.icon) })
        // Glyph-specific compensation, the same kind upstream applies to its
        // own widgets (monitor Panel.qml:348 uses rightExtraMargin: 4 too).
        // Upstream ships 5.5 here; measured on this bar that splits the globe's
        // neighbours 29/34 — 4 evens the pair. Not a rewrite of upstream's
        // convention, a one-glyph nudge inside it.
        c.rightExtraMargin = 4
        break
      }
    }
  }

  onBarChanged: inject()
  onSettingsChanged: inject()

  Loader {
    id: inner
    active: true
    anchors.verticalCenter: parent.verticalCenter
    source: "file:///usr/share/omarchy/shell/plugins/panels/network/Panel.qml"
    onLoaded: {
      root.inject()
      Qt.callLater(root.inject)

    }
  }
}

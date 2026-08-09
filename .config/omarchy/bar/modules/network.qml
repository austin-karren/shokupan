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
        // Upstream gives this button rightExtraMargin: 5.5, which lands as the
        // left margin of the audio module beside it. Measured on the live bar,
        // that put 34 physical px between the globe and the speaker cone while
        // the eye-corrected gap on the speaker's other side reads ~24; the eye
        // discounts the wave arcs even though their ink is dense. 2 instead of
        // 5.5 closes the left gap to ~28. Tuned by looking, not computed.
        c.rightExtraMargin = 2
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

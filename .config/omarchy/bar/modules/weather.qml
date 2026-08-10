// The weather widget, hosted so the open-panel underline can work at all.
//
// Stock weather can NEVER show the bar's underline: the indicator lights when
// `bar.activePopout === slot.activeItem`, but the popout that registers is
// the panel's KeyboardPanel (owner defaults to the Panel), while the slot's
// item is the BarWidget chip — the identity check can't hold. Same disease
// audio.qml already cured: host the upstream widget whole and re-point the
// panel's popout `owner` at this wrapper, which IS the slot's item.
//
// Upstream's BarWidget.qml is loaded verbatim from the package, so the chip,
// the panel, refresh, and click routing all track upstream updates. The
// wrapper only forwards the panel contract (open/close/opened, for
// findPanelWidget and `omarchy-shell shell toggle omarchy.weather`) and
// computes openIndicatorInlineOffset from TextMetrics — ink centre minus
// advance centre — so the underline sits on the glyph's ink whatever glyph
// the forecast picks (the audio/barcfg lesson; no measured pixels).
//
// NOTE: module FILES are read at startup only — adding or editing one needs
// omarchy-restart-shell; only shell.json hot-reloads.

import QtQuick
import qs.Commons

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  implicitWidth: inner.item ? inner.item.implicitWidth : 0
  implicitHeight: bar ? bar.barSize : 26

  readonly property bool opened: inner.item ? inner.item.opened === true : false
  function open() { if (inner.item && typeof inner.item.open === "function") inner.item.open() }
  function close() { if (inner.item && typeof inner.item.close === "function") inner.item.close() }

  readonly property real openIndicatorInlineOffset: {
    if (!bar || bar.vertical) return 0
    var r = metrics.tightBoundingRect
    if (!r || r.width <= 0) return 0
    return (r.x + r.width / 2) - metrics.advanceWidth / 2
  }

  TextMetrics {
    id: metrics
    // text / font are bound to the live chip in inject(), so the offset
    // re-computes whenever the forecast swaps the glyph.
  }

  function inject() {
    var w = inner.item
    if (!w) return
    if ("bar" in w) w.bar = root.bar
    if ("moduleName" in w) w.moduleName = "omarchy.weather"
    if ("settings" in w) w.settings = root.settings || ({})

    // Mirror the chip's glyph and font into the TextMetrics.
    for (var i = 0; i < w.children.length; i++) {
      var c = w.children[i]
      if (c && "tooltipText" in c && "fixedWidth" in c && "text" in c) {
        metrics.text = Qt.binding(function() { return c.text })
        metrics.font.family = Qt.binding(function() { return c.fontFamily })
        metrics.font.pixelSize = Qt.binding(function() { return c.fontSize })
        break
      }
    }

    // The KeyboardPanel is two levels down: the widget's Loader holds the
    // Panel, and the Panel's `data` holds the layer-shell window (windows are
    // not visual children). Re-point its owner at this wrapper.
    for (var j = 0; j < w.data.length; j++) {
      var l = w.data[j]
      if (!l || !("item" in l) || !l.item) continue
      var panel = l.item
      if (!panel.data) continue
      for (var k = 0; k < panel.data.length; k++) {
        var p = panel.data[k]
        if (p && "owner" in p && "anchorItem" in p && "open" in p) {
          p.owner = root
          return
        }
      }
    }
  }

  onBarChanged: inject()
  onSettingsChanged: inject()

  Loader {
    id: inner
    active: true
    anchors.verticalCenter: parent.verticalCenter
    source: "file:///usr/share/omarchy/shell/plugins/panels/weather/BarWidget.qml"
    onLoaded: {
      root.inject()
      Qt.callLater(root.inject)
    }
  }
}

// The audio widget, with the active-panel underline centred on the glyph's INK.
//
// Upstream's audio chip deliberately uses the old Waybar Font Awesome speaker
// glyphs (its own comment: the Material ones "render visually smaller"). Those
// wave glyphs draw their ink PAST their text advance — measured on this
// machine: at 10% volume (cone only) the icon sits centred; at 71% (cone +
// waves) the ink's left edge is identical and the waves extend 7px past
// centre, because Qt centres the advance and the ink overhangs it rightward.
// The bar centres the open-panel underline on the slot, so the underline sits
// visibly left of the icon whenever the volume is audible.
//
// Upstream's hook for this is `openIndicatorInlineOffset`, but its one user
// (the tailscale panel) sets a hand-measured constant. This wrapper computes
// the offset from TextMetrics instead — (ink centre − advance centre) of the
// glyph currently displayed — so it tracks volume changes, mute, headphones,
// font swaps, and goes to zero for symmetric glyphs. No measured pixels.
//
// A Hosted widget, same pattern as microphone.qml: upstream's Panel.qml is
// loaded whole. One extra wrinkle: the underline only shows while
// `bar.activePopout === slot.activeItem`, and hosting makes the slot's item
// this wrapper while the panel registers ITS root as the popout owner. The
// inner KeyboardPanel exposes `owner` for exactly this coordination, so the
// wrapper reassigns it to itself.
//
// NOTE: the shell registers new files in bar/modules/ only at startup. Editing
// this file hot-reloads; *adding* a module file needs omarchy-restart-shell.

import QtQuick
import qs.Commons

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  implicitWidth: inner.item ? inner.item.implicitWidth : 0
  implicitHeight: bar ? bar.barSize : 26

  // The bar resolves IPC (`omarchy-shell shell toggle omarchy.audio`, and the
  // microphone's middle-click) through findPanelWidget, which requires the
  // slot's item — this wrapper — to quack like a panel: open(), close(), and
  // an `opened` that is not undefined. Forward all three to the hosted panel.
  // The shell.json entry must also keep the id "omarchy.audio", because
  // findPanelWidget matches on slot.moduleName.
  readonly property bool opened: inner.item ? inner.item.opened === true : false
  function open() { if (inner.item && typeof inner.item.open === "function") inner.item.open() }
  function close() { if (inner.item && typeof inner.item.close === "function") inner.item.close() }

  // Read by Bar.qml's openPanelIndicator: shift the underline to the ink's
  // centre. Horizontal bars only — on a vertical bar the glyph box is square
  // and the indicator runs along the other axis.
  readonly property real openIndicatorInlineOffset: {
    if (!bar || bar.vertical) return 0
    var r = metrics.tightBoundingRect
    if (!r || r.width <= 0) return 0
    return (r.x + r.width / 2) - metrics.advanceWidth / 2
  }

  TextMetrics {
    id: metrics
    // text / font are bound to the live chip in inject(), so the offset
    // re-computes whenever the volume ladder swaps the glyph.
  }

  function inject() {
    var w = inner.item
    if (!w) return
    if ("bar" in w) w.bar = root.bar
    if ("moduleName" in w) w.moduleName = "omarchy.audio"
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

    // Re-point the panel's popout registration at this wrapper, so the bar's
    // `activePopout === slot.activeItem` identity check — which is what shows
    // the underline at all — still holds under hosting. The KeyboardPanel is a
    // layer-shell WINDOW, not a visual child, so it lives in `data` rather
    // than `children`.
    for (var j = 0; j < w.data.length; j++) {
      var p = w.data[j]
      if (p && "owner" in p && "anchorItem" in p && "open" in p) {
        p.owner = root
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
    source: "file:///usr/share/omarchy/shell/plugins/panels/audio/Panel.qml"
    onLoaded: {
      root.inject()
      Qt.callLater(root.inject)
    }
  }
}

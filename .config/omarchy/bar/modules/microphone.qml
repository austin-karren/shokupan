// The microphone widget, wearing the right-cluster box convention.
//
// Restored at the user's word after being skipped as "duplicates the Dictation
// indicator" — it does not: the indicator reports dictation state, this one
// reads and *acts on* the input device (click = mute, scroll = source volume,
// middle = audio panel). One subsystem, two directions, so it sits next to
// omarchy.audio per ADR-0029's question rule.
//
// A Hosted widget: upstream's Microphone.qml is loaded whole, and the one
// change is the box. Upstream gives this widget a glyph-derived width (its
// WidgetButton sets no fixedWidth) while every other icon in this cluster pins
// `fixedWidth: Style.space(27)`; the wrapper pins it too, so the mic sits on
// the same pitch as its neighbours instead of being the one narrow box.
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

  function inject() {
    var w = inner.item
    if (!w) return
    if ("bar" in w) w.bar = root.bar
    if ("moduleName" in w) w.moduleName = "omarchy.microphone"
    if ("settings" in w) w.settings = root.settings || ({})
    for (var i = 0; i < w.children.length; i++) {
      var c = w.children[i]
      if (c && "tooltipText" in c && "fixedWidth" in c && "text" in c) {
        c.fixedWidth = Qt.binding(function() {
          return root.bar && root.bar.vertical ? -1 : Style.space(27)
        })
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
    source: "file:///usr/share/omarchy/shell/plugins/bar/widgets/Microphone.qml"
    onLoaded: {
      root.inject()
      Qt.callLater(root.inject)
    }
  }
}

// Claude usage, in the centre's hover-reveal group instead of always on show.
//
// `omarchy.model-usage` has no visibility setting, and the hover group only
// loads indicators from inside the Omarchy package, so neither route gets this
// behaviour by configuration. But `Ui/BarWidget.qml` is a plain `Item` carrying
// three injected properties (`bar`, `moduleName`, `settings`) and nothing tied
// to the bar's slot machinery — so the upstream widget can simply be *hosted*:
// this module loads the real `Widget.qml` by absolute path, injects the same
// three properties the host would, and owns only the question of whether it is
// visible. The popup, the provider tabs and the sync logic stay upstream's.
//
// Hover-only in both states, unlike ratio.qml: usage is never urgent enough to
// earn permanent space, which was the point of moving it off the right cluster.
//
// NOTE: the shell registers new files in bar/modules/ only at startup. Editing
// this file hot-reloads; *adding* a module file needs omarchy-restart-shell.

import QtQuick

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property bool revealed: bar && bar.centerSectionRevealHeld === true

  implicitWidth: revealed && inner.item ? inner.item.implicitWidth : 0
  implicitHeight: bar ? bar.barSize : 26
  clip: true

  Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

  function inject() {
    var w = inner.item
    if (!w) return
    if ("bar" in w) w.bar = root.bar
    // The canonical id, not this module's id: the host registry uses moduleName
    // to route the widget's own IPC and settings lookups.
    if ("moduleName" in w) w.moduleName = "omarchy.model-usage"
    if ("settings" in w) w.settings = root.settings || ({})
  }

  onBarChanged: inject()
  onSettingsChanged: inject()

  Loader {
    id: inner
    active: true
    anchors.verticalCenter: parent.verticalCenter
    source: "file:///usr/share/omarchy/shell/plugins/model-usage/Widget.qml"
    opacity: root.revealed ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    onLoaded: {
      root.inject()
      Qt.callLater(root.inject)
    }
  }
}

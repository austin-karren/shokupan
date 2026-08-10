// The calendar affordance, static and immediately left of the clock (ADR-0006,
// ADR-0029's bracket around the date).
//
// ADR-0006 stands — quattro's clock is a 66-line label with no popup and no
// month grid (verified by the menus agent, commit ef2cdab), and GNOME Calendar
// is the synced calendar with the actual meetings in it. This module restores
// the bar entry point that died with config.jsonc.
//
// It sits where the built-in bar-config control used to reveal. That control is
// suppressed by `centerAnchor: ""` in shell.json (it only renders when the
// anchor is omarchy.clock) and relocated to the barcfg module after the
// workspaces — restoring the anchor would put a second gear back in this very
// slot on clock hover, which is why it stays suppressed.
//
// STATIC, deliberately: unlike the rest of the rice's centre modules this one
// does not hover-reveal. The calendar is the left half of the ADR-0029 bracket
// around the date, and a bracket that is usually missing is not a bracket.
//
// WidgetButton, not a raw Text+MouseArea, so it carries the same hover
// highlight, pressed state and shared tooltip every clickable built-in has.
//
// NOTE: the shell registers new files in bar/modules/ only at startup. Editing
// this file hot-reloads; *adding* a module file needs omarchy-restart-shell.

import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  // The calendar's "panel" is a Hyprland special workspace, not a shell
  // popout, so the bar's own open-panel indicator can never light up for it
  // (that one keys on bar.activePopout identity). This tracks the workspace
  // instead: Hyprland emits `activespecial` with the workspace name when a
  // special shows and an empty name when it hides — event-driven, no polling.
  property bool calendarShown: false

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "activespecial") return
      root.calendarShown = event.data.indexOf("special:calendar") === 0
    }
  }

  implicitWidth: btn.implicitWidth
  implicitHeight: bar ? bar.barSize : 26

  // A twin of Bar.qml's openPanelIndicator (same tokens: accent, 0.9, 55%
  // width, space(2) bar and inset), drawn here because the real one is
  // unreachable for a non-popout panel. Centred on the glyph's INK via
  // TextMetrics, not the advance — the audio/barcfg lesson.
  TextMetrics {
    id: metrics
    text: btn.text
    font.family: btn.fontFamily
    font.pixelSize: btn.fontSize
  }

  Rectangle {
    readonly property int inset: Style.space(2)
    readonly property real inkOffset: {
      var r = metrics.tightBoundingRect
      if (!r || r.width <= 0) return 0
      return (r.x + r.width / 2) - metrics.advanceWidth / 2
    }

    visible: opacity > 0 && bar && !bar.vertical
    opacity: root.calendarShown ? 0.9 : 0
    color: Color.accent
    radius: Math.min(width, height) / 2
    width: Math.max(Style.space(10), Math.round(parent.width * 0.55))
    height: Style.space(2)
    x: (parent.width - width) / 2 + inkOffset
    y: bar && bar.position === "bottom" ? inset : parent.height - height - inset
    z: 50

    Behavior on opacity {
      NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
  }

  WidgetButton {
    id: btn
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: "󰃭"
    tooltipText: "Calendar\n\nClick to show or hide"
    // 4, not the default 8.5: the raw-Text revision measured the bracket even
    // at 23/23 with 4 logical px of padding a side, and this keeps that ink
    // geometry (glyph + 8 total) while gaining the button chrome.
    horizontalMargin: 4
    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton)
        root.bar.run("env XDG_CURRENT_DESKTOP=Hyprland:GNOME gnome-control-center online-accounts")
      else
        root.bar.run("$HOME/.local/bin/calendar-toggle")
    }
  }
}

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
import qs.Ui

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  implicitWidth: btn.implicitWidth
  implicitHeight: bar ? bar.barSize : 26

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

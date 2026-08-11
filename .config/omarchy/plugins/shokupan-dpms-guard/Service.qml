import QtQuick
import Quickshell
import Quickshell.Io

// The BenQ over USB-C drops its DP link when it deep-sleeps after a DPMS off.
// The kernel reports that as a connector hotplug, and Hyprland sometimes
// answers by re-enabling the output — leaving the lock screen lit for hours
// (Hyprland discussions #13654/#11356). Crucially the self-wake happens inside
// aquamarine's DRM layer and emits NO Hyprland event (verified with socat on
// socket2), so this cannot be event-driven: while the session is locked we
// poll, and if the display is awake with the user still idle, we blank again.
//
// Safety: the idle check means real input (a returning user typing their
// password) marks the monitor active and the guard stands down; the lock
// gate means the timer doesn't run at all during normal desktop use.
Item {
  id: root

  // Injected by the plugin loader, same as first-party services.
  property var shell: null

  readonly property var lockService: shell && shell.serviceFor ? shell.serviceFor("omarchy.lock") : null
  readonly property bool lockActive: lockService ? lockService.locked === true : false

  function logEvent(message) {
    console.log("shokupan dpms-guard " + new Date().toISOString() + " " + message)
  }

  onLockActiveChanged: logEvent(lockActive ? "lock engaged: polling" : "unlocked: standing down")

  Timer {
    interval: 30000
    repeat: true
    running: root.lockActive
    onTriggered: if (!checkProcess.running) checkProcess.running = true
  }

  // One decision, one subprocess: awake display + idle user -> re-assert.
  Process {
    id: checkProcess
    command: ["bash", "-lc",
      "export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t ${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr 2>/dev/null | head -1); "
      + "idle=$(omarchy-shell idle status 2>/dev/null | jq -r .idle); "
      + "dpms=$(hyprctl monitors -j 2>/dev/null | jq -r '[.[].dpmsStatus] | any'); "
      + "if [[ $idle == true && $dpms == true ]]; then echo reassert; else echo ok; fi"]
    stdout: StdioCollector {
      onStreamFinished: root.handleCheck(text.trim())
    }
  }

  function handleCheck(result) {
    if (result !== "reassert") return
    if (root.lockService && root.lockService.authenticating) return
    logEvent("display awake while locked+idle: re-asserting off")
    if (!blankProcess.running) blankProcess.running = true
  }

  Process {
    id: blankProcess
    command: ["bash", "-lc",
      "export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t ${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr 2>/dev/null | head -1); "
      + "omarchy-brightness-display off"]
  }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Blanks every display until the next key or mouse button press. A black
// overlay catches that press (and hides the cursor) while screen-power.sh
// switches the displays off, by DPMS or a user screen-off hook.
Scope {
  id: root

  property bool active: false
  // Ignore the tail of the click or Enter that chose the action.
  property bool armed: false

  readonly property string script: decodeURIComponent(
    Qt.resolvedUrl("screen-power.sh").toString().replace(/^file:\/\//, ""))

  function run(mode) {
    Quickshell.execDetached(["/usr/bin/timeout", "--signal=TERM", "--kill-after=2s", "30s",
                             "/usr/bin/bash", script, mode])
  }

  function start() {
    if (active) return
    armed = false
    active = true
    armTimer.restart()
  }

  function wake() {
    if (!active || !armed) return
    active = false
    armed = false
    run("on")
  }

  // The session locked underneath us: the lock screen owns the displays now,
  // so drop the overlay without waking anything.
  function release() {
    active = false
    armed = false
    run("release")
  }

  Timer {
    id: armTimer
    interval: 700
    onTriggered: {
      if (!root.active) return
      root.armed = true
      root.run("off")
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.armed
    onTriggered: if (!lockCheck.running) lockCheck.running = true
  }

  Process {
    id: lockCheck
    command: ["/usr/bin/omarchy-hyprland-session-locked"]
    onExited: function(exitCode) {
      if (exitCode === 0 && root.active) root.release()
    }
  }

  Variants {
    model: root.active ? Quickshell.screens : []

    PanelWindow {
      required property var modelData

      screen: modelData
      anchors { top: true; left: true; bottom: true; right: true }
      color: "black"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.namespace: "simple-power-menu-screen-off"

      Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          event.accepted = true
          root.wake()
        }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        onPressed: root.wake()
      }
    }
  }
}

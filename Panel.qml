pragma ComponentBehavior: Bound

import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui

Ui.Panel {
  id: root

  moduleName: "io.github.jordanneenan.simple-power-menu"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property int selectedIndex: 0
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property var actions: [
    { label: "Lock", command: "omarchy system lock", danger: false },
    { label: "Restart", command: "omarchy system reboot", danger: false },
    { label: "Shut down", command: "omarchy system shutdown", danger: true }
  ]

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function activate(index) {
    var action = actions[index]
    if (!action || !bar) return
    close()
    bar.run(action.command)
  }

  onOpenedChanged: if (opened) {
    selectedIndex = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Ui.KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Commons.Style.space(176))
    contentHeight: fittedContentHeight(actionColumn.implicitHeight)

    Ui.PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy !== 0)
          root.selectedIndex = (root.selectedIndex + dy + root.actions.length) % root.actions.length
      }
      onActivateRequested: root.activate(root.selectedIndex)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: actionColumn
        width: parent.width
        spacing: Commons.Style.space(3)

        Repeater {
          model: root.actions

          delegate: Rectangle {
            id: actionRow
            required property var modelData
            required property int index

            width: actionColumn.width
            height: Commons.Style.space(34)
            radius: Math.max(2, Commons.Style.cornerRadius)
            color: rowMouse.containsMouse || root.selectedIndex === index
              ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
              : "transparent"

            Text {
              anchors.left: parent.left
              anchors.leftMargin: Commons.Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: actionRow.modelData.label
              color: actionRow.modelData.danger ? root.urgent : root.foreground
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.bodySmall
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.selectedIndex = actionRow.index
              onClicked: root.activate(actionRow.index)
            }
          }
        }
      }
    }
  }
}

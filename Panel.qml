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
  property string menuMode: "actions"
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property var actions: [
    { id: "lock", label: "Lock", command: "omarchy system lock", danger: false },
    { id: "screensaver", label: "Screensaver", command: "omarchy launch screensaver", danger: false },
    { id: "sleep", label: "Sleep", command: "systemctl suspend", danger: false },
    { id: "restart", label: "Restart", command: "omarchy system reboot", danger: false },
    { id: "shutdown", label: "Shut down", command: "omarchy system shutdown", danger: true }
  ]
  readonly property var defaultActionIds: ["lock", "screensaver", "sleep", "restart", "shutdown"]
  property var visibleActionIds: actionIdsFromSettings(settings)
  readonly property var visibleActions: actions.filter(function(action) {
    return root.visibleActionIds.indexOf(action.id) !== -1
  })
  readonly property var menuActions: menuMode === "settings" ? actions : visibleActions

  function actionIdsFromSettings(source) {
    var configured = source ? source.visibleActions : undefined
    if (!Array.isArray(configured)) return defaultActionIds.slice()

    var result = []
    for (var i = 0; i < actions.length; i++) {
      if (configured.indexOf(actions[i].id) !== -1) result.push(actions[i].id)
    }
    return result
  }

  function actionIsVisible(id) {
    return visibleActionIds.indexOf(id) !== -1
  }

  function persistVisibleActions() {
    if (!bar) return
    var json = JSON.stringify(visibleActionIds)
    bar.run("omarchy bar set " + moduleName + " visibleActions " + Commons.Util.shellQuote(json) + " --json")
  }

  function toggleActionVisibility(id) {
    var next = visibleActionIds.slice()
    var index = next.indexOf(id)
    if (index === -1) next.push(id)
    else next.splice(index, 1)

    // Normalize against the fixed allowlist and keep the display order stable.
    visibleActionIds = actionIdsFromSettings({ visibleActions: next })
    persistVisibleActions()
  }

  function open() {
    menuMode = "actions"
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggleActions() {
    if (opened && menuMode === "actions") close()
    else {
      menuMode = "actions"
      root.controller.show()
    }
  }

  function toggleSettings() {
    if (opened && menuMode === "settings") close()
    else {
      menuMode = "settings"
      root.controller.show()
    }
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function activate(index) {
    var action = menuActions[index]
    if (!action) return
    if (menuMode === "settings") {
      toggleActionVisibility(action.id)
      return
    }
    if (!bar) return
    close()
    bar.run(action.command)
  }

  onSettingsChanged: visibleActionIds = actionIdsFromSettings(settings)
  onMenuActionsChanged: {
    if (menuActions.length === 0) selectedIndex = 0
    else selectedIndex = Math.min(selectedIndex, menuActions.length - 1)
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
        if (dy !== 0 && root.menuActions.length > 0)
          root.selectedIndex = (root.selectedIndex + dy + root.menuActions.length) % root.menuActions.length
      }
      onActivateRequested: if (root.menuActions.length > 0) root.activate(root.selectedIndex)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: actionColumn
        width: parent.width
        spacing: Commons.Style.space(3)

        Text {
          width: actionColumn.width
          height: visible ? Commons.Style.space(34) : 0
          visible: root.menuMode === "actions" && root.menuActions.length === 0
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: "No actions selected"
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.7)
          font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
          font.pixelSize: Commons.Style.font.bodySmall
        }

        Repeater {
          model: root.menuActions

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
              id: actionLabel
              anchors.left: parent.left
              anchors.leftMargin: root.menuMode === "settings"
                ? Commons.Style.space(36)
                : Commons.Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: actionRow.modelData.label
              color: actionRow.modelData.danger ? root.urgent : root.foreground
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.bodySmall
            }

            Rectangle {
              id: checkBox
              visible: root.menuMode === "settings"
              width: Commons.Style.space(14)
              height: width
              anchors.left: parent.left
              anchors.leftMargin: Commons.Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              radius: Math.max(2, Commons.Style.cornerRadius / 2)
              color: root.actionIsVisible(actionRow.modelData.id)
                ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
                : "transparent"
              border.width: 1
              border.color: root.actionIsVisible(actionRow.modelData.id)
                ? root.foreground
                : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)

              Text {
                anchors.centerIn: parent
                text: "✓"
                visible: root.actionIsVisible(actionRow.modelData.id)
                color: root.foreground
                font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
                font.pixelSize: Commons.Style.space(10)
              }
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

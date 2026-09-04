pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
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
    { id: "screensaver", label: "Screensaver", argv: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=2s", "30s", "/usr/bin/omarchy", "launch", "screensaver"], danger: false },
    { id: "sleep", label: "Sleep", argv: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=2s", "30s", "/usr/bin/systemctl", "suspend"], danger: false },
    { id: "lock", label: "Lock", argv: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=2s", "30s", "/usr/bin/omarchy", "system", "lock"], danger: false },
    { id: "restart", label: "Restart", argv: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=2s", "30s", "/usr/bin/omarchy", "system", "reboot"], danger: false },
    { id: "shutdown", label: "Shut down", argv: ["/usr/bin/timeout", "--signal=TERM", "--kill-after=2s", "30s", "/usr/bin/omarchy", "system", "shutdown"], danger: true }
  ]
  readonly property var defaultActionIds: ["screensaver", "sleep", "lock", "restart", "shutdown"]
  property var visibleActionIds: visibleActionIdsFromSettings(settings)
  property var actionOrderIds: actionOrderIdsFromSettings(settings)
  readonly property var orderedActions: actionOrderIds.map(function(id) {
    return root.actionForId(id)
  }).filter(function(action) { return action !== null })
  readonly property var visibleActions: orderedActions.filter(function(action) {
    return root.visibleActionIds.indexOf(action.id) !== -1
  })
  readonly property var menuActions: menuMode === "settings" ? orderedActions : visibleActions

  function actionForId(id) {
    for (var i = 0; i < actions.length; i++) {
      if (actions[i].id === id) return actions[i]
    }
    return null
  }

  function visibleActionIdsFromSettings(source) {
    var configured = source ? source.visibleActions : undefined
    if (!Array.isArray(configured)) return defaultActionIds.slice()

    var result = []
    for (var i = 0; i < configured.length; i++) {
      var id = String(configured[i] || "")
      if (actionForId(id) && result.indexOf(id) === -1) result.push(id)
    }
    return result
  }

  function actionOrderIdsFromSettings(source) {
    var configured = source ? source.actionOrder : undefined
    var result = []

    if (Array.isArray(configured)) {
      for (var i = 0; i < configured.length; i++) {
        var id = String(configured[i] || "")
        if (actionForId(id) && result.indexOf(id) === -1) result.push(id)
      }
    }

    // Append new or omitted actions in the default order so every fixed action
    // always remains recoverable through the right-click editor.
    for (var j = 0; j < defaultActionIds.length; j++) {
      if (result.indexOf(defaultActionIds[j]) === -1) result.push(defaultActionIds[j])
    }
    return result
  }

  function actionIsVisible(id) {
    return visibleActionIds.indexOf(id) !== -1
  }

  function persistPreferences() {
    if (!bar || !bar.shell || typeof bar.shell.mutateShellConfig !== "function") return
    var visibleSnapshot = visibleActionIds.slice()
    var orderSnapshot = actionOrderIds.slice()

    // The shell owns shell.json and serializes this mutation. Keeping the
    // update in-process also avoids passing user preferences through a shell.
    bar.shell.mutateShellConfig(function(config) {
      if (!Commons.Util.isPlainObject(config.bar)
          || !Commons.Util.isPlainObject(config.bar.layout)) return

      var sections = ["left", "center", "right"]
      for (var i = 0; i < sections.length; i++) {
        var entries = config.bar.layout[sections[i]]
        if (!Array.isArray(entries)) continue

        for (var j = 0; j < entries.length; j++) {
          var entry = entries[j]
          var id = Commons.Util.isPlainObject(entry) ? String(entry.id || "") : String(entry || "")
          if (id !== root.moduleName) continue

          if (!Commons.Util.isPlainObject(entry)) {
            entry = { id: root.moduleName }
            entries[j] = entry
          }
          entry.visibleActions = visibleSnapshot
          entry.actionOrder = orderSnapshot
          return
        }
      }
    })
  }

  function toggleActionVisibility(id) {
    var next = visibleActionIds.slice()
    var index = next.indexOf(id)
    if (index === -1) next.push(id)
    else next.splice(index, 1)

    visibleActionIds = visibleActionIdsFromSettings({ visibleActions: next })
    persistPreferences()
  }

  function moveAction(fromIndex, toIndex) {
    if (fromIndex < 0 || fromIndex >= actionOrderIds.length) return
    toIndex = Math.max(0, Math.min(actionOrderIds.length - 1, toIndex))
    if (fromIndex === toIndex) return

    var next = actionOrderIds.slice()
    var moved = next.splice(fromIndex, 1)[0]
    next.splice(toIndex, 0, moved)
    actionOrderIds = next
    selectedIndex = toIndex
    persistPreferences()
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
    close()
    // GNU timeout (without --foreground) owns a dedicated process group. It
    // bounds the complete action tree with TERM, followed by KILL after 2s.
    // Every executable and argument is a fixed absolute argv entry: no shell,
    // PATH lookup, or user-controlled command material is involved.
    Quickshell.execDetached(action.argv)
  }

  onSettingsChanged: {
    visibleActionIds = visibleActionIdsFromSettings(settings)
    actionOrderIds = actionOrderIdsFromSettings(settings)
  }
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
            property real dragOffsetY: 0
            property bool dragging: false

            width: actionColumn.width
            height: Commons.Style.space(34)
            z: dragging ? 10 : 0
            radius: Math.max(2, Commons.Style.cornerRadius)
            color: rowMouse.containsMouse || root.selectedIndex === index
              ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
              : "transparent"

            Text {
              id: actionLabel
              anchors.left: root.menuMode === "settings" ? dragGrip.right : parent.left
              anchors.leftMargin: root.menuMode === "settings"
                ? Commons.Style.space(8)
                : Commons.Style.space(10)
              anchors.right: root.menuMode === "settings" ? checkBox.left : parent.right
              anchors.rightMargin: root.menuMode === "settings"
                ? Commons.Style.space(10)
                : Commons.Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              text: actionRow.modelData.label
              color: actionRow.modelData.danger ? root.urgent : root.foreground
              font.family: root.bar ? root.bar.fontFamily : Commons.Style.font.family
              font.pixelSize: Commons.Style.font.bodySmall
            }

            transform: Translate { y: actionRow.dragOffsetY }

            Rectangle {
              id: checkBox
              visible: root.menuMode === "settings"
              width: Commons.Style.space(14)
              height: width
              anchors.right: parent.right
              anchors.rightMargin: Commons.Style.space(10)
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

            Item {
              id: dragGrip
              visible: root.menuMode === "settings"
              width: Commons.Style.space(18)
              height: parent.height
              anchors.left: parent.left
              anchors.leftMargin: Commons.Style.space(5)
              anchors.verticalCenter: parent.verticalCenter

              Column {
                anchors.centerIn: parent
                spacing: Commons.Style.space(2)

                Repeater {
                  model: 3
                  Rectangle {
                    required property int index
                    width: Commons.Style.space(10)
                    height: Math.max(1, Commons.Style.space(1))
                    radius: height / 2
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.65)
                  }
                }
              }

              MouseArea {
                id: gripMouse
                anchors.fill: parent
                cursorShape: Qt.SizeVerCursor
                property real pressColumnY: 0

                onPressed: function(mouse) {
                  pressColumnY = mapToItem(actionColumn, mouse.x, mouse.y).y
                  actionRow.dragging = true
                  root.selectedIndex = actionRow.index
                }
                onPositionChanged: function(mouse) {
                  if (!pressed) return
                  var point = mapToItem(actionColumn, mouse.x, mouse.y)
                  actionRow.dragOffsetY = point.y - pressColumnY
                }
                onReleased: function(mouse) {
                  var stride = actionRow.height + actionColumn.spacing
                  var target = Math.round(actionRow.index + actionRow.dragOffsetY / stride)
                  var source = actionRow.index
                  actionRow.dragging = false
                  actionRow.dragOffsetY = 0
                  root.moveAction(source, target)
                }
                onCanceled: {
                  actionRow.dragging = false
                  actionRow.dragOffsetY = 0
                }
              }
            }
          }
        }
      }
    }
  }
}

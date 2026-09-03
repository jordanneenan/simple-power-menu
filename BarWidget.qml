pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons as Commons
import qs.Ui as Ui

Ui.BarWidget {
  id: root

  moduleName: "io.github.jordanneenan.simple-power-menu"

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property var powerPanel: panelLoader.item
  readonly property bool opened: powerPanel
    ? powerPanel.opened === true
    : false
  readonly property bool popoutSwitchClosing: powerPanel
    ? powerPanel.popoutSwitchClosing === true
    : false

  function open() {
    if (powerPanel) powerPanel.open()
  }

  function close() {
    if (powerPanel) powerPanel.close()
  }

  function toggle() {
    if (powerPanel) powerPanel.toggleActions()
  }

  function toggleSettings() {
    if (powerPanel) powerPanel.toggleSettings()
  }

  function closeForPopoutSwitch() {
    if (powerPanel) powerPanel.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.settings = root.settings
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  Ui.BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Commons.Style.space(18)
    opticalSize: Commons.Style.space(12)
    tooltipText: "Power · right-click to customize"
    iconComponent: Component {
      Canvas {
        id: powerGlyph
        antialiasing: true

        onPaint: {
          var ctx = getContext("2d")
          var scale = Math.min(width, height) / 12
          ctx.reset()
          ctx.strokeStyle = root.foreground
          ctx.lineWidth = 1.05 * scale
          ctx.lineCap = "round"

          ctx.beginPath()
          ctx.moveTo(width / 2, 1.0 * scale)
          ctx.lineTo(width / 2, 5.25 * scale)
          ctx.stroke()

          ctx.beginPath()
          ctx.arc(width / 2, 6.2 * scale, 4.25 * scale, -Math.PI / 4, 5 * Math.PI / 4, false)
          ctx.stroke()
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
          target: root
          function onForegroundChanged() { powerGlyph.requestPaint() }
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton) root.toggleSettings()
    }
  }
}

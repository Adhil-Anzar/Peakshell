import QtQuick
import QtQuick.Controls
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell
import "root:/"
import "root:/components"

Rectangle {
    required property SystemTrayItem modelData;
    required property var panelHost;
    property var trayMenuPanel: null

    function toggleMenu() {
        if (!modelData.hasMenu || !trayMenuPanel)
            return

        if (trayMenuPanel.visible && trayMenuPanel.targetMenu === modelData.menu) {
            trayMenuPanel.closeMenu()
        } else {
            const p = panelHost ? mapToItem(panelHost.contentItem, 0, 0) : mapToGlobal(0, 0)
            const offsetX = panelHost ? (p.x + Theme.barHorizontalPad) : p.x
            trayMenuPanel.openMenu(modelData.menu, modelData.title || modelData.id, offsetX)
        }
    }

    height: parent.height
    width: this.height
    radius: Theme.cornerRadius
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
    Behavior on color {
        CAnim {}
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: { hoverDebounce.isDelaying = true; hoverDebounce.restart() }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (modelData.hasMenu && trayMenuPanel) {
                    toggleMenu()
                } else if (modelData.hasMenu) {
                    const p = panelHost ? mapToItem(panelHost.contentItem, 0, 0) : Qt.point(0, 0)
                    modelData.display(panelHost, Math.max(0, p.x), Theme.barHeight + Theme.barHorizontalPad / 2)
                }
                return;
            }

            if (mouse.button === Qt.LeftButton) {
                if (modelData.onlyMenu && modelData.hasMenu && trayMenuPanel) {
                    toggleMenu()
                    return
                }
                modelData.activate()
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                modelData.secondaryActivate()
            }
        }
        onWheel: (wheel) => {
            modelData.scroll(wheel.angleDelta.x, wheel.angleDelta.y)
        }
    }
    Timer {
        id: hoverDebounce
        property bool isDelaying: false
        interval: Theme.hoverDuration
        repeat: false
        running: !mouseArea.containsMouse && isDelaying

        onTriggered: isDelaying = false;
    }
    IconImage {
        anchors.centerIn: parent
        implicitSize: Theme.iconFontSize
        source: modelData.icon
    }
}

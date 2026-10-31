import QtQuick
import "root:/"
import "root:/components"
import Quickshell
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import "../panels"

Rectangle {
    id: root
    required property var panelHost
    visible: Theme.moduleSysTray && SystemTray.items.values.length !== 0
    width: container.width + Theme.cornerRadius
    color: Theme.bgColor
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight

    Row {
        id: container
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.height
        spacing: 4
        Repeater {
            model: SystemTray.items
            delegate: TrayItem {
                panelHost: root.panelHost
                menuLoader: trayMenuLoader
            }
        }
    }

    LazyLoader {
        id: trayMenuLoader
        loading: true
        TrayMenuPanel {
            panelHost: root.panelHost
        }
    }
}

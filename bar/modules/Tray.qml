import QtQuick
import "root:/"
import Quickshell
import QtQuick.Layouts
import Quickshell.Services.SystemTray

Rectangle {
    id: root
    required property var panelHost
    visible: SystemTray.items.values.length !== 0
    width: container.width + Theme.cornerRadius
    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutExpo
        }
    }
    color: Theme.bgColor
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.height
        id: container
        spacing: 4
        Repeater {
            height: root.height
            width: this.height
            model: SystemTray.items
            delegate: TrayItem { panelHost: root.panelHost }
        }
    }
}

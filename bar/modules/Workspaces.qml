import QtQuick
import Quickshell
import Quickshell.Hyprland
import QtQuick.Effects
import "root:/"

Rectangle {
    id: root
    width: container.width + Theme.cornerLargeRadius
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
        spacing: 0
        Repeater {
            height: root.height
            width: this.height
            model: Hyprland.workspaces.values

            delegate: Rectangle {
                required property int index;
                required property HyprlandWorkspace modelData;
                height: parent.height
                width: this.height
                radius: Theme.cornerRadius
                color: mouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
                Behavior on color {
                    ColorAnimation { duration: Theme.animationDuration }
                }
                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onEntered: { hoverDebounce.isDelaying = true; hoverDebounce.restart() }
                    onClicked: modelData.activate()
                }
                Timer {
                    id: hoverDebounce
                    property bool isDelaying: false
                    interval: Theme.hoverDuration
                    repeat: false
                    running: !mouseArea.containsMouse && isDelaying

                    onTriggered: isDelaying = false;
                }
                Rectangle {
                    property bool isSelected: {
                        if (!modelData) return false
                        if (modelData.focused) return true
                        return false
                    }

                    anchors.centerIn: parent
                    height: 16
                    width: this.height
                    color: isSelected ? Theme.mutedFgColor : Qt.darker(Theme.mutedAccent, 2)
                    radius: width / 2
                    scale: isSelected ? 1.1 : 0.75
                    Behavior on color {
                        ColorAnimation { duration: Theme.animationDuration }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.animationDuration
                            easing.type: Easing.OutExpo
                        }
                    }
                }
            }
        }
    }
}

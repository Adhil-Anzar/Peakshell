import QtQuick
import Quickshell
import Quickshell.Hyprland
import QtQuick.Effects
import "root:/"
import "root:/components"
import "root:/bar/panels"
import "root:/services"

Rectangle {
    id: root
    function togglePanel() {
        previewPanel.togglePreview(Hypr.activeWsId, Hypr.activeWsId);
    }
    property var panelHost

    width: container.width + Theme.cornerLargeRadius
    Behavior on width {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    color: Theme.bgColor
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight

    WorkspacePreviewPanel {
        id: previewPanel
        panelHost: root.panelHost
    }

    // Right-click on workspaces container opens preview for focused workspace
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: {
            const focusedWs = Hyprland.focusedWorkspace;
            if (focusedWs) {
                previewPanel.togglePreview(focusedWs.id, focusedWs.name);
            } else if (Hypr.activeWsId) {
                previewPanel.togglePreview(Hypr.activeWsId, "Workspace " + Hypr.activeWsId);
            }
        }
    }

    Row {
        id: container
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.height
        spacing: 0

        Repeater {
            height: root.height
            width: this.height
            model: Hyprland.workspaces.values

            delegate: Rectangle {
                id: wsItem
                required property int index
                required property HyprlandWorkspace modelData

                readonly property bool isFocused: modelData ? modelData.focused : false
                readonly property bool isOccupied: modelData ? (Hypr.toplevelsForWs(modelData.id).length > 0) : false
                readonly property bool isUrgent: modelData ? (Hypr.urgentWorkspaceIds[modelData.id] === true) : false

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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onEntered: {
                        hoverDebounce.isDelaying = true;
                        hoverDebounce.restart();
                    }
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            previewPanel.togglePreview(modelData.id, modelData.name);
                        } else {
                            modelData.activate();
                        }
                    }
                }

                Timer {
                    id: hoverDebounce
                    property bool isDelaying: false
                    interval: Theme.hoverDuration
                    repeat: false
                    running: !mouseArea.containsMouse && isDelaying
                    onTriggered: isDelaying = false
                }

                Rectangle {
                    id: wsDot
                    anchors.centerIn: parent
                    height: 12
                    width: this.height
                    radius: width / 2

                    color: {
                        if (wsItem.isUrgent)
                            return Theme.urgentPulseColor;
                        if (wsItem.isFocused)
                            return Theme.mutedFgColor;
                        if (wsItem.isOccupied)
                            return Theme.mutedAccent;
                        return Qt.darker(Theme.mutedAccent, 2);
                    }

                    scale: {
                        if (wsItem.isFocused)
                            return 1.15;
                        if (wsItem.isOccupied)
                            return 0.9;
                        return 0.65;
                    }

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on scale {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }

                    // Purple pulse when the workspace has an urgent window
                    SequentialAnimation {
                        id: urgentPulse
                        running: wsItem.isUrgent
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                        Anim {
                            target: wsDot
                            property: "scale"
                            from: wsItem.isFocused ? 1.15 : 0.9
                            to: 1.45
                            type: Anim.DefaultSpatial
                        }
                        Anim {
                            target: wsDot
                            property: "scale"
                            from: 1.45
                            to: wsItem.isFocused ? 1.15 : 0.9
                            type: Anim.DefaultSpatial
                        }
                    }
                }
            }
        }
    }
}

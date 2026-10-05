import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"
import "root:/services"
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: main

    required property var panelHost
    screen: Hypr.focusedMonitor

    property int currentIndex: 0
    property string activePressed: ""

    readonly property string username: Quickshell.env("USER") || "User"
    readonly property var powerActions: Power.powerActions

    function executeAction(index) {
        if (index < 0 || index >= powerActions.length)
            return;
        Power.executeAction(index);
        close();
    }

    function open() {
        panelHost.hideAllPanelExcept("shutdown");
        currentIndex = 0;
        main.visible = true;
        if (panelHost.toggledPanels)
            panelHost.toggledPanels["shutdown"] = main;
    }

    function close() {
        main.visible = false;
        if (panelHost.toggledPanels)
            panelHost.toggledPanels["shutdown"] = false;
    }

    function togglePanel() {
        if (main.visible)
            close();
        else
            open();
    }

    visible: false
    focusable: true
    color: Qt.darker(Theme.bgColor)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    // Dismiss on background click
    MouseArea {
        anchors.fill: parent
        onClicked: main.close()
    }

    FocusScope {
        id: keyScope
        anchors.fill: parent
        focus: main.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                main.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                main.currentIndex = (main.currentIndex - 1 + main.powerActions.length) % main.powerActions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                main.currentIndex = (main.currentIndex + 1) % main.powerActions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab) {
                main.currentIndex = (main.currentIndex - 1 + main.powerActions.length) % main.powerActions.length;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                main.executeAction(main.currentIndex);
                event.accepted = true;
            }
        }

        // Center card with user avatar, name, and power buttons
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 28

            // User Profile Section

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 80
                    height: 80
                    radius: 40
                    color: Theme.mutedBgColor
                    border.color: "#44FFFFFF"
                    border.width: Theme.generalThickness

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 44
                        source: Quickshell.iconPath("user-identity")
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: main.username
                    font.pointSize: Theme.labelFontSize * 1.5
                    font.family: Theme.labelFontFamily
                    font.bold: true
                    color: Theme.fgColor
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Select a power action or press Esc to cancel"
                    font.pointSize: Theme.labelFontSize * 0.95
                    font.family: Theme.labelFontFamily
                    color: Theme.mutedFgColor
                }
            }

            // Power Buttons Row
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Repeater {
                    model: main.powerActions

                    delegate: ColumnLayout {
                        id: btnDelegate
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: main.currentIndex === btnDelegate.index
                        spacing: 8

                        Rectangle {
                            id: circleBtn
                            Layout.alignment: Qt.AlignHCenter
                            width: 68
                            height: 68
                            radius: 34

                            // Pure monochrome states: no accent color!
                            color: {
                                if (btnMouse.pressed)
                                    return "#66FFFFFF";
                                if (btnDelegate.isSelected)
                                    return "#33FFFFFF";
                                if (btnMouse.containsMouse)
                                    return "#26FFFFFF";
                                return Theme.mutedBgColor;
                            }

                            border.color: {
                                if (btnDelegate.isSelected)
                                    return "#AAFFFFFF";
                                if (btnMouse.containsMouse)
                                    return "#66FFFFFF";
                                return "#33FFFFFF";
                            }
                            border.width: btnDelegate.isSelected ? 2 : 1

                            scale: btnMouse.pressed ? 0.94 : (btnDelegate.isSelected ? 1.08 : (btnMouse.containsMouse ? 1.04 : 1.0))

                            Behavior on color {
                                CAnim {}
                            }
                            Behavior on border.color {
                                CAnim {}
                            }
                            Behavior on scale {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }

                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onEntered: main.currentIndex = btnDelegate.index
                                onClicked: main.executeAction(btnDelegate.index)
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 30
                                source: Quickshell.iconPath(btnDelegate.modelData.icon)
                            }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: btnDelegate.modelData.name
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            font.bold: btnDelegate.isSelected
                            color: btnDelegate.isSelected ? Theme.fgColor : Theme.mutedFgColor

                            Behavior on color {
                                CAnim {}
                            }
                        }
                    }
                }
            }
        }
    }
}

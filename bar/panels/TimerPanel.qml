import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import PeakShell
import "root:/"
import "root:/components"
import "root:/bar/panels"
import "root:/services"

PanelWindow {
    id: root

    property var panelHost
    property bool editing: false

    function openPanel() {
        root.editing = false;
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("timer");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["timer"] = root;
    }

    function closePanel() {
        if (root.editing)
            root.exitEditing();
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["timer"] = false;
    }

    function togglePanel() {
        if (visible)
            closePanel();
        else
            openPanel();
    }

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    // Reads the three fields, rolls seconds into minutes and minutes into
    // hours (so values past 59 carry), writes the normalized values back and
    // returns the total in seconds.
    function editTotal() {
        let h = hoursField.value;
        let m = minutesField.value;
        let s = secondsField.value;
        m += Math.floor(s / 60);
        s %= 60;
        h += Math.floor(m / 60);
        m %= 60;
        h = clamp(h, 0, 99);
        hoursField.setValue(h);
        minutesField.setValue(m);
        secondsField.setValue(s);
        return h * 3600 + m * 60 + s;
    }

    function enterEditing() {
        if (root.editing)
            return;
        TimerService.pause();
        const total = Math.floor(TimerService.remainingMs / 1000) || TimerService.presetSeconds;
        hoursField.setValue(Math.floor(total / 3600));
        minutesField.setValue(Math.floor((total % 3600) / 60));
        secondsField.setValue(total % 60);
        root.editing = true;
        hoursField.focusInput();
    }

    function commitEdit() {
        TimerService.setDuration(editTotal());
    }

    function exitEditing() {
        if (!root.editing)
            return;
        commitEdit();
        root.editing = false;
    }

    function primaryLabel() {
        if (TimerService.finished)
            return "Restart";
        if (TimerService.running)
            return "Pause";
        if (TimerService.remainingMs > 0)
            return "Resume";
        return "Start";
    }

    function primaryAction() {
        if (root.editing)
            root.exitEditing();
        if (TimerService.finished)
            TimerService.start(TimerService.presetSeconds);
        else if (TimerService.remainingMs > 0)
            TimerService.toggleRunning();
        else
            root.enterEditing();
    }

    visible: false
    focusable: true
    color: "transparent"
    implicitWidth: Screen.desktopAvailableWidth
    implicitHeight: Screen.desktopAvailableHeight

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closePanel()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closePanel();
                event.accepted = true;
            }
        }
    }

    Rectangle {
        id: card
        width: Theme.timerPanelWidth || 420
        height: contentColumn.implicitHeight + 32
        anchors.right: parent.right
        anchors.rightMargin: Theme.barHorizontalPad
        y: Theme.dropdownOffset * 2

        color: Theme.bgColor
        border.color: Theme.mutedAccent
        border.width: Theme.generalThickness
        radius: Theme.cornerLargeRadius
        clip: true

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.editing)
                    root.exitEditing();
            }
        }

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94
        transformOrigin: Item.TopRight

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                IconImage {
                    Layout.alignment: Qt.AlignVCenter
                    implicitSize: Theme.iconFontSize
                    source: Quickshell.iconPath("alarm-clock-panel")
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    text: "Timer"
                    color: Theme.fgColor
                    font.pointSize: Theme.labelFontSize * 1.2
                    font.family: Theme.labelFontFamily
                    font.bold: true
                }

                ClickButton {
                    symbol: "window-close"
                    size: 28
                    onPress: root.closePanel()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                radius: Theme.cornerRadius
                color: Theme.mutedBgColor
                border.color: (TimerService.running || root.editing) ? Theme.accent : Theme.mutedAccent
                border.width: Theme.generalThickness
                clip: true

                Behavior on border.color {
                    CAnim {}
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.editing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.enterEditing()
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !root.editing
                        text: TimerService.formatted
                        color: TimerService.finished ? Theme.accent : Theme.fgColor
                        font.pointSize: Theme.labelFontSize * 3
                        font.family: Theme.labelFontFamily
                        font.bold: true
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        visible: root.editing
                        spacing: 2

                        TimerField {
                            id: hoursField
                            Layout.alignment: Qt.AlignTop
                            label: "Hours"
                            onAdvanced: {
                                root.commitEdit();
                                minutesField.focusInput();
                            }
                            onDismissed: root.exitEditing()
                        }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: ":"
                            color: Theme.fgColor
                            font.pointSize: Theme.labelFontSize * 3
                            font.family: Theme.labelFontFamily
                            font.bold: true
                        }

                        TimerField {
                            id: minutesField
                            Layout.alignment: Qt.AlignTop
                            label: "Minutes"
                            onAdvanced: {
                                root.commitEdit();
                                secondsField.focusInput();
                            }
                            onDismissed: root.exitEditing()
                        }

                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: ":"
                            color: Theme.fgColor
                            font.pointSize: Theme.labelFontSize * 3
                            font.family: Theme.labelFontFamily
                            font.bold: true
                        }

                        TimerField {
                            id: secondsField
                            Layout.alignment: Qt.AlignTop
                            label: "Seconds"
                            onAdvanced: root.commitEdit()
                            onDismissed: root.exitEditing()
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        visible: !root.editing
                        text: {
                            if (TimerService.finished)
                                return "Finished";
                            if (TimerService.running)
                                return "Running";
                            if (TimerService.remainingMs > 0)
                                return "Paused";
                            return "Ready";
                        }
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize * 0.9
                        font.family: Theme.labelFontFamily
                    }
                }
            }

            Text {
                text: "Presets"
                color: Theme.mutedFgColor
                font.pointSize: Theme.labelFontSize * 0.9
                font.family: Theme.labelFontFamily
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 3
                rowSpacing: 8
                columnSpacing: 8

                Repeater {
                    model: [
                        {
                            label: "1 min",
                            seconds: 60
                        },
                        {
                            label: "5 min",
                            seconds: 300
                        },
                        {
                            label: "10 min",
                            seconds: 600
                        },
                        {
                            label: "15 min",
                            seconds: 900
                        },
                        {
                            label: "30 min",
                            seconds: 1800
                        },
                        {
                            label: "1 hour",
                            seconds: 3600
                        }
                    ]

                    delegate: Rectangle {
                        id: presetCell
                        required property var modelData

                        readonly property bool isActive: TimerService.presetSeconds === presetCell.modelData.seconds

                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Theme.cornerRadius
                        color: isActive ? Theme.accent : (presetMouse.containsMouse ? Theme.hoveredBgColor : Theme.mutedBgColor)

                        Behavior on color {
                            CAnim {}
                        }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.editing = false;
                                TimerService.start(presetCell.modelData.seconds);
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: presetCell.modelData.label
                            color: presetCell.isActive ? Theme.fgColor : Theme.mutedFgColor
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            font.bold: presetCell.isActive
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Theme.cornerRadius
                    color: primaryMouse.containsMouse ? Theme.accent : Theme.mutedBgColor

                    Behavior on color {
                        CAnim {}
                    }

                    MouseArea {
                        id: primaryMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.primaryAction()
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.primaryLabel()
                        color: Theme.fgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        font.bold: true
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 40
                    radius: Theme.cornerRadius
                    color: resetMouse.containsMouse ? Theme.hoveredBgColor : Theme.mutedBgColor
                    opacity: TimerService.active ? 1 : 0.4

                    Behavior on color {
                        CAnim {}
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.editing)
                                root.exitEditing();
                            TimerService.reset();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Reset"
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                    }
                }
            }
        }
    }
}

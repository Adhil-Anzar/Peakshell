import QtQuick
import QtQuick.Layouts
import PeakShell
import "root:/"
import "../widgets"

ColumnLayout {
    spacing: 12
    property var positions: [
        { key: "topLeft", label: "Top left" },
        { key: "topRight", label: "Top right" },
        { key: "bottomLeft", label: "Bottom left" },
        { key: "bottomRight", label: "Bottom right" }
    ]
    Section {
        title: "Popup position"
        hint: "Corner of the screen where notification popups appear"
        resetLabel: "Reset notifications"
        onReset: Settings.resetNotifications()
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: positions
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: Settings.cornerRadius
                    color: Settings.notificationPosition === modelData.key ? Settings.hoveredBgColor : Settings.bgColor
                    border.color: Settings.notificationPosition === modelData.key ? Theme.accent : Settings.mutedAccent
                    border.width: Settings.notificationPosition === modelData.key ? Settings.generalThickness : 1
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: Settings.fgColor
                        font.pointSize: Settings.labelFontSize
                        font.family: Settings.labelFontFamily
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.notificationPosition = modelData.key
                    }
                }
            }
        }
    }
    Section {
        title: "Behavior"
        Row { label: "Popup timeout"; hint: "Milliseconds before a popup fades"; NumField { width: parent.width; value: Settings.notificationPopupTimeout; from: 1000; to: 30000; step: 500; isInt: true; onEdited: v => Settings.notificationPopupTimeout = v } }
        Row { label: "Max popups"; hint: "How many popups stack on screen"; NumField { width: parent.width; value: Settings.notificationMaxPopups; from: 1; to: 10; step: 1; isInt: true; onEdited: v => Settings.notificationMaxPopups = v } }
        Row {
            label: "Show copy button"
            hint: "Right-click any notification to copy its text, even when the button is hidden"
            Toggle {
                x: parent.width - width
                checked: Settings.notificationShowCopyButton
                onToggled: v => Settings.notificationShowCopyButton = v
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import PeakShell
import "root:/services"
import "../widgets"

ColumnLayout {
    spacing: 12
    Section {
        title: "Features"
        resetLabel: "Reset clipboard"
        onReset: Settings.resetClipboard()
        Row {
            label: "Fuzzy search"
            hint: "Off means only literal substring matches are shown"
            Toggle {
                x: parent.width - width
                checked: Settings.clipboardFuzzy
                onToggled: v => Settings.clipboardFuzzy = v
            }
        }
    }
    Section {
        title: "History"
        hint: "Oldest entries are dropped once the limit is reached."
        Row {
            label: "Max items"
            hint: "How many clipboard entries to keep (default 100)"
            NumField {
                width: parent.width
                value: Settings.clipboardMaxItems
                from: 10
                to: 1000
                step: 10
                isInt: true
                onEdited: v => Settings.clipboardMaxItems = v
            }
        }
        Row {
            label: "Stored entries"
            hint: "Currently captured clipboard items"
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                horizontalAlignment: Text.AlignRight
                text: Clipboard.count.toString()
                color: Settings.fgColor
                font.pointSize: Settings.labelFontSize
                font.family: Settings.labelFontFamily
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 34
            radius: Settings.cornerRadius
            color: clearMa.containsMouse ? Settings.hoveredBgColor : Settings.bgColor
            border.color: Settings.mutedAccent
            border.width: 1
            Text {
                anchors.centerIn: parent
                text: "Clear history"
                color: Settings.mutedFgColor
                font.pointSize: Settings.labelFontSize
                font.family: Settings.labelFontFamily
            }
            MouseArea {
                id: clearMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Clipboard.clear()
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import PeakShell

Rectangle {
    property string title: ""
    property string hint: ""
    property string resetLabel: ""
    signal reset()
    default property alias content: body.data
    color: Settings.bgColor
    border.color: Settings.mutedAccent
    border.width: 1
    radius: Settings.cornerLargeRadius
    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 28

    ColumnLayout {
        id: inner
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: title
                color: Settings.fgColor
                font.pointSize: Settings.labelFontSize + 2
                font.bold: true
                font.family: Settings.labelFontFamily
            }
            Rectangle {
                visible: resetLabel.length > 0
                implicitWidth: resetText.implicitWidth + 20
                implicitHeight: resetText.implicitHeight + 10
                radius: height * 0.5
                color: resetMa.containsMouse ? Settings.hoveredBgColor : "transparent"
                border.color: Settings.mutedAccent
                border.width: 1
                Text {
                    id: resetText
                    anchors.centerIn: parent
                    text: resetLabel
                    color: Settings.mutedFgColor
                    font.pointSize: Settings.labelFontSize
                    font.family: Settings.labelFontFamily
                }
                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: reset()
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            visible: hint.length > 0
            text: hint
            color: Settings.mutedFgColor
            font.pointSize: Math.max(8, Settings.labelFontSize - 1)
            font.family: Settings.labelFontFamily
            wrapMode: Text.WordWrap
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 6
        }
    }
}

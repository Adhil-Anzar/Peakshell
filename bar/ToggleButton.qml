import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell
import "root:/"

ColumnLayout {
    signal press()
    property bool isChecked: true
    property real size: 50
    property string symbol
    property string label
    Layout.alignment: Qt.AlignVCenter  | Qt.AlignHCenter
    spacing: 8

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        width: size
        height: size
        radius: Theme.cornerRadius
        Behavior on color {
            ColorAnimation {
            duration: Theme.animationDuration
            }
        }
        scale: mouseArea.containsMouse ? 1.25 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: Theme.animationDuration
                easing.type: Easing.OutExpo
            }
        }
        color: isChecked ? Theme.accent : Theme.mutedBgColor
        // Text {
        //     anchors.centerIn: parent
        //     text: symbol
        //     font.pointSize: Theme.iconFontSize 
        //     font.family: Theme.iconFontFamily 
        //     color: isChecked ? Theme.altFgColor : Theme.fgColor 
        //     Behavior on color {
        //         ColorAnimation {
        //         duration: Theme.animationDuration
        //         }
        //     }
        // }
        IconImage {
            implicitSize: Theme.iconFontSize
            anchors.centerIn: parent
            source: Quickshell.iconPath(symbol)
        }
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: { isChecked = !isChecked; press() }
        }
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        text: label
        font.pointSize: Theme.labelFontSize
        font.family: Theme.labelFontFamily
        color: Theme.fgColor
    }
}
import QtQuick
import PeakShell

Rectangle {
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 46
    implicitHeight: 26
    radius: 13
    color: checked ? Settings.accent : Settings.mutedBgColor
    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    Rectangle {
        width: 20
        height: 20
        radius: 10
        x: parent.checked ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        color: Settings.fgColor
        Behavior on x {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggled(!parent.checked)
    }
}

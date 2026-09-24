import QtQuick
import "root:/"

Rectangle {
    id: root
    property string label
    signal press()
    implicitHeight: textObject.height
    implicitWidth: textObject.width + Theme.cornerLargeRadius
    radius: Theme.cornerRadius
    visible: textObject.width !== 0

    Behavior on color {
        CAnim {}
    }
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"

    MouseArea {
        enabled: parent.enabled
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.press()
    }
    Text {
        anchors.centerIn: parent
        id: textObject
        text: label
        color: Theme.mutedFgColor
        font.pointSize: Theme.labelFontSize
        font.family: Theme.labelFontFamily
    }
}

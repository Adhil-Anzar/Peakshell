import QtQuick
import "root:/"

Rectangle {
    id: root
    // Properties
    property string icon
    property bool isIconOnly: true
    property string label
    scale: mouseArea.containsMouse ? 1.1 : 1.0
    // Transitions

    Behavior on scale {
        NumberAnimation {
            duration: Theme.animationDuration
            easin.type: Easing.OutExpo
        }
    }
    Behavior on color {
        ColorAnimation {
        duration: Theme.animationDuration
        }
    }
    // Styling
    color: {
        if (mouseArea.containsMouse)
            return Theme.hoveredBgColor
        return Theme.bgColor
    }
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    // Icon / Label Text
    Text {
        anchors.centerIn: parent
        text: parent.isIconOnly ? parent.icon : parent.label
        font.pointSize: parent.isIconOnly ? Theme.iconFontSize : Theme.labelFontSize
        font.family: parent.isIconOnly ? Theme.iconFontFamily : Theme.labelFontFamily
        color: Theme.fgColor
    }
    // Controls animation on color change + Click
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: parent.onClicked()
    }
}
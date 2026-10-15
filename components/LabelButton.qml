import QtQuick
import "root:/"

Rectangle {
    id: root
    property string label
    property real maxWidth: -1
    readonly property real desiredWidth: textObject.implicitWidth + Theme.cornerLargeRadius
    signal press
    implicitHeight: textObject.height
    implicitWidth: {
        if (maxWidth === -1)
            return desiredWidth;
        return maxWidth <= desiredWidth ? maxWidth : desiredWidth;
    }
    radius: Theme.cornerRadius
    visible: textObject.width !== 0

    Behavior on color {
        CAnim {}
    }
    Behavior on implicitWidth {
        Anim {
            type: Anim.FastEffects
        }
    }

    color: mouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"

    MouseArea {
        id: mouseArea
        enabled: parent.enabled
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.press()
    }
    Text {
        id: textObject
        anchors.centerIn: parent
        width: parent.width - Theme.cornerLargeRadius
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: label
        color: Theme.mutedFgColor
        elide: Text.ElideRight
        font.pointSize: Theme.labelFontSize
        font.family: Theme.labelFontFamily
    }
}

import QtQuick
import Quickshell.Widgets
import Quickshell
import "root:/"

Rectangle {
    id: root
    signal press()
    property real size: Theme.iconFontSize
    property string symbol
    property real cornerRadius: Theme.cornerRadius
    property string bgColor: Theme.mutedBgColor
    
    width: size
    height: size
    radius: cornerRadius
    color: mouseArea.pressed ? Theme.accent : bgColor
    Behavior on color {
        CAnim {}
    }
    scale: mouseArea.containsMouse ? 1.25 : 1.0
    Behavior on scale {
        Anim { type: Anim.DefaultSpatial }
    }
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
        onClicked: root.press()
    }
}

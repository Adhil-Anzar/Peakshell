import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell
import "root:/"

Rectangle {
    id: root
    signal press
    signal scroll(int delta)

    property real size: Theme.iconFontSize
    property string symbol
    property real cornerRadius: Theme.cornerRadius
    property string bgColor: Theme.mutedBgColor
    property var iconColor: undefined
    readonly property bool isHovered: mouseArea.containsMouse

    width: size
    height: size
    radius: cornerRadius
    color: mouseArea.pressed ? Theme.accent : bgColor
    Behavior on color {
        CAnim {}
    }
    scale: mouseArea.containsMouse ? 1.25 : 1.0
    Behavior on scale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    IconImage {
        implicitSize: Theme.iconFontSize
        anchors.centerIn: parent
        source: Quickshell.iconPath(symbol)
        layer.enabled: root.iconColor !== undefined
        layer.effect: MultiEffect {
            colorization: 1.0
            brightness: 1.0
            colorizationColor: root.iconColor !== undefined ? root.iconColor : "transparent"
            Behavior on colorizationColor {
                CAnim {}
            }
        }
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.press()

        onWheel: wheel => {
            let delta = wheel.angleDelta.y > 0 ? 1 : (wheel.angleDelta.y < 0 ? -1 : 0);
            if (delta !== 0) {
                root.scroll(delta);
            }
        }
    }
}

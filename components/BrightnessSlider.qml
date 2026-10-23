import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell.Widgets
import "root:/"
import "root:/services"

// Volume-slider style track, but the accent follows the brightness level:
// low values are dim and almost monochrome, 100% is fully saturated and
// glowing.
Slider {
    id: root

    focusPolicy: Qt.NoFocus
    from: 0
    to: 1

    readonly property real glow: Math.max(0, Math.min(1, (root.visualPosition - 0.82) / 0.18))
    readonly property color accentColor: Brightness.levelColor(root.value)

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitHeight: 8
        width: root.availableWidth
        height: implicitHeight
        radius: height / 2
        color: Theme.mutedBgColor

        RectangularShadow {
            anchors.fill: activeTrack
            color: root.accentColor
            radius: activeTrack.radius
            spread: 1.5 + root.glow * 7
            blur: 6 + root.glow * 28
            opacity: 0.15 + root.glow * 0.85
        }

        Rectangle {
            id: activeTrack
            width: root.visualPosition * parent.width
            height: parent.height
            radius: height / 2
            color: root.accentColor
            Behavior on color {
                CAnim {}
            }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 14
        implicitHeight: 14
        radius: 14
        color: root.accentColor
        border.color: Qt.lighter(root.accentColor, 1.45)
        border.width: root.glow > 0.02 ? 1 : 0
        scale: root.pressed ? 1.5 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.animationDuration
                easing.type: Easing.OutExpo
            }
        }
        Behavior on color {
            CAnim {}
        }
    }
}

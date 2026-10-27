import QtQuick
import QtQuick.Controls
import "root:/"

// Slim, pill-shaped scrollbar used by the preview surfaces. The default
// controls style draws square handles; this keeps the shell's rounded look.
ScrollBar {
    id: root

    policy: ScrollBar.AsNeeded
    minimumSize: 0.08
    hoverEnabled: true
    focusPolicy: Qt.NoFocus

    background: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: Math.min(width, height) / 2
        color: "transparent"
    }

    contentItem: Rectangle {
        implicitWidth: 6
        implicitHeight: 6
        radius: Math.min(width, height) / 2
        color: root.pressed ? Theme.accent : Theme.mutedFgColor
        opacity: root.pressed ? 1.0 : (root.hovered ? 0.85 : 0.55)

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
}

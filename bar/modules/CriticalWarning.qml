import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

Rectangle {
    id: root

    property var panelHost

    readonly property bool isCritical: SystemMonitor.isCritical

    // Matches other bar chips: only visible when critical, slides in/out
    visible: isCritical || opacity > 0.01
    opacity: isCritical ? 1 : 0
    implicitHeight: Theme.barHeight
    width: isCritical ? container.width + Theme.cornerLargeRadius : 0

    Behavior on width {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Background same as other bar chips; red border kept as indicator
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : Theme.bgColor
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius

    // Pulsing red border — the only thing that distinguishes it from normal chips
    property color borderColor: Theme.dangerPulse
    border.color: borderColor

    SequentialAnimation {
        running: root.isCritical
        loops: Animation.Infinite
        ColorAnimation {
            target: root
            property: "borderColor"
            from: Theme.dangerPulse
            to: Theme.danger
            duration: 750
            easing.type: Easing.InOutSine
        }
        ColorAnimation {
            target: root
            property: "borderColor"
            from: Theme.danger
            to: Theme.dangerPulse
            duration: 750
            easing.type: Easing.InOutSine
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    Row {
        id: container
        anchors.centerIn: parent
        spacing: 6

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Theme.iconFontSize
            // Try themed name first; fall back to the known Papirus/YAMIS panel icon
            source: {
                const icon = SystemMonitor.criticalIcon;
                // indicator-sensors-cpu lives in the panel/ category of most icon themes
                // Quickshell.iconPath searches all categories, so pass it directly
                return Quickshell.iconPath(icon, "cpu");
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: SystemMonitor.criticalMessage
            font.pointSize: Theme.labelFontSize
            font.family: Theme.labelFontFamily
            font.bold: true
            color: Theme.fgColor
        }
    }
}

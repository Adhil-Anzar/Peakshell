import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/bar/panels"
import "root:/services"

Rectangle {
    id: root

    property var panelHost

    function togglePanel() {
        calendarLoader.active = true;
        calendarLoader.item.togglePanel();
    }

    function toggleTimerPanel() {
        calendarLoader.active = true;
        calendarLoader.item.toggleTimer();
    }

    Behavior on width {
        Anim { type: Anim.DefaultSpatial }
    }
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : Theme.bgColor
    Behavior on color {
        CAnim {}
    }
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    width: container.width + Theme.cornerLargeRadius

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: {
            hoverDebounce.isDelaying = true
            hoverDebounce.restart()
            clock.now = new Date()
            clock.restart()
        }
        onExited: {
            hoverDebounce.isDelaying = true
            hoverDebounce.restart()
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.toggleTimerPanel();
            else
                root.togglePanel();
        }
    }

    Timer {
        id: hoverDebounce
        property bool isDelaying: false
        interval: Theme.hoverDuration
        repeat: false
        running: !mouseArea.containsMouse && isDelaying

        onTriggered: isDelaying = false
    }

    Timer {
        id: clock
        property date now: new Date()
        property int msToNextMinute: 60000
        property int msToNextSecond: 1000
        interval: hoverDebounce.isDelaying || mouseArea.containsMouse ? msToNextSecond : msToNextMinute
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            now = new Date()
            if (hoverDebounce.isDelaying || mouseArea.containsMouse)
                msToNextSecond = Math.max(1, 1000 - now.getMilliseconds())
            msToNextMinute = Math.max(1, 60000 - (now.getSeconds() * 1000 + now.getMilliseconds()))
        }
    }

    Row {
        id: container
        anchors.centerIn: parent
        spacing: 5

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            opacity: TimerService.running ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: Theme.iconFontSize
                source: Quickshell.iconPath("alarm-clock-panel")
                smooth: true
                mipmap: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: TimerService.compact
                color: Theme.accent
                font.pointSize: Theme.labelFontSize
                font.family: Theme.labelFontFamily
                font.bold: true
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.now, hoverDebounce.isDelaying || mouseArea.containsMouse ? "dd/MM/yyyy dddd hh:mm:ss AP" : "dddd hh:mm AP")
            font.pointSize: Theme.labelFontSize
            font.family: Theme.labelFontFamily
            color: Theme.fgColor
            opacity: visible ? 1 : 0
            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }
        }
    }

    LazyLoader {
        id: calendarLoader
        loading: true
        CalendarPanel {
            panelHost: root.panelHost
        }
    }
}

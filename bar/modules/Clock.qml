import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "root:/"

Rectangle {
    id: root
    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutExpo
        }
    }
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : Theme.bgColor
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
        //acceptedButtons: Qt.LeftButton
        onEntered: { hoverDebounce.isDelaying = true; hoverDebounce.restart(); clock.now = new Date(); clock.restart(); }
        onExited: { hoverDebounce.isDelaying = true; hoverDebounce.restart() }
        //onClicked: root.togglePanel()
    }
    Timer {
        id: hoverDebounce
        property bool isDelaying: false
        interval: Theme.hoverDuration
        repeat: false
        running: !mouseArea.containsMouse && isDelaying

        onTriggered: isDelaying = false;
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
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.now, hoverDebounce.isDelaying || mouseArea.containsMouse ? "dd/MM/yyyy dddd hh:mm:ss AP" : "dddd hh:mm AP")
            font.pointSize: Theme.labelFontSize
            font.family: Theme.labelFontFamily
            color: Theme.fgColor
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
        }
    }
    PanelWindow {
        id: panel
        visible: false
        focusable: true
        color: "transparent"
        implicitWidth: Theme.clockPanelWidth + Theme.barHorizontalPad
        implicitHeight: Theme.clockPanelHeight
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            bottom: false
            left: false
            right: true
        }
        Rectangle {
            anchors.fill: parent
            anchors.rightMargin: Theme.barHorizontalPad
            color: Theme.bgColor
            radius: Theme.cornerRadius
            border.color: Theme.mutedAccent
            border.width: Theme.generalThickness
            // Calendar thing
        }
    }
}

import QtQuick
import QtQuick.Controls
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell
import "root:/"

Rectangle {
    required property SystemTrayItem modelData;
    required property var panelHost;
    height: parent.height
    width: this.height
    radius: Theme.cornerRadius
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
    Behavior on color {
        ColorAnimation { duration: Theme.animationDuration }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: { hoverDebounce.isDelaying = true; hoverDebounce.restart() }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (modelData.hasMenu) {
                    const p = parent.mapFromGlobal(0,0)
                    modelData.display(panelHost, Math.abs(p.x), Theme.barHeight + Theme.barHorizontalPad / 2)
                    //mainMenu.open()
                }

                return;
            }
            if (mouse.button === Qt.LeftButton) {
                modelData.activate()
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                modelData.secondaryActivate()
            }
        }
        onWheel: (wheel) => {
            modelData.scroll(wheel.angleDelta.x, wheel.angleDelta.y)
        }
    }
    Timer {
        id: hoverDebounce
        property bool isDelaying: false
        interval: Theme.hoverDuration
        repeat: false
        running: !mouseArea.containsMouse && isDelaying

        onTriggered: isDelaying = false;
    }
    IconImage {
        anchors.centerIn: parent
        implicitSize: Theme.iconFontSize
        source: modelData.icon
    }
}

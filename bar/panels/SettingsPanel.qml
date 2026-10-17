import QtQuick
import Quickshell
import Quickshell.Wayland
import PeakShell
import "root:/"
import "root:/settings"

PanelWindow {
    id: root
    property var panelHost

    function open() {
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("settings");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["settings"] = root;
    }

    function close() {
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["settings"] = false;
    }

    function toggle() {
        visible ? close() : open();
    }

    visible: false
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(1020, parent.width - 32)
            height: Math.min(740, parent.height - 32)
            color: Settings.bgColor
            border.color: Settings.mutedAccent
            border.width: 1
            radius: Settings.cornerLargeRadius
            clip: true

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            SettingsView {
                anchors.fill: parent
                anchors.margins: 16
            }
        }
    }
}

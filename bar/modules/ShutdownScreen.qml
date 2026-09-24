import QtQuick
import "root:/"
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland

PanelWindow {
    required property var panelHost
    function togglePanel() {
        panelHost.hideAllPanelExcept("shutdown")
        main.visible = !main.visible;
        if (main.visible) panelHost.toggledPanels["shutdown"] = main;
        else panelHost.toggledPanels["shutdown"] = false;
    }

    id: main
    visible: false
    focusable: true
    color: Theme.bgColor
    WlrLayershell.layer: WlrLayer.Overlay
    implicitHeight: Screen.desktopAvailableHeight
    implicitWidth: Screen.desktopAvailableWidth
    anchors {
        top: false
        bottom: false
        left: false
        right: false
    }
}

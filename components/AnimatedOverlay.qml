import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"

PanelWindow {
    id: panel
    required property var container
    property bool expanded: false
    property var displayContent
    property point targetPos: Qt.point(0, 0)

    function refreshPos() {
        targetPos = container.mapToItem(null, 0, 0)
    }

    Connections {
        target: container
        function onXChanged() { panel.refreshPos() }
        function onYChanged() { panel.refreshPos() }
        function onWidthChanged() { panel.refreshPos() }
        function onHeightChanged() { panel.refreshPos() }
    }

    visible: expanded
    onExpandedChanged: refreshPos()
    Component.onCompleted: refreshPos()

    focusable: false
    color: "transparent"
    implicitWidth: Theme.workspacePanelWidth + Theme.barHorizontalPad + Math.abs(targetPos.x)
    implicitHeight: loader.height
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: false
        left: true
        right: false
    }

    Loader {
        id: loader
        x: (expanded ? (container.width / 2) - (Theme.workspacePanelWidth / 2) : 0) + Math.abs(targetPos.x) + Theme.barHorizontalPad
        y: expanded ? targetPos.y + (Theme.barVerticalPad * 3.5) + container.height : targetPos.y + Theme.barVerticalPad
        height: expanded ? Theme.workspacePanelHeight : container.height
        width: expanded ? Theme.workspacePanelWidth : container.width
        opacity: expanded ? 1 : 0
        Behavior on y { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo } }
        Behavior on x { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo } }
        Behavior on width { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo } }
        sourceComponent: panel.displayContent
    }
}

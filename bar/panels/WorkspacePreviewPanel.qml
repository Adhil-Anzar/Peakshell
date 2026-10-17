import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick.Effects
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root

    property var panelHost

    property int targetWorkspaceId: Hypr.activeWsId
    property string targetWorkspaceName: ""
    property int selectedIndex: 0
    property int prevSelectedIndex: 0
    property bool isShiftPressed: false

    readonly property var wsToplevels: Hypr.toplevelsForWs(targetWorkspaceId)
    readonly property HyprlandToplevel currentToplevel: {
        if (!wsToplevels || wsToplevels.length === 0)
            return null;
        const idx = Math.max(0, Math.min(selectedIndex, wsToplevels.length - 1));
        return wsToplevels[idx];
    }
    onVisibleChanged: {
        if (visible)
            screencopyView.update();
    }
    // Slide/Fade animation when switching selected tab
    onSelectedIndexChanged: {
        if (!root.visible || selectedIndex === prevSelectedIndex) {
            prevSelectedIndex = selectedIndex;
            return;
        }

        const count = root.wsToplevels.length;
        let isNext = selectedIndex > prevSelectedIndex;

        // Handle wrap-around direction
        if (prevSelectedIndex === count - 1 && selectedIndex === 0)
            isNext = true;
        if (prevSelectedIndex === 0 && selectedIndex === count - 1)
            isNext = false;

        prevSelectedIndex = selectedIndex;

        // Animate content from right to left (next) or left to right (prev)
        tabSwitchAnim.stop();
        activePreviewContent.slideX = isNext ? 35 : -35;
        activePreviewContent.contentOpacity = 0.2;
        tabSwitchAnim.start();
    }

    // When the user swaps desktops while preview is open, automatically switch preview to current desktop
    Connections {
        target: Hypr
        function onActiveWsIdChanged() {
            if (root.visible) {
                root.targetWorkspaceId = Hypr.activeWsId;
                const ws = Hypr.workspaceById(Hypr.activeWsId);
                root.targetWorkspaceName = ws ? ws.name : ("Workspace " + Hypr.activeWsId);

                // Find index of currently focused window
                let targetIndex = 0;
                const toplevels = Hypr.toplevelsForWs(Hypr.activeWsId);
                if (Hypr.activeToplevel && toplevels) {
                    for (let i = 0; i < toplevels.length; i++) {
                        if (toplevels[i].address === Hypr.activeToplevel.address) {
                            targetIndex = i;
                            break;
                        }
                    }
                }

                root.selectedIndex = targetIndex;
                root.prevSelectedIndex = targetIndex;
            }
        }
        function onActiveToplevelChanged() {
            Qt.callLater(() => {
                if (root.visible) {
                    if (Hypr.activeToplevel) {
                        root.selectedIndex = Hypr.getActiveWsTopLevelIndex();
                    } else {
                        root.selectedIndex = 0;
                    }
                    screencopyView.update();
                }
            });
        }
    }

    function getAppClass(toplevel) {
        if (!toplevel || !toplevel.lastIpcObject || !toplevel.lastIpcObject.class)
            return "";
        return toplevel.lastIpcObject.class;
    }

    function getAppIcon(toplevel) {
        const cls = getAppClass(toplevel);
        return cls ? Quickshell.iconPath(cls.toLowerCase(), "application-x-executable") : Quickshell.iconPath("application-x-executable");
    }

    function getAppTitle(toplevel) {
        if (!toplevel)
            return "Window";
        if (toplevel.title)
            return toplevel.title;
        return getAppClass(toplevel) || "Window";
    }

    function openPreview(wsId, wsName) {
        targetWorkspaceId = wsId ? wsId : Hypr.activeWsId;
        targetWorkspaceName = wsName ? wsName : ("Workspace " + targetWorkspaceId);
        selectedIndex = Hypr.getActiveWsTopLevelIndex();
        prevSelectedIndex = selectedIndex;
        isShiftPressed = false;
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("workspacePreview");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["workspacePreview"] = root;
    }

    function closePreview() {
        visible = false;
        isShiftPressed = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["workspacePreview"] = false;
    }

    function togglePreview(wsId, wsName) {
        if (visible && targetWorkspaceId === wsId)
            closePreview();
        else
            openPreview(wsId, wsName);
    }

    function focusSelected() {
        if (root.currentToplevel) {
            const ws = Hypr.workspaceById(root.targetWorkspaceId);
            if (ws)
                ws.activate();
            Hypr.focusWindow(root.currentToplevel.address);
            root.closePreview();
        }
    }

    visible: false
    focusable: true
    color: "transparent"
    implicitWidth: Screen.desktopAvailableWidth
    implicitHeight: Screen.desktopAvailableHeight

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Parallel animation handling slide and fade concurrently
    ParallelAnimation {
        id: tabSwitchAnim

        NumberAnimation {
            target: activePreviewContent
            property: "slideX"
            to: 0
            duration: 180
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: activePreviewContent
            property: "contentOpacity"
            to: 1.0
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    // Dismiss on clicking background
    MouseArea {
        anchors.fill: parent
        onClicked: root.closePreview()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible

        onActiveFocusChanged: event => {
            if (!event.activeFocus) {
                root.isShiftPressed = false;
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Shift || (event.modifiers & Qt.ShiftModifier)) {
                root.isShiftPressed = true;
            }
            if (event.key === Qt.Key_Escape) {
                root.closePreview();
                event.accepted = true;
            }
            if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                focusSelected();
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Shift || !(event.modifiers & Qt.ShiftModifier)) {
                root.isShiftPressed = false;
            }
        }

        Keys.onTabPressed: event => {
            const count = root.wsToplevels.length;
            if (count > 1) {
                root.selectedIndex = (root.selectedIndex + 1) % count;
            }
            event.accepted = true;
        }

        Keys.onBacktabPressed: event => {
            const count = root.wsToplevels.length;
            if (count > 1)
                root.selectedIndex = (root.selectedIndex - 1 + count) % count;
            event.accepted = true;
        }
    }

    // Main Layout container grouping Card 1 & Card 2
    ColumnLayout {
        id: cardContainer
        width: Theme.workspacePreviewWidth
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.dropdownOffset * 2
        spacing: visible ? 5 : 30
        Behavior on spacing {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.92
        transformOrigin: Item.Top

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Scroll / trackpad gesture navigation across both cards
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event => {
                const count = root.wsToplevels.length;

                if (count <= 1) {
                    event.accepted = true;
                    return;
                }

                if (event.angleDelta.y > 0) {
                    // Scroll up → previous window
                    root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                } else if (event.angleDelta.y < 0) {
                    // Scroll down → next window
                    root.selectedIndex = Math.min(root.selectedIndex + 1, count - 1);
                }

                event.accepted = true;
            }
        }

        // Card 1: header row and window switcher tabs
        Rectangle {
            id: headerCard
            Layout.fillWidth: true
            Layout.preferredHeight: root.wsToplevels.length === 0 ? 0 : headerColumn.implicitHeight + 24

            color: Theme.bgColor
            border.color: Theme.mutedAccent
            border.width: Theme.generalThickness
            radius: Theme.cornerLargeRadius
            clip: true

            Behavior on Layout.preferredHeight {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            // Prevent clicks inside card from propagating to background dismiss
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: headerColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Header Row: Workspace Name, Window Count, Close Dialog Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: wsLabel.implicitWidth + 20
                        radius: Theme.cornerRadius
                        color: Theme.accent

                        Text {
                            id: wsLabel
                            anchors.centerIn: parent
                            text: root.targetWorkspaceName ? root.targetWorkspaceName : ("Workspace " + root.targetWorkspaceId)
                            color: Theme.fgColor
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            font.bold: true
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.wsToplevels.length + (root.wsToplevels.length === 1 ? " window" : " windows")
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    ClickButton {
                        symbol: "window-close"
                        size: 26
                        onPress: root.closePreview()
                    }
                }

                // Window Switcher Tabs (if multiple windows)
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.wsToplevels.length > 1
                    spacing: 6

                    Repeater {
                        model: root.wsToplevels

                        delegate: Rectangle {
                            id: tabItem
                            required property HyprlandToplevel modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Theme.cornerRadius
                            color: root.selectedIndex === tabItem.index ? Theme.hoveredBgColor : "transparent"
                            border.color: root.selectedIndex === tabItem.index ? Theme.accent : Theme.mutedAccent
                            border.width: 1

                            Behavior on color {
                                CAnim {}
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedIndex = tabItem.index
                            }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                width: parent.width - 12

                                IconImage {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitSize: 16
                                    source: root.getAppIcon(tabItem.modelData)
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.getAppTitle(tabItem.modelData)
                                    color: root.selectedIndex === tabItem.index ? Theme.fgColor : Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize * 0.9
                                    font.family: Theme.labelFontFamily
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }

        // Card 2: content area and live preview frame
        Rectangle {
            id: contentCard
            Layout.fillWidth: true
            implicitHeight: root.wsToplevels.length > 0 ? Theme.workspacePreviewHeight : 180

            color: Theme.bgColor
            border.color: Theme.mutedAccent
            border.width: Theme.generalThickness
            radius: Theme.cornerLargeRadius
            clip: true

            Behavior on implicitHeight {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            // Prevent clicks inside card from propagating to background dismiss
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Item {
                anchors.fill: parent
                anchors.margins: 12

                // Active Window Preview Card (Animated)
                ColumnLayout {
                    id: activePreviewContent
                    anchors.fill: parent
                    visible: root.wsToplevels.length > 0 && root.currentToplevel !== null
                    spacing: 10

                    property real slideX: 0
                    property real contentOpacity: 1.0

                    opacity: contentOpacity
                    transform: Translate {
                        x: activePreviewContent.slideX
                    }

                    // Window info banner with Kill / Force Kill button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        IconImage {
                            Layout.alignment: Qt.AlignVCenter
                            implicitSize: 22
                            source: root.getAppIcon(root.currentToplevel)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: root.getAppTitle(root.currentToplevel)
                                color: Theme.fgColor
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.getAppClass(root.currentToplevel)
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                                elide: Text.ElideRight
                            }
                        }

                        // Kill / Force Kill Button
                        Rectangle {
                            id: killBtn
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: killBtnRow.implicitWidth + 20
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.cornerRadius

                            color: root.isShiftPressed ? "#D32F2F" : (killMouse.containsMouse ? Theme.hoveredBgColor : Theme.mutedBgColor)
                            border.color: root.isShiftPressed ? "#EF5350" : (killMouse.containsMouse ? Theme.accent : Theme.mutedAccent)
                            border.width: 1

                            Behavior on color {
                                CAnim {}
                            }

                            Behavior on border.color {
                                CAnim {}
                            }

                            Behavior on Layout.preferredWidth {
                                Anim {
                                    type: Anim.FastEffects
                                }
                            }

                            MouseArea {
                                id: killMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton

                                onClicked: mouse => {
                                    if (!root.currentToplevel)
                                        return;
                                    const isShift = root.isShiftPressed || (mouse.modifiers & Qt.ShiftModifier);
                                    if (isShift) {
                                        const pid = (root.currentToplevel.lastIpcObject && root.currentToplevel.lastIpcObject.pid) ? root.currentToplevel.lastIpcObject.pid : 0;
                                        Hypr.forceKillWindow(pid, root.currentToplevel.address);
                                    } else {
                                        Hypr.dispatch("closewindow address:" + root.currentToplevel.address);
                                    }
                                }
                            }

                            RowLayout {
                                id: killBtnRow
                                anchors.centerIn: parent
                                spacing: 6

                                IconImage {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitSize: 14
                                    source: Quickshell.iconPath(root.isShiftPressed ? "process-stop" : "window-close")
                                }

                                Text {
                                    id: killTxt
                                    Layout.alignment: Qt.AlignVCenter
                                    text: root.isShiftPressed ? "Force Kill" : "Kill"
                                    color: root.isShiftPressed ? "#FFFFFF" : Theme.fgColor
                                    font.pointSize: Theme.labelFontSize
                                    font.family: Theme.labelFontFamily
                                    elide: Text.ElideRight
                                    font.bold: root.isShiftPressed
                                }
                            }
                        }
                    }

                    // Screencopy Live Preview Frame
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 4
                        color: Qt.darker(Theme.bgColor, 2)
                        radius: Theme.cornerRadius
                        border.color: Theme.mutedAccent
                        border.width: Theme.generalThickness
                        clip: true

                        Connections {
                            target: root
                            function onCurrentToplevelChanged() {
                                screencopyView.update();
                            }
                        }

                        ScreencopyView {
                            id: screencopyView
                            anchors.fill: parent
                            anchors.margins: Theme.generalThickness
                            captureSource: root.currentToplevel ? root.currentToplevel.wayland : null
                            live: root.visible
                            paintCursor: false

                            // Enable layer and apply rounded clipping effect
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: ShaderEffectSource {
                                    sourceItem: Rectangle {
                                        width: screencopyView.width
                                        height: screencopyView.height
                                        // Subtract inner border margin so corners fit cleanly inside
                                        radius: Math.max(0, Theme.cornerRadius - Theme.generalThickness)
                                    }
                                }
                            }
                        }

                        // Focus window on click
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: focusSelected()
                        }
                    }
                }

                // Empty Workspace State
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.wsToplevels.length === 0
                    spacing: 12

                    IconImage {
                        Layout.alignment: Qt.AlignHCenter
                        implicitSize: 42
                        source: Quickshell.iconPath("preferences-desktop-display")
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No active windows in " + (root.targetWorkspaceName ? root.targetWorkspaceName : ("Workspace " + root.targetWorkspaceId))
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                    }

                    LabelButton {
                        Layout.alignment: Qt.AlignHCenter
                        label: "Switch to Workspace"
                        onPress: {
                            Hypr.focusWorkspace(root.targetWorkspaceId);
                            root.closePreview();
                        }
                    }
                }
            }
        }
    }
}

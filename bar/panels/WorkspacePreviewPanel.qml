import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root

    property var panelHost

    property int targetWorkspaceId: Hypr.activeWsId
    property string targetWorkspaceName: ""
    property int selectedIndex: 0
    property bool isShiftPressed: false

    readonly property var wsToplevels: Hypr.toplevelsForWs(targetWorkspaceId)
    readonly property HyprlandToplevel currentToplevel: {
        if (!wsToplevels || wsToplevels.length === 0)
            return null;
        const idx = Math.max(0, Math.min(selectedIndex, wsToplevels.length - 1));
        return wsToplevels[idx];
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
            }
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

            event.accepted = true; // Prevents default Tab focus-shifting behavior
        }
        Keys.onBacktabPressed: event => {
            const count = root.wsToplevels.length;

            if (count > 1)
                root.selectedIndex = (root.selectedIndex - 1 + count) % count;

            event.accepted = true;
        }
    }

    Rectangle {
        id: card
        width: Theme.workspacePreviewWidth
        height: root.wsToplevels.length > 0 ? Theme.workspacePreviewHeight + (root.wsToplevels.length > 1 ? 46 : 0) : 230
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.dropdownOffset * 2

        color: Theme.bgColor
        border.color: Theme.mutedAccent
        border.width: Theme.generalThickness
        radius: Theme.cornerLargeRadius
        clip: true

        // Prevent clicks inside card from propagating to background dismiss
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        // Scroll / trackpad gesture navigation
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
        Behavior on height {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
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

            // Content Area: Live Screencopy Preview or Empty State
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Active Window Preview Card
                ColumnLayout {
                    anchors.fill: parent
                    visible: root.wsToplevels.length > 0 && root.currentToplevel !== null
                    spacing: 10

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
                                        Hypr.closeWindow(root.currentToplevel.address);
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
                                    font.bold: root.isShiftPressed
                                }
                            }
                        }
                    }

                    // Screencopy Live Preview Frame with Generous Margins
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 4
                        color: Qt.darker(Theme.bgColor, 2)
                        radius: Theme.cornerRadius
                        border.color: Theme.mutedAccent
                        border.width: 1
                        clip: true

                        Item {
                            id: bufferContainer
                            anchors.fill: parent
                            anchors.margins: 8

                            // Track which view is currently active
                            property bool useFirst: true

                            // Store the specific toplevel for each view independently
                            property var toplevel1: root.currentToplevel
                            property var toplevel2: null

                            // Listen for window changes and swap the buffers
                            Connections {
                                target: root
                                function onCurrentToplevelChanged() {
                                    // DO NOT REMOVE THIS LINE. THIS EXCEPTION CAUSES intel GPUS to not MESS UP
                                    fuckassRetardedIntelGPUS = ignoreMe;
                                }
                            }

                            // Buffer 1
                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: parent.toplevel1 ? parent.toplevel1.wayland : null
                                live: parent.useFirst && root.visible
                                paintCursor: true
                                layer.enabled: true

                                opacity: parent.useFirst ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }

                            // Buffer 2
                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: parent.toplevel2 ? parent.toplevel2.wayland : null
                                live: !parent.useFirst && root.visible
                                paintCursor: true
                                layer.enabled: true

                                opacity: !parent.useFirst ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.InOutQuad
                                    }
                                }
                            }
                        }

                        // Clicking anywhere on the preview focuses that window
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

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root
    property var panelHost
    property real barOffset: 0
    property var expandedGroups: ({})

    function openPanel() {
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("notifications");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["notifications"] = root;
    }

    function closePanel() {
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["notifications"] = false;
    }

    function togglePanel() {
        if (visible)
            closePanel();
        else
            openPanel();
    }

    function getGroups() {
        var items = Notifications.items;
        var map = {};
        var groups = [];
        for (var i = 0; i < items.length; i++) {
            var it = items[i];
            var name = it.notif.appName || "Unknown";
            if (!map[name]) {
                map[name] = {
                    appName: name,
                    appIcon: it.notif.appIcon || "",
                    items: [],
                    latestTime: it.time
                };
                groups.push(map[name]);
            }
            map[name].items.push(it);
        }
        if (groups.length > 5) {
            groups = groups.slice(0, 5);
        }
        return groups;
    }

    function formatAppName(name) {
        if (!name)
            return "Unknown";
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    visible: false
    focusable: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closePanel()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closePanel();
                event.accepted = true;
            }
        }
    }

    Item {
        id: card
        x: root.barOffset + Theme.barHorizontalPad
        y: root.visible ? 0 : -14
        width: Theme.notificationPanelWidth
        property real maxHeight: (root.height || 800) - Theme.barHeight - Theme.barVerticalPad * 4
        height: Math.min(48 + 5 + groupColumn.height, maxHeight)
        Behavior on height {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
        Behavior on y {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        visible: root.visible

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.96
        transformOrigin: Item.TopLeft

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

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: mainLayout
            anchors.fill: parent
            spacing: 5

            // Header Box
            Rectangle {
                id: headerRect
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Theme.bgColor
                border.color: Theme.mutedAccent
                border.width: Theme.generalThickness
                radius: Theme.cornerLargeRadius
                clip: true

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 5

                    IconImage {
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: Theme.iconFontSize
                        source: Quickshell.iconPath(Notifications.icon)
                    }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: Notifications.notificationCount > 0 ? "Notifications (" + Notifications.notificationCount + ")" : "No new notifications!"
                        color: Theme.fgColor
                        font.pointSize: Theme.labelFontSize * 1.2
                        font.bold: true
                        font.family: Theme.labelFontFamily
                        elide: Text.ElideRight
                    }
                    LabelButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: Notifications.items.length > 0
                        label: "Clear all"
                        onPress: Notifications.clearAll()
                    }
                    ClickButton {
                        Layout.alignment: Qt.AlignVCenter
                        symbol: "window-close"
                        size: 28
                        bgColor: "transparent"
                        onPress: root.closePanel()
                    }
                }
            }

            // Scrollable Area
            Flickable {
                id: flickArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: groupColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                ColumnLayout {
                    id: groupColumn
                    width: flickArea.width
                    spacing: 5

                    Repeater {
                        model: root.getGroups()

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true

                            property bool expanded: root.expandedGroups[modelData.appName] || false
                            property var groupItems: modelData.items

                            color: "transparent"
                            clip: true

                            Layout.preferredHeight: groupContentLayout.implicitHeight + 16

                            ColumnLayout {
                                id: groupContentLayout
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 5

                                // Group Heading Rectangle
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    color: Theme.bgColor
                                    radius: Theme.cornerRadius
                                    border.color: Theme.mutedAccent
                                    border.width: Theme.generalThickness
                                    clip: true

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var current = root.expandedGroups[modelData.appName] || false;
                                            root.expandedGroups[modelData.appName] = !current;
                                            root.expandedGroupsChanged();
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 5

                                        Text {
                                            Layout.fillWidth: true
                                            text: groupItems.length + " notifications from " + root.formatAppName(modelData.appName)
                                            color: Theme.fgColor
                                            font.pointSize: Theme.labelFontSize * 0.9
                                            font.bold: true
                                            font.family: Theme.labelFontFamily
                                            elide: Text.ElideRight
                                        }

                                        LabelButton {
                                            Layout.alignment: Qt.AlignVCenter
                                            label: "Clear"
                                            onPress: Notifications.clearGroup(modelData.appName)
                                        }

                                        IconImage {
                                            visible: groupItems.length > 1
                                            implicitSize: Theme.iconFontSize * 0.8
                                            source: Quickshell.iconPath(expanded ? "pan-up" : "pan-down")
                                        }
                                    }
                                }

                                // Collapsed Stack View (Vertical Shift)
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: topCard.height + Math.min(groupItems.length - 1, 2) * 6
                                    visible: !expanded && groupItems.length > 1
                                    clip: true
                                    opacity: (!expanded && groupItems.length > 1) ? 1 : 0
                                    scale: (!expanded && groupItems.length > 1) ? 1 : 0.98

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

                                    Repeater {
                                        model: Math.min(groupItems.length - 1, 2)
                                        delegate: NotificationCard {
                                            required property int index
                                            x: 0
                                            y: (index + 1) * 6
                                            width: parent.width
                                            height: topCard.height
                                            opacity: Math.max(0.2, 0.7 - index * 0.25)
                                            z: 3 - index
                                            enabled: false

                                            property var itemData: groupItems[index + 1]
                                            entryKey: itemData.key
                                            summary: itemData.notif.summary
                                            body: itemData.notif.body
                                            appName: itemData.notif.appName
                                            appIcon: itemData.notif.appIcon
                                            image: itemData.notif.image
                                            urgency: itemData.notif.urgency
                                            time: itemData.time
                                            actions: itemData.notif.actions
                                            popupMode: false
                                        }
                                    }

                                    NotificationCard {
                                        id: topCard
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        z: 5
                                        clickable: true
                                        onCardClicked: {
                                            root.expandedGroups[modelData.appName] = true;
                                            root.expandedGroupsChanged();
                                        }

                                        property var itemData: groupItems[0]
                                        entryKey: itemData.key
                                        summary: itemData.notif.summary
                                        body: itemData.notif.body
                                        appName: itemData.notif.appName
                                        appIcon: itemData.notif.appIcon
                                        image: itemData.notif.image
                                        urgency: itemData.notif.urgency
                                        time: itemData.time
                                        actions: itemData.notif.actions
                                        popupMode: false
                                    }
                                }

                                // Expanded View / Single Item View
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 5
                                    visible: expanded || groupItems.length === 1
                                    opacity: (expanded || groupItems.length === 1) ? 1 : 0
                                    scale: (expanded || groupItems.length === 1) ? 1 : 0.98

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

                                    Repeater {
                                        model: groupItems
                                        delegate: NotificationCard {
                                            Layout.fillWidth: true
                                            entryKey: modelData.key
                                            summary: modelData.notif.summary
                                            body: modelData.notif.body
                                            appName: modelData.notif.appName
                                            appIcon: modelData.notif.appIcon
                                            image: modelData.notif.image
                                            urgency: modelData.notif.urgency
                                            time: modelData.time
                                            actions: modelData.notif.actions
                                            popupMode: false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty State Rectangle
                    Rectangle {
                        visible: Notifications.items.length === 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: 64
                        color: Theme.bgColor
                        border.color: Theme.mutedAccent
                        border.width: Theme.generalThickness
                        radius: Theme.cornerLargeRadius
                        clip: true
                        opacity: Notifications.items.length === 0 ? 1 : 0
                        scale: Notifications.items.length === 0 ? 1 : 0.96

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

                        Text {
                            anchors.centerIn: parent
                            text: Notifications.isDndOn ? "Do not disturb is on" : "No new notifications!"
                            color: Theme.mutedFgColor
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}

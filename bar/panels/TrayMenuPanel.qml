import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/"
import "root:/components"

PopupWindow {
    id: root

    property var panelHost
    property real anchorX: 0
    property real anchorY: 0
    property real barOffset: 0
    property QsMenuHandle targetMenu: null
    property string menuTitle: ""
    property bool wasHovered: false

    implicitWidth: menuContainer.width
    implicitHeight: menuContainer.height
    visible: false
    color: "transparent"
    grabFocus: true

    anchor.window: panelHost
    anchor.rect.x: anchorX
    anchor.rect.y: anchorY
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.All

    function openMenu(menuHandle, title, x, y) {
        if (!menuHandle)
            return;
        panelHost.hideAllPanelExcept("traymenu");
        targetMenu = menuHandle;
        menuTitle = title || "";
        anchorX = x;
        anchorY = y;
        while (stackView.depth > 1)
            stackView.pop();
        wasHovered = false;
        closeTimer.stop();
        visible = true;
        if (panelHost.toggledPanels)
            panelHost.toggledPanels["traymenu"] = root;
    }

    function closeMenu() {
        visible = false;
        if (panelHost.toggledPanels)
            panelHost.toggledPanels["traymenu"] = false;
    }
    FocusScope {
        anchors.fill: parent
        focus: root.visible
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (stackView.depth > 1)
                    stackView.pop();
                else
                    root.closeMenu();
                event.accepted = true;
            }
        }
    }

    Item {
        id: menuContainer
        readonly property real maxOffset: root.width > 0 ? (root.width - Theme.trayMenuWidth - Theme.barHorizontalPad) : root.barOffset
        //x: Math.max(Theme.barHorizontalPad, Math.min(root.barOffset, maxOffset))
        y: 0
        width: Theme.trayMenuWidth
        height: stackView.implicitHeight

        opacity: root.visible ? 1 : 0
        scale: root.visible ? 1 : 0.94
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
        Behavior on height {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Behavior on width {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
        Timer {
            id: closeTimer
            interval: 250
            onTriggered: root.closeMenu()
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop();
                    root.wasHovered = true;
                } else if (root.wasHovered) {
                    closeTimer.restart();
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.bgColor
            radius: Theme.cornerRadius
            border.color: Theme.mutedAccent
            border.width: Theme.generalThickness

            clip: true

            StackView {
                id: stackView
                anchors.fill: parent
                implicitHeight: currentItem ? currentItem.contentHeight : 40

                initialItem: SubMenuView {
                    handle: root.targetMenu
                    isRoot: true
                    title: root.menuTitle
                }

                pushEnter: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.effectsDuration
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "x"
                        from: 30
                        to: 0
                        duration: Theme.fastSpatialDuration
                        easing.type: Easing.OutCubic
                    }
                }
                pushExit: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Theme.effectsDuration
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "x"
                        from: 0
                        to: -30
                        duration: Theme.fastSpatialDuration
                        easing.type: Easing.OutCubic
                    }
                }
                popEnter: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.effectsDuration
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "x"
                        from: -30
                        to: 0
                        duration: Theme.fastSpatialDuration
                        easing.type: Easing.OutCubic
                    }
                }
                popExit: Transition {
                    NumberAnimation {
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Theme.effectsDuration
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "x"
                        from: 0
                        to: 30
                        duration: Theme.fastSpatialDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Component {
        id: subMenuComponent
        SubMenuView {}
    }

    component SubMenuView: ColumnLayout {
        id: subMenu
        required property QsMenuHandle handle
        property bool isRoot: false
        property string title: ""

        readonly property int contentHeight: layoutContainer.implicitHeight + 16

        width: Theme.trayMenuWidth
        spacing: 0

        QsMenuOpener {
            id: opener
            menu: subMenu.handle
        }

        ColumnLayout {
            id: layoutContainer
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 3

            // Back button if in a submenu
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.trayMenuItemHeight
                visible: !subMenu.isRoot
                radius: Theme.cornerRadius
                color: backMouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animationDuration
                    }
                }

                MouseArea {
                    id: backMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stackView.pop()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 6

                    IconImage {
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: 16
                        source: Quickshell.iconPath("go-previous")
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: subMenu.title ? subMenu.title : "Back"
                        color: Theme.accent
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.mutedAccent
                opacity: 0.4
                visible: !subMenu.isRoot
            }

            Repeater {
                model: opener.children

                delegate: Rectangle {
                    id: entryItem
                    required property QsMenuEntry modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: modelData.isSeparator ? 1 : Theme.trayMenuItemHeight
                    radius: Theme.cornerRadius
                    color: {
                        if (modelData.isSeparator)
                            return Theme.mutedAccent;
                        return itemMouse.containsMouse && modelData.enabled ? Theme.hoveredBgColor : "transparent";
                    }
                    opacity: modelData.isSeparator ? 0.4 : (modelData.enabled ? 1.0 : 0.4)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animationDuration
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        enabled: !entryItem.modelData.isSeparator && entryItem.modelData.enabled
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (entryItem.modelData.hasChildren) {
                                stackView.push(subMenuComponent, {
                                    handle: entryItem.modelData,
                                    isRoot: false,
                                    title: entryItem.modelData.text
                                });
                            } else {
                                entryItem.modelData.triggered();
                                root.closeMenu();
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8
                        visible: !entryItem.modelData.isSeparator

                        IconImage {
                            Layout.alignment: Qt.AlignVCenter
                            implicitSize: 18
                            visible: !!entryItem.modelData.icon
                            source: {
                                const icon = entryItem.modelData.icon;
                                if (!icon)
                                    return "";
                                // Already a URL (image://, file://, qrc:/ ...), use as-is
                                if (icon.includes("://") || icon.startsWith("/"))
                                    return icon;
                                // Otherwise treat it as a theme icon name
                                return Quickshell.iconPath(icon, true);
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: entryItem.modelData.text
                            color: Theme.fgColor
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            elide: Text.ElideRight
                        }

                        IconImage {
                            Layout.alignment: Qt.AlignVCenter
                            implicitSize: 14
                            source: Quickshell.iconPath("go-next")
                            visible: entryItem.modelData.hasChildren
                        }
                    }
                }
            }

            // Empty state if no menu items
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                visible: opener.children.values.length === 0
                text: "No menu items"
                color: Theme.mutedFgColor
                font.pointSize: Theme.labelFontSize
                font.family: Theme.labelFontFamily
            }
        }
    }
}

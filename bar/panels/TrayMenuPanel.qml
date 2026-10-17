import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/"
import "root:/components"

PanelWindow {
    id: root

    property var panelHost
    //screen: panelHost ? panelHost.screen : null
    property real barOffset: 0
    property QsMenuHandle targetMenu: null
    property string menuTitle: ""

    function openMenu(menuHandle, title, offset) {
        if (!menuHandle)
            return;
        panelHost.hideAllPanelExcept("traymenu");
        targetMenu = menuHandle;
        menuTitle = title || "";
        barOffset = offset || 0;

        // Reset stack view to root menu
        while (stackView.depth > 1) {
            stackView.pop();
        }

        visible = true;
        if (panelHost.toggledPanels)
            panelHost.toggledPanels["traymenu"] = root;
    }

    function closeMenu() {
        visible = false;
        if (panelHost.toggledPanels)
            panelHost.toggledPanels["traymenu"] = false;
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

    // Dismiss on clicking outside
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeMenu()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (stackView.depth > 1) {
                    stackView.pop();
                } else {
                    root.closeMenu();
                }
                event.accepted = true;
            }
        }
    }

    Item {
        id: menuContainer
        readonly property real maxOffset: root.width > 0 ? (root.width - Theme.trayMenuWidth - Theme.barHorizontalPad) : root.barOffset
        x: Math.max(Theme.barHorizontalPad, Math.min(root.barOffset, maxOffset))
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
                            source: entryItem.modelData.icon ? Quickshell.iconPath(entryItem.modelData.icon) : ""
                            visible: entryItem.modelData.icon !== ""
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

import QtQuick
import QtQuick.Controls
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Quickshell
import "root:/"
import "root:/components"

Rectangle {
    required property SystemTrayItem modelData
    required property var panelHost
    property var menuLoader: null

    // Returns the loaded menu popup, or null if unavailable
    function getMenu() {
        if (!modelData.hasMenu || !menuLoader)
            return null;
        menuLoader.active = true;
        return menuLoader.item;
    }

    function isMenuOpen(menu) {
        return menu.visible && menu.targetMenu === modelData.menu;
    }

    function showMenu(menu) {
        // Position relative to the bar window, just below this icon
        const p = mapToItem(panelHost.contentItem, 0, 0);
        menu.openMenu(modelData.menu, modelData.title || modelData.id, p.x, p.y + height + 4);
    }

    function toggleMenu() {
        const menu = getMenu();
        if (!menu)
            return;

        if (isMenuOpen(menu))
            menu.closeMenu();
        else
            showMenu(menu);
    }

    function openMenu() {
        const menu = getMenu();
        if (!menu)
            return;

        if (!isMenuOpen(menu))
            showMenu(menu);
    }

    function closeMenu() {
        const menu = getMenu();
        if (!menu)
            return;

        if (isMenuOpen(menu))
            menu.closeMenu();
    }
    height: parent.height
    width: this.height
    radius: Theme.cornerRadius
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
    Behavior on color {
        CAnim {}
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: openMenu()
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                if (modelData.hasMenu && menuLoader) {
                    toggleMenu();
                } else if (modelData.hasMenu) {
                    const p = panelHost ? mapToItem(panelHost.contentItem, 0, 0) : Qt.point(0, 0);
                    modelData.display(panelHost, Math.max(0, p.x), Theme.barHeight + Theme.barHorizontalPad / 2);
                }
                return;
            }

            if (mouse.button === Qt.LeftButton) {
                if (modelData.onlyMenu && modelData.hasMenu && menuLoader) {
                    toggleMenu();
                    return;
                }
                modelData.activate();
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                modelData.secondaryActivate();
            }
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y !== 0)
                modelData.scroll(wheel.angleDelta.y, false);
            if (wheel.angleDelta.x !== 0)
                modelData.scroll(wheel.angleDelta.x, true);
        }
    }
    IconImage {
        anchors.centerIn: parent
        implicitSize: Theme.iconFontSize
        source: modelData.icon || Quickshell.iconPath("application-x-executable", true)
    }
}

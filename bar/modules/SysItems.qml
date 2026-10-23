import QtQuick
import Quickshell
import "root:/"
import "root:/components"
import "root:/services"
import "root:/bar/panels"

Rectangle {
    id: root
    clip: true
    required property var panelHost

    // Hide the whole pill when every system chip has been disabled.
    readonly property var screen: panelHost ? panelHost.screen : null
    readonly property bool brightnessVisible: Theme.moduleBrightness && Brightness.supportsScreen(screen)
    visible: Theme.moduleNotifications || Theme.moduleSound || Theme.moduleWifi || Theme.moduleBluetooth || brightnessVisible

    function registerPanel(name, panel, visible) {
        if (visible)
            panelHost.toggledPanels[name] = panel;
        else
            panelHost.toggledPanels[name] = false;
    }

    function toggleSoundPanel() {
        soundLoader.active = true;
        const panel = soundLoader.item;
        panelHost.hideAllPanelExcept("sound");
        panel.visible = !panel.visible;
        soundChip.keepExpanded();
        registerPanel("sound", panel, panel.visible);
    }
    function toggleWifiPanel() {
        wifiLoader.active = true;
        const panel = wifiLoader.item;
        panelHost.hideAllPanelExcept("wifi");
        panel.visible = !panel.visible;
        wifiChip.keepExpanded();
        registerPanel("wifi", panel, panel.visible);
    }
    function toggleBluetoothPanel() {
        bluetoothLoader.active = true;
        const panel = bluetoothLoader.item;
        panelHost.hideAllPanelExcept("bluetooth");
        panel.visible = !panel.visible;
        bluetoothChip.keepExpanded();
        registerPanel("bluetooth", panel, panel.visible);
    }
    function toggleBrightnessPanel() {
        brightnessLoader.active = true;
        const panel = brightnessLoader.item;
        panelHost.hideAllPanelExcept("brightness");
        panel.visible = !panel.visible;
        brightnessChip.keepExpanded();
        registerPanel("brightness", panel, panel.visible);
    }
    function toggleNotificationPanel() {
        notifLoader.active = true;
        const panel = notifLoader.item;
        panelHost.hideAllPanelExcept("notifications");
        panel.visible = !panel.visible;
        notifChip.keepExpanded();
        registerPanel("notifications", panel, panel.visible);
    }
    function openSoundPanel() {
        soundLoader.active = true;
        const panel = soundLoader.item;
        panelHost.hideAllPanelExcept("sound");
        panel.visible = true;
        soundChip.keepExpanded();
        registerPanel("sound", panel, true);
    }

    width: container.width + 32
    Behavior on width {
        Anim {
            type: Anim.FastEffects
        }
    }
    color: Theme.bgColor
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight

    Row {
        id: container
        function getSpacingDistance() {
            return panelHost ? container.mapToItem(panelHost.contentItem, 0, 0).x : container.mapToGlobal(0, 0).x;
        }
        anchors.centerIn: parent
        spacing: 5

        BarChip {
            id: notifChip
            visible: Theme.moduleNotifications
            extraButtons: Qt.RightButton
            iconName: Notifications.barIcon
            label: Notifications.nullableMessage
            onRightClicked: Notifications.toggleDnd()
            onLeftClicked: root.toggleNotificationPanel()
        }
        BarChip {
            id: soundChip
            visible: Theme.moduleSound
            extraButtons: Qt.RightButton
            iconName: PipewireResolve.outputIcon
            label: PipewireResolve.status
            onLeftClicked: root.toggleSoundPanel()
        }
        BarChip {
            id: wifiChip
            visible: Theme.moduleWifi
            iconName: INetwork.networkStrengthIcon
            label: INetwork.connectionMessage
            onLeftClicked: root.toggleWifiPanel()
        }
        BarChip {
            id: bluetoothChip
            visible: Theme.moduleBluetooth
            iconName: BluetoothResolve.icon
            label: BluetoothResolve.status
            onLeftClicked: root.toggleBluetoothPanel()
        }
        BarChip {
            id: brightnessChip
            visible: root.brightnessVisible
            iconName: Brightness.iconForScreen(root.screen)
            iconColor: Theme.fgColor
            label: Brightness.statusForScreen(root.screen)
            onLeftClicked: root.toggleBrightnessPanel()
            onWheeled: direction => Brightness.adjustMonitor(Brightness.monitorForScreen(root.screen), direction * Brightness.step)
        }
    }

    LazyLoader {
        id: soundLoader
        loading: true
        SoundPanel {
            panelHost: root.panelHost
            barOffset: container.getSpacingDistance()
        }
    }
    LazyLoader {
        id: wifiLoader
        loading: true
        WifiPanel {
            panelHost: root.panelHost
            barOffset: container.getSpacingDistance()
        }
    }
    LazyLoader {
        id: bluetoothLoader
        loading: true
        BluetoothPanel {
            panelHost: root.panelHost
            barOffset: container.getSpacingDistance()
        }
    }
    LazyLoader {
        id: brightnessLoader
        loading: true
        BrightnessPanel {
            panelHost: root.panelHost
            barOffset: container.getSpacingDistance()
        }
    }
    LazyLoader {
        id: notifLoader
        loading: true
        NotificationPanel {
            panelHost: root.panelHost
            barOffset: container.getSpacingDistance()
        }
    }
}

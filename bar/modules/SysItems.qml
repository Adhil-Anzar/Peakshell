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
            extraButtons: Qt.RightButton
            iconName: Swaync.icon
            label: Swaync.nullableMessage
            onRightClicked: Swaync.toggleDnd()
            onLeftClicked: {
                panelHost.hideAllPanelExcept("notifications");
                Swaync.togglePanel();
            }
        }
        BarChip {
            id: soundChip
            extraButtons: Qt.RightButton
            iconName: PipewireResolve.outputIcon
            label: PipewireResolve.status
            onLeftClicked: root.toggleSoundPanel()
        }
        BarChip {
            id: wifiChip
            iconName: INetwork.networkStrengthIcon
            label: INetwork.connectionMessage
            onLeftClicked: root.toggleWifiPanel()
        }
        BarChip {
            id: bluetoothChip
            iconName: BluetoothResolve.icon
            label: BluetoothResolve.status
            onLeftClicked: root.toggleBluetoothPanel()
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
}

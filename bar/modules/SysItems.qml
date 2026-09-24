import QtQuick
import Quickshell
import "root:/"
import "root:/components"
import "root:/services"
import "root:/bar/panels"

Rectangle {
    id: root
    required property var panelHost

    function registerPanel(name, panel, visible) {
        if (visible)
            panelHost.toggledPanels[name] = panel
        else
            panelHost.toggledPanels[name] = false
    }

    function toggleSoundPanel() {
        panelHost.hideAllPanelExcept("sound")
        soundPanel.visible = !soundPanel.visible
        soundChip.keepExpanded()
        registerPanel("sound", soundPanel, soundPanel.visible)
    }
    function toggleWifiPanel() {
        panelHost.hideAllPanelExcept("wifi")
        wifiPanel.visible = !wifiPanel.visible
        wifiChip.keepExpanded()
        registerPanel("wifi", wifiPanel, wifiPanel.visible)
    }
    function toggleBluetoothPanel() {
        panelHost.hideAllPanelExcept("bluetooth")
        bluetoothPanel.visible = !bluetoothPanel.visible
        bluetoothChip.keepExpanded()
        registerPanel("bluetooth", bluetoothPanel, bluetoothPanel.visible)
    }
    function openSoundPanel() {
        panelHost.hideAllPanelExcept("sound")
        soundPanel.visible = true
        soundChip.keepExpanded()
        registerPanel("sound", soundPanel, true)
    }

    width: container.width + 32
    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutExpo
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
            return container.mapToGlobal(0, 0).x
        }
        anchors.centerIn: parent
        spacing: 5

        BarChip {
            extraButtons: Qt.RightButton
            iconName: Swaync.icon
            label: Swaync.nullableMessage
            onRightClicked: Swaync.toggleDnd()
            onLeftClicked: {
                panelHost.hideAllPanelExcept("notifications")
                Swaync.togglePanel()
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

    SoundPanel {
        id: soundPanel
        panelHost: root.panelHost
        barOffset: container.getSpacingDistance()
    }
    WifiPanel {
        id: wifiPanel
        panelHost: root.panelHost
        barOffset: container.getSpacingDistance()
    }
    BluetoothPanel {
        id: bluetoothPanel
        panelHost: root.panelHost
        barOffset: container.getSpacingDistance()
    }
}

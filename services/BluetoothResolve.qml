pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    property string status: {
        if (connectedDevices.length > 0)
            return connectedDevices[0].name
        return bluetoothEnabled ? "Enabled" : "Disabled"
    }

    property var connectedDevices: {
        const devs = []
        if (!Bluetooth.defaultAdapter)
            return devs
        for (let i = 0; i < Bluetooth.defaultAdapter.devices.values.length; ++i) {
            const dev = Bluetooth.defaultAdapter.devices.values[i]
            if (dev.connected)
                devs.push(dev)
        }
        return devs
    }

    property var bondedDevices: {
        const devs = []
        if (!Bluetooth.defaultAdapter)
            return devs
        for (let i = 0; i < Bluetooth.defaultAdapter.devices.values.length; ++i) {
            const dev = Bluetooth.defaultAdapter.devices.values[i]
            if (dev.bonded && !dev.connected)
                devs.push(dev)
        }
        return devs
    }

    property var otherDevices: {
        const devs = []
        if (!Bluetooth.defaultAdapter)
            return devs
        for (let i = 0; i < Bluetooth.defaultAdapter.devices.values.length; ++i) {
            const dev = Bluetooth.defaultAdapter.devices.values[i]
            if (!dev.bonded && dev.state === BluetoothDeviceState.Disconnected)
                devs.push(dev)
        }
        return devs
    }

    property string icon: {
        if (!bluetoothEnabled)
            return "bluetooth-disabled"
        if (connectedDevices.length > 0)
            return "bluetooth-paired"
        return "bluetooth-active"
    }

    property bool bluetoothEnabled: Bluetooth.defaultAdapter?.enabled ?? false

    function setBluetooth(enabled) {
        if (!Bluetooth.defaultAdapter)
            return
        Bluetooth.defaultAdapter.enabled = enabled
        if (enabled)
            Bluetooth.defaultAdapter.discovering = true
    }
    function disconnect(dev) {
        dev.disconnect()
    }
    function forget(dev) {
        dev.forget()
    }
    function connect(dev) {
        dev.connect()
    }
    function setDiscovering(enabled) {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.discovering = enabled
    }
    function pair(dev) {
        dev.pair()
    }
}

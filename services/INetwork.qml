pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root
    property bool isNetworkAvailable: Networking.connectivity === NetworkConnectivity.Full

    property NetworkDevice wifiDevice: {
        for (let i = 0; i < Networking.devices.values.length; ++i) {
            if (Networking.devices.values[i] instanceof WifiDevice)
                return Networking.devices.values[i];
        }
        return null;
    }
    property var wiredDevice: {
        for (let i = 0; i < Networking.devices.values.length; ++i) {
            if (Networking.devices.values[i] instanceof WiredDevice)
                return Networking.devices.values[i];
        }
        return null;
    }

    property Network connectedWiredNetwork: {
        if (!wiredDevice)
            return null;
        for (let i = 0; i < wiredDevice.networks.values.length; ++i) {
            const network = wiredDevice.networks.values[i];
            if (network.connected)
                return network;
        }
        return null;
    }
    property WifiNetwork connectedWifiNetwork: {
        if (!wifiDevice)
            return null;
        for (let i = 0; i < wifiDevice.networks.values.length; ++i) {
            const network = wifiDevice.networks.values[i];
            if (network.connected)
                return network;
        }
        return null;
    }

    property string networkStrengthIcon: {
        if (connectedWiredNetwork)
            return "network-wired-activated";
        if (connectedWifiNetwork) {
            const strength = Math.max(0, Math.min(1, connectedWifiNetwork.signalStrength));
            const percent = Math.round(strength * 4) * 25;
            return "network-wireless-connected-" + percent;
        }
        return "network-wireless-available";
    }
    property string connectionMessage: {
        if (connectedWiredNetwork)
            return "Wired";
        if (connectedWifiNetwork)
            return connectedWifiNetwork.name;
        return "Disconnected";
    }

    property var connectedNetworks: {
        const nets = [];
        if (wifiDevice) {
            for (let i = 0; i < wifiDevice.networks.values.length; ++i) {
                if (wifiDevice.networks.values[i].connected)
                    nets.push(wifiDevice.networks.values[i]);
            }
        }
        if (wiredDevice) {
            for (let j = 0; j < wiredDevice.networks.values.length; ++j) {
                if (wiredDevice.networks.values[j].connected)
                    nets.push(wiredDevice.networks.values[j]);
            }
        }
        return nets;
    }
    property var knownLocalWifies: {
        const nets = [];
        if (wifiDevice) {
            for (let i = 0; i < wifiDevice.networks.values.length; ++i) {
                const network = wifiDevice.networks.values[i];
                if (network.known && !network.connected)
                    nets.push(network);
            }
        }
        return nets;
    }
    property var unknownLocalWifies: {
        const nets = [];
        if (wifiDevice) {
            for (let i = 0; i < wifiDevice.networks.values.length; ++i) {
                const network = wifiDevice.networks.values[i];
                if (!network.known)
                    nets.push(network);
            }
        }
        nets.sort((a, b) => b.signalStrength - a.signalStrength);
        return nets;
    }

    function setWifi(enabled) {
        Networking.wifiEnabled = enabled;
        Networking.connectivityCheckEnabled = enabled;
        if (enabled) {
            Networking.checkConnectivity();
            if (wifiDevice)
                wifiDevice.scannerEnabled = true;
        }
    }
    function getStrengthOnlyIcon(wifiNetwork) {
        if (!wifiNetwork)
            return "network-wireless-available";
        const strength = Math.max(0, Math.min(1, wifiNetwork.signalStrength));
        const percent = Math.round(strength * 5) * 20;
        const securityStr = (wifiNetwork.security === WifiSecurityType.Open || wifiNetwork.security === WifiSecurityType.Owe) ? "" : "-locked";
        return "network-wireless-" + percent + securityStr;
    }
    function connectKnownWifi(network) {
        const settings = network.nmSettings.values;
        for (let i = 0; i < settings.length; ++i)
            network.connectWithSettings(settings[i]);
    }
    function setScan(enabled) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = enabled;
    }
    function connectUnknownWifi(network) {
        network.connect();
        network.connectionFailed.connect(function (reason) {
            console.log("Failed to connect: " + ConnectionFailReason.toString(reason));
            network.forget();
        });
    }
    function forgetWifi(network) {
        network.forget();
    }
    function disconnect(network) {
        network.disconnect();
        Networking.checkConnectivity();
    }
}

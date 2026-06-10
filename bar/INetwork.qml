pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root
    property bool isNetworkAvailable: {
        return Networking.connectivity === NetworkConnectivity.Full
    }

    property NetworkDevice wifiDevice: {
        //console.log("============================");
        //console.log("Devices Plugged: " + Networking.devices.values.length)
        for ( let i = 0; i <= Networking.devices.values.length; ++i ) {
            //remove ts maybe
            //console.log(`${Networking.devices.values[i].name} : ${Networking.devices.values[i].connected} :: ${Networking.devices.values[i].autoconnect}`)
            //if (!Networking.devices.values[i].connected) continue;
            if (Networking.devices.values[i] instanceof WifiDevice) {
                //console.log(`${Networking.devices.values[i].name} : ${Networking.devices.values[i].scannerEnabled}`);
                Networking.devices.values[i].scannerEnabled = true;
                return Networking.devices.values[i];
            }
        }
        return null
    }
    property NetworkDevice wiredDevice: {
        for ( let i = 0; i < Networking.devices.values.length; ++i ) {
            //if (!Networking.devices.values[i].connected) continue;
            if (Networking.devices.values[i] instanceof WiredDevice)
                return Networking.devices.values[i];
            return null
        }
    }

    property Network connectedWiredNetwork: {
        if (!wiredDevice) return null;
        for ( let i = 0; i < wiredDevice.networks.values.length; ++i ) {
            const network = wiredDevice.networks.values[i];
            if (network.connected) {
                return network
            }
        }
        return null
    }
    property WifiNetwork connectedWifiNetwork: {
        for ( let i = 0; i < wifiDevice.networks.values.length; ++i ) {
            const network = wifiDevice.networks.values[i];
            if (network.connected) {
                return network
            }
        }
        return null
    }

    property string networkStrengthIcon: {
        if (connectedWiredNetwork) {
            return "network-wired-activated";
        }

        if (connectedWifiNetwork) {
            const strength = Math.max(0, Math.min(1, connectedWifiNetwork.signalStrength))
            const percent = Math.round(strength * 4) * 25
            //const securityStr = (item.security === WifiSecurityType.Open || item.security === WifiSecurityType.Owe) ? "" : "-locked"
            const iconName = "network-wireless-connected-" + percent
            return iconName
        }
        return "network-wireless-available"
    }
    property string connectionMessage: {
        if (connectedWiredNetwork) {
            return "ffast wired c:"
        }

        if (connectedWifiNetwork) {
            return connectedWifiNetwork.name;
        }
        return "Disconnected :c"
    }

    property var connectedNetworks: {
        var nets = [];
        for ( let i = 0; i < wifiDevice.networks.values.length; ++i ) {
            const wifiNetwork = wifiDevice.networks.values[i];
            if (wifiNetwork.connected) {
                nets.push(wifiNetwork)
            }
        }
        if (wiredDevice) {
            for ( let j = 0; j < wiredDevice.networks.values.length; ++j ) {
                const wiredNetwork = wiredDevice.networks.values[j];
                if (wiredNetwork.connected) {
                    nets.push(wiredNetwork)
                }
            }
        }
        return nets
    }
    property var knownLocalWifies: {
        var nets = [];
        for ( let i = 0; i < wifiDevice.networks.values.length; ++i ) {
            const network = wifiDevice.networks.values[i];
            if (network.known && !network.connected) {
                nets.push(network)
            }
        }
        return nets
    }
    property var unknownLocalWifies: {
        const nets = [];
        for ( let i = 0; i < wifiDevice.networks.values.length; ++i ) {
            const network = wifiDevice.networks.values[i];
            if (!network.known) {
                nets.push(network)
            }
        }
        nets.sort(function(a, b) {
            return b.signalStrength - a.signalStrength;
        });
        return nets
    }
    // onUnknownLocalWifiesChanged: {
    //     const current = {}; // "name": network

    //     for ( let i = 0; unknownLocalWifies.length > i; ++i ) {
    //         current[unknownLocalWifies[i].name] = unknownLocalWifies[i]
    //     }

    //     for ( let j = unknownLocalWifiesModel.length - 1; j >= 0; --j ) {
    //         const item = unknownLocalWifiesModel[j];
    //         //if (!item) continue
    //         if (!(unknownLocalWifiesModel[j].name in current)) {
    //             unknownLocalWifiesModel.pop(j);
    //         }
    //     }

    //     for ( let k = 0; unknownLocalWifies.length > k; ++k ) {
    //         const item = unknownLocalWifiesModel[k]
    //         if (!item) {
    //             unknownLocalWifiesModel.push(current[unknownLocalWifies[k].name])
    //         }
    //         else if (item.name in current) {
    //             unknownLocalWifiesModel[k] = current[unknownLocalWifies[k].name];
    //         }
    //     }
    //     unknownLocalWifiesModel = unknownLocalWifiesModel.concat([]);
    // }
    // property var unknownLocalWifiesModel: [];
    // onUnknownLocalWifiesModelChanged: {
    //     console.log("changed")
    // }

    function setWifi(bool){
        Networking.wifiEnabled = bool;
        Networking.connectivityCheckEnabled = bool
        if (bool){
            Networking.checkConnectivity();
            wifiDevice.scannerEnabled = true;
        }
    }
    function getStrengthOnlyIcon(wifiNetwork) {
        const strength = Math.max(0, Math.min(1, wifiNetwork.signalStrength))
        const percent = Math.round(strength * 5) * 20
        const securityStr = (wifiNetwork.security === WifiSecurityType.Open || wifiNetwork.security === WifiSecurityType.Owe) ? "" : "-locked"
        const iconName = "network-wireless-" + percent + securityStr
        return iconName
    }
    function getStrengthOnlyIconFromString(percent, security) {
        percent = Math.round(percent / 100 * 5) * 20
        const securityStr = (security === WifiSecurityType.toString(WifiSecurityType.Open) || security === WifiSecurityType.toString(WifiSecurityType.Owe)) ? "" : "-locked"
        const iconName = "network-wireless-" + percent + securityStr
        //console.log(iconName)
        return iconName
    }
    function connectKnownWifi(network) {
        console.log("Begin connecting...")
        for (const item of network.nmSettings.values()) {
            console.log(`UUID ${item.uuid}\n\t\t  ID: ${item.id}`)
            network.connectWithSettings(item);
        }
    }


    function connectUnknownWifi(network) {
        network.connect();

        network.connectionFailed.connect( function(reason) {
            console.log("Failed to connect: " + ConnectionFailReason.toString(reason));
            network.forget();
        })
    }

    function forgetWifi(network) {
        network.forget();
    }

    function disconnect(network) {
        network.disconnect();
        //network.device.autoconnect = true;
        Networking.checkConnectivity();
    }

}

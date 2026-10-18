pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// What kind of machine the shell is running on.
//
// Laptop-only UI (battery readout, power profiles, low battery warning) should
// not appear on a desktop, so the shell has to tell them apart. Neither source
// is reliable on its own:
//
//   * a battery (via UPower) is the ground truth for "there is something worth
//     showing", but a laptop whose battery driver is missing reports none;
//   * the SMBIOS chassis type covers that case, but some boards report a wrong
//     or missing chassis type.
//
// So a battery or a portable chassis means laptop, a chassis that positively
// names a desktop means desktop, and anything else stays "unknown". Unknown is
// treated as a laptop: showing UI on a machine we cannot identify is better
// than hiding working UI on a laptop.
//
// PEAKSHELL_FORM_FACTOR=laptop|desktop in the environment overrides detection,
// for hardware that reports the wrong chassis type.
Singleton {
    id: root

    // SMBIOS chassis types describing a portable machine (DMI spec 7.4.1).
    readonly property var portableChassisTypes: [8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32]
    // ... and the ones describing a stationary one.
    readonly property var desktopChassisTypes: [3, 4, 5, 6, 7, 15, 16, 17, 23, 24, 35, 36]

    readonly property bool hasBattery: !!(UPower.displayDevice && UPower.displayDevice.isPresent)

    readonly property int chassisType: {
        const value = parseInt(String(chassisFile.text()).trim(), 10);
        return isNaN(value) ? 0 : value;
    }
    readonly property bool chassisIsPortable: root.portableChassisTypes.includes(root.chassisType)
    readonly property bool chassisIsDesktop: root.desktopChassisTypes.includes(root.chassisType)

    readonly property string override: {
        const value = Quickshell.env("PEAKSHELL_FORM_FACTOR");
        if (value === undefined || value === null)
            return "";
        const text = String(value).trim().toLowerCase();
        return (text === "laptop" || text === "desktop") ? text : "";
    }

    readonly property string formFactor: {
        if (root.override !== "")
            return root.override;
        if (root.hasBattery || root.chassisIsPortable)
            return "laptop";
        return root.chassisIsDesktop ? "desktop" : "unknown";
    }

    readonly property bool isLaptop: root.formFactor === "laptop"
    readonly property bool isDesktop: root.formFactor === "desktop"

    FileView {
        id: chassisFile
        path: "/sys/class/dmi/id/chassis_type"
        blockLoading: true
    }

    // Diagnostic line: what was decided and why. UPower publishes its devices
    // asynchronously, so a boot can log more than once while the inputs settle.
    Component.onCompleted: root.reportFormFactor()
    onFormFactorChanged: root.reportFormFactor()
    onHasBatteryChanged: root.reportFormFactor()

    function reportFormFactor() {
        console.info("platform: " + root.formFactor
            + " (battery: " + root.hasBattery
            + ", chassis: " + (root.chassisType || "unknown")
            + (root.override ? ", override: " + root.override : "") + ")");
    }
}

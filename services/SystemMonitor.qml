pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import PeakShell.Services

Singleton {
    id: root

    // Keep the native C++ service polling while this wrapper exists.
    ServiceRef {
        service: SystemMonitor
    }

    // CPU/GPU metrics come from the native C++ SystemMonitor singleton.
    readonly property int cpuLoad: SystemMonitor.cpuLoad
    readonly property int cpuTemp: SystemMonitor.cpuTemp
    readonly property int gpuTemp: SystemMonitor.gpuTemp
    readonly property int memUsage: SystemMonitor.memUsage

    readonly property bool hasBattery: UPower.displayDevice && UPower.displayDevice.isPresent
    readonly property real batteryPercent: hasBattery ? Math.round(UPower.displayDevice.percentage * 100) : 100
    readonly property bool isBatteryCritical: UPower.onBattery && (batteryPercent < 20)

    readonly property string batteryTimeStr: {
        if (!hasBattery)
            return "";
        const dev = UPower.displayDevice;
        if (UPower.onBattery) {
            const s = dev.timeToEmpty;
            if (s > 0)
                return formatSeconds(s);
        } else {
            const s = dev.timeToFull;
            if (s > 0)
                return formatSeconds(s);
        }
        return "";
    }

    function formatSeconds(s) {
        if (!s || s <= 0)
            return "";
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (h > 0)
            return h + "h " + m + "m";
        if (m > 0)
            return m + "m";
        return Math.floor(s) + "s";
    }

    readonly property bool isCpuLoadCritical: cpuLoad > 90
    readonly property bool isCpuTempCritical: cpuTemp >= 85
    readonly property bool isGpuTempCritical: gpuTemp >= 85
    readonly property bool isCritical: isCpuLoadCritical || isCpuTempCritical || isGpuTempCritical || isBatteryCritical

    readonly property string criticalMessage: {
        let parts = [];
        if (isCpuLoadCritical)
            parts.push("CPU " + cpuLoad + "%");
        if (isCpuTempCritical)
            parts.push("CPU " + cpuTemp + "°C");
        if (isGpuTempCritical)
            parts.push("GPU " + gpuTemp + "°C");
        if (isBatteryCritical) {
            let bat = "BAT " + batteryPercent + "%";
            if (batteryTimeStr)
                bat += " (" + batteryTimeStr + ")";
            parts.push(bat);
        }
        return parts.join(" • ");
    }

    readonly property string criticalIcon: {
        if (isBatteryCritical)
            return "battery-caution";
        if (isCpuTempCritical || isGpuTempCritical)
            return "temperature-high";
        return "indicator-sensors-cpu";
    }
}

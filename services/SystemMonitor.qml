pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    property int cpuLoad: 0
    property int cpuTemp: 0
    property int gpuTemp: 0

    readonly property bool hasBattery: UPower.displayDevice && UPower.displayDevice.isPresent
    readonly property real batteryPercent: hasBattery ? Math.round(UPower.displayDevice.percentage * 100) : 100
    readonly property bool isBatteryCritical: UPower.onBattery && (batteryPercent < 20)

    // Battery time remaining (seconds from UPower, formatted here)
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

    // Icon priority: battery > temp > cpu load
    readonly property string criticalIcon: {
        if (isBatteryCritical)
            return "battery-caution";
        if (isCpuTempCritical || isGpuTempCritical)
            return "temperature-high";
        return "indicator-sensors-cpu";
    }

    Process {
        id: monitorProc
        running: true
        command: ["bash", "-c", "prev_idle=0; prev_total=0; while true; do " + "read -r cpu u n s idle iowait irq softirq steal rest < /proc/stat; " + "total=$((u + n + s + idle + iowait + irq + softirq + steal)); " + "idle_time=$((idle + iowait)); " + "cpu_usage=0; " + "if [ \"$prev_total\" -gt 0 ]; then " + "diff_total=$((total - prev_total)); " + "diff_idle=$((idle_time - prev_idle)); " + "if [ \"$diff_total\" -gt 0 ]; then " + "diff_used=$((diff_total - diff_idle)); " + "cpu_usage=$((diff_used * 100 / diff_total)); " + "fi; " + "fi; " + "prev_total=$total; prev_idle=$idle_time; " + "cpu_temp=0; " + "for f in /sys/class/hwmon/hwmon*/temp*_input; do " + "d=$(dirname \"$f\"); name=\"\"; " + "if [ -f \"$d/name\" ]; then name=$(cat \"$d/name\" 2>/dev/null); fi; " + "if [ \"$name\" = \"coretemp\" ] || [ \"$name\" = \"k10temp\" ] || [ \"$name\" = \"zenpower\" ] || [ \"$name\" = \"legion_hwmon\" ]; then " + "t=$(cat \"$f\" 2>/dev/null); " + "if [ -n \"$t\" ] && [ \"$t\" -gt 0 ]; then " + "deg=$((t / 1000)); " + "if [ \"$deg\" -gt \"$cpu_temp\" ]; then cpu_temp=$deg; fi; " + "fi; fi; done; " + "if [ \"$cpu_temp\" -eq 0 ]; then " + "for f in /sys/class/thermal/thermal_zone*/temp; do " + "t=$(cat \"$f\" 2>/dev/null); " + "if [ -n \"$t\" ] && [ \"$t\" -gt 0 ]; then " + "deg=$((t / 1000)); " + "if [ \"$deg\" -gt \"$cpu_temp\" ]; then cpu_temp=$deg; fi; " + "fi; done; fi; " + "gpu_temp=0; " + "if command -v nvidia-smi >/dev/null 2>&1; then " + "nv=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '); " + "if [ -n \"$nv\" ] && [ \"$nv\" -gt 0 ] 2>/dev/null; then gpu_temp=$nv; fi; " + "fi; " + "if [ \"$gpu_temp\" -eq 0 ]; then " + "for f in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do " + "t=$(cat \"$f\" 2>/dev/null); " + "if [ -n \"$t\" ] && [ \"$t\" -gt 0 ]; then " + "deg=$((t / 1000)); " + "if [ \"$deg\" -gt \"$gpu_temp\" ]; then gpu_temp=$deg; fi; " + "fi; done; fi; " + "echo \"{\\\"cpuUsage\\\":$cpu_usage,\\\"cpuTemp\\\":$cpu_temp,\\\"gpuTemp\\\":$gpu_temp}\"; " + "sleep 1; " + "done"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const text = data.trim();
                    if (text.length > 0 && text.startsWith("{")) {
                        const obj = JSON.parse(text);
                        if (obj.cpuUsage !== undefined)
                            root.cpuLoad = obj.cpuUsage;
                        if (obj.cpuTemp !== undefined)
                            root.cpuTemp = obj.cpuTemp;
                        if (obj.gpuTemp !== undefined)
                            root.gpuTemp = obj.gpuTemp;
                    }
                } catch (e) {
                    console.warn("SystemMonitor parse error:", e);
                }
            }
        }
    }
}

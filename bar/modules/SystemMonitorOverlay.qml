import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Io
import "root:/"
import PeakShell
import PeakShell.Services
import "root:/components"
import "root:/services"

Scope {
    id: root
    property var screen: null
    function toggle() {
        sysMonitorOverlay.visible = !sysMonitorOverlay.visible;
    }
    ServiceRef {
        service: SystemMonitor
    }

    // Component keys are also the tokens stored in the "overlay/order" setting.
    readonly property var componentKeys: ["cpu", "gpu", "ram"]

    // How much of each component is drawn. Values are always shown; the mode
    // only changes the identity part (icon, text label, or both). Unknown
    // values (for example from a hand-edited config) fall back to the default
    // icon + text layout.
    readonly property var displayModes: ["iconText", "text", "icon"]
    readonly property string displayMode: displayModes.indexOf(Settings.overlayDisplayMode) !== -1 ? Settings.overlayDisplayMode : "iconText"

    // Settings may be edited by hand, so accept only known keys and append any
    // missing ones (keeping the configured relative order).
    readonly property var orderedKeys: {
        const parsed = (Settings.overlayOrder || "").split(",").map(k => k.trim());
        const keys = [];
        for (const key of parsed) {
            if (componentKeys.indexOf(key) !== -1 && keys.indexOf(key) === -1)
                keys.push(key);
        }
        for (const key of componentKeys) {
            if (keys.indexOf(key) === -1)
                keys.push(key);
        }
        return keys;
    }

    // Only enabled components with at least one enabled subcomponent take part
    // in the layout.
    readonly property var visibleKeys: orderedKeys.filter(key => componentEnabled(key) && componentHasMetrics(key))

    function componentEnabled(key) {
        switch (key) {
        case "cpu":
            return Settings.overlayCpuEnabled;
        case "gpu":
            return Settings.overlayGpuEnabled;
        case "ram":
            return Settings.overlayRamEnabled;
        }
        return false;
    }

    function componentHasMetrics(key) {
        switch (key) {
        case "cpu":
            return Settings.overlayCpuLoad || Settings.overlayCpuTemp;
        case "gpu":
            return Settings.overlayGpuLoad || Settings.overlayGpuTemp;
        case "ram":
            return Settings.overlayRamUsage;
        }
        return false;
    }

    function componentLabel(key) {
        switch (key) {
        case "cpu":
            return "CPU";
        case "gpu":
            return "GPU";
        case "ram":
            return "RAM";
        }
        return key;
    }

    function componentIcon(key) {
        switch (key) {
        case "cpu":
            return "indicator-sensors-cpu";
        case "gpu":
            return "indicator-sensors-gpu";
        case "ram":
            return "indicator-sensors-memory";
        }
        return "";
    }

    // The first enabled subcomponent is rendered inline; when both load and
    // temperature are enabled the temperature becomes the parenthesised
    // secondary value: "CPU: 42% (55°C)".
    function primaryMetric(key) {
        switch (key) {
        case "cpu":
            if (Settings.overlayCpuLoad)
                return { kind: "load", value: SystemMonitor.cpuLoad, suffix: "%" };
            if (Settings.overlayCpuTemp)
                return { kind: "temp", value: SystemMonitor.cpuTemp, suffix: "°C" };
            break;
        case "gpu":
            if (Settings.overlayGpuLoad)
                return { kind: "load", value: SystemMonitor.gpuLoad, suffix: "%" };
            if (Settings.overlayGpuTemp)
                return { kind: "temp", value: SystemMonitor.gpuTemp, suffix: "°C" };
            break;
        case "ram":
            if (Settings.overlayRamUsage)
                return { kind: "usage", value: SystemMonitor.memUsage, suffix: "%" };
            break;
        }
        return null;
    }

    function secondaryMetric(key) {
        switch (key) {
        case "cpu":
            if (Settings.overlayCpuLoad && Settings.overlayCpuTemp)
                return { kind: "temp", value: SystemMonitor.cpuTemp, suffix: "°C" };
            break;
        case "gpu":
            if (Settings.overlayGpuLoad && Settings.overlayGpuTemp)
                return { kind: "temp", value: SystemMonitor.gpuTemp, suffix: "°C" };
            break;
        }
        return null;
    }

    // Positive (low) values use the theme's green, critical (high) values use
    // the danger color, everything in between stays on the normal foreground.
    // The limits mirror the system monitor service (load is critical above the
    // limit, temperature at or above it).
    readonly property var metricLimits: ({
        load: { positive: 50, critical: 90, criticalAtLimit: false },
        usage: { positive: 50, critical: 90, criticalAtLimit: false },
        temp: { positive: 60, critical: 85, criticalAtLimit: true }
    })

    function metricColor(kind, value) {
        return metricColorFromSeverity(metricSeverity(kind, value));
    }

    // Severity: 0 = positive, 1 = normal, 2 = critical.
    function metricSeverity(kind, value) {
        const limits = metricLimits[kind] || metricLimits.load;
        const critical = limits.criticalAtLimit ? value >= limits.critical : value > limits.critical;
        if (critical)
            return 2;
        if (value <= limits.positive)
            return 0;
        return 1;
    }

    function metricColorFromSeverity(severity) {
        switch (severity) {
        case 2:
            return Theme.dangerPulse;
        case 0:
            return Theme.battery;
        default:
            return Theme.fgColor;
        }
    }

    // Icon-only mode has no numbers, so tint the icon with the worst status of
    // the component's enabled metrics (load and temperature can differ).
    function componentColor(key) {
        let severity = -1;
        for (const metric of [primaryMetric(key), secondaryMetric(key)]) {
            if (metric !== null)
                severity = Math.max(severity, metricSeverity(metric.kind, metric.value));
        }
        return metricColorFromSeverity(severity);
    }

    PanelWindow {
        id: sysMonitorOverlay
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: hasFullscreen ? ExclusionMode.Ignore : ExclusionMode.Auto
        screen: root.screen
        visible: false
        focusable: false
        color: "transparent"

        readonly property bool hasFullscreen: {
            if (!screen || !Hypr.focusedMonitor)
                return false;
            const mon = Hypr.focusedMonitor;
            const specialWs = mon.lastIpcObject?.specialWorkspace?.name;
            if (specialWs) {
                const sWs = Hypr.workspaces.values.find(w => w.name === specialWs);
                if (sWs && sWs.toplevels.values.some(t => t.lastIpcObject?.fullscreen > 1))
                    return true;
            }
            const activeWs = mon.activeWorkspace;
            if (activeWs && activeWs.toplevels.values.some(t => t.lastIpcObject?.fullscreen > 1))
                return true;
            return false;
        }

        implicitWidth: root.visibleKeys.length > 0 ? overlayLayout.implicitWidth + 24 : 0
        implicitHeight: root.visibleKeys.length > 0 ? overlayLayout.implicitHeight + 16 : 0

        anchors {
            top: true
            left: true
            bottom: false
            right: false
        }

        margins {
            top: Theme.barVerticalPad * 2
            left: Theme.barHorizontalPad
        }

        Rectangle {
            anchors.fill: parent
            visible: root.visibleKeys.length > 0
            color: Theme.overlayBackground ? Theme.bgColor : "transparent"
            border.color: Theme.mutedFgColor
            border.width: Theme.overlayBorder ? Theme.generalThickness / 2 : 0
            radius: Theme.cornerRadius

            RowLayout {
                id: overlayLayout
                anchors.centerIn: parent
                spacing: 16

                Repeater {
                    model: root.visibleKeys

                    delegate: RowLayout {
                        id: componentRow
                        required property string modelData
                        readonly property var primary: root.primaryMetric(modelData)
                        readonly property var secondary: root.secondaryMetric(modelData)
                        readonly property color statusColor: root.componentColor(modelData)
                        spacing: 6

                        IconImage {
                            visible: root.displayMode !== "text"
                            implicitSize: root.displayMode === "icon" ? 18 : 16
                            source: Quickshell.iconPath(root.componentIcon(componentRow.modelData))
                            layer.enabled: root.displayMode === "icon"
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                brightness: 1.0
                                colorizationColor: componentRow.statusColor
                            }
                        }

                        // Values are shown in every mode; icon-only simply drops the
                        // text label and lets the (tinted) icon identify the component.
                        Row {
                            spacing: 0

                            Text {
                                visible: root.displayMode !== "icon"
                                text: root.componentLabel(componentRow.modelData) + ": "
                                color: Theme.fgColor
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                            }
                            Text {
                                visible: componentRow.primary !== null
                                text: componentRow.primary ? componentRow.primary.value + componentRow.primary.suffix : ""
                                color: componentRow.primary ? root.metricColor(componentRow.primary.kind, componentRow.primary.value) : Theme.fgColor
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                                font.bold: true
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.effectsDuration
                                    }
                                }
                            }
                            Text {
                                visible: componentRow.secondary !== null
                                text: componentRow.secondary ? " (" + componentRow.secondary.value + componentRow.secondary.suffix + ")" : ""
                                color: componentRow.secondary ? root.metricColor(componentRow.secondary.kind, componentRow.secondary.value) : Theme.fgColor
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                                font.bold: true
                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.effectsDuration
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

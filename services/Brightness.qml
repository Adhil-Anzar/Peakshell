pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

// Brightness for every screen Quickshell knows about.
//
// Two backends are used:
//   * DDC/CI (ddcutil) for external monitors that expose a brightness VCP.
//   * sysfs (or brightnessctl, when available) for internal panels.
//
// A monitor is only considered supported when one of those backends can
// actually drive it. The bar chip is hidden for screens that are not
// supported, so machines without any controllable display never see the
// module at all.
Singleton {
    id: root

    // Emitted whenever a monitor's brightness is changed through the shell so
    // the OSD can mirror the change.
    signal osdRequested(var monitor)

    readonly property real step: 0.05
    readonly property var monitors: variants.instances

    // Parsed output of `ddcutil detect --brief`.
    property var ddcMonitors: []

    readonly property var ddcMonitorMap: {
        const map = {};
        for (const monitor of ddcMonitors)
            map[monitor.connector] = monitor;
        return map;
    }

    // First backlight device under /sys/class/backlight. Laptops have one;
    // desktops usually have none.
    property string backlightDevice: ""
    property bool brightnessctlAvailable: false

    // Screens powered off through toggleScreen() or the minimum-brightness
    // gesture. Keyed by connector so each screen is woken independently.
    property var offScreens: ({})

    readonly property var supportedMonitors: root.monitors.filter(m => m.supported)
    readonly property bool anySupported: root.supportedMonitors.length > 0

    function monitorForScreen(screen): var {
        if (!screen)
            return null;
        return root.monitors.find(m => m.modelData === screen) ?? null;
    }

    function supportsScreen(screen): bool {
        const monitor = monitorForScreen(screen);
        return monitor ? monitor.supported : false;
    }

    function statusForScreen(screen): string {
        const monitor = monitorForScreen(screen);
        return monitor ? root.statusForMonitor(monitor) : "";
    }

    function iconForScreen(screen): string {
        return root.iconForMonitor(monitorForScreen(screen));
    }

    // The monitor the user is currently looking at. Falls back to the first
    // supported monitor when the compositor cannot tell us (or when this is
    // not running under Hyprland).
    function focusedMonitor(): var {
        const name = Hypr.focusedMonitor ? String(Hypr.focusedMonitor.name) : "";
        if (name !== "") {
            const byName = root.monitors.find(m => m.connector === name);
            if (byName)
                return byName;
        }
        return root.supportedMonitors.length > 0 ? root.supportedMonitors[0] : null;
    }

    // The focused output, even when it has no brightness backend. This keeps
    // screen power actions useful on displays we cannot dim.
    function focusedConnector(): string {
        const name = Hypr.focusedMonitor ? String(Hypr.focusedMonitor.name) : "";
        if (name !== "")
            return name;
        const monitor = root.supportedMonitors.length > 0 ? root.supportedMonitors[0] : null;
        return monitor ? monitor.connector : "";
    }

    function screenIsOff(connector): bool {
        return root.offScreens[connector] === true;
    }

    function setScreenPower(connector, on): void {
        if (connector === "")
            return;
        const next = Object.assign({}, root.offScreens);
        if (on)
            delete next[connector];
        else
            next[connector] = true;
        root.offScreens = next;
        Hypr.dispatch(`dpms ${on ? "on" : "off"} ${connector}`);
    }

    function toggleScreen(): bool {
        const connector = root.focusedConnector();
        if (connector === "")
            return false;
        root.setScreenPower(connector, root.screenIsOff(connector));
        return true;
    }

    function statusForMonitor(monitor): string {
        if (!monitor || !monitor.supported)
            return "";
        if (!monitor.ready)
            return "...";
        return Math.round(monitor.brightness * 100) + "%";
    }

    function iconForMonitor(monitor): string {
        if (!monitor || !monitor.supported || !monitor.ready)
            return "display-brightness-symbolic";
        return root.iconForLevel(monitor.brightness);
    }

    function iconForLevel(level): string {
        if (level <= 0.01)
            return "display-brightness-off-symbolic";
        if (level < 0.34)
            return "display-brightness-low-symbolic";
        if (level < 0.67)
            return "display-brightness-medium-symbolic";
        return "display-brightness-high-symbolic";
    }

    // Low brightness is desaturated and dim (monotone), while 100% is the
    // fully saturated accent. This is what gives the slider its personality.
    function levelColor(level): color {
        const l = Math.max(0, Math.min(1, level));
        const base = Qt.color(Theme.accent);
        const hue = base.hslHue >= 0 ? base.hslHue : 0;
        const saturation = 0.05 + 0.95 * Math.pow(l, 1.25);
        const lightness = Math.min(0.72, base.hslLightness * (0.78 + 0.22 * l) + 0.12 * Math.pow(l, 3));
        const alpha = base.a * (0.65 + 0.35 * l);
        return Qt.hsla(hue, saturation, lightness, alpha);
    }

    function adjustMonitor(monitor, delta): bool {
        if (!monitor || !monitor.supported)
            return false;
        monitor.adjustBrightness(delta);
        return true;
    }

    function adjustFocused(delta): bool {
        const focused = focusedMonitor();
        if (focused && focused.supported) {
            focused.adjustBrightness(delta);
            return true;
        }

        // The focused screen may not support brightness, but an increase
        // should still wake it before we fall back to supported monitors.
        if (delta > 0)
            root.setScreenPower(root.focusedConnector(), true);

        const targets = root.supportedMonitors;
        if (targets.length === 0) {
            Utils.notify("Brightness", "None of the monitors supports it", "display-brightness");
            return false;
        }

        for (const monitor of targets)
            monitor.adjustBrightness(delta);
        return true;
    }

    function increaseBrightness(): bool {
        return root.adjustFocused(root.step);
    }

    function decreaseBrightness(): bool {
        return root.adjustFocused(-root.step);
    }

    function setForScreen(screen, value): void {
        const monitor = monitorForScreen(screen);
        if (monitor && monitor.supported)
            monitor.setBrightness(value);
    }

    function refresh(): void {
        for (const monitor of root.monitors) {
            if (monitor.supported)
                monitor.initBrightness();
        }
    }

    function summary(): string {
        const focused = focusedMonitor();
        if (focused && focused.supported)
            return `${focused.displayName}: ${root.statusForMonitor(focused)}`;

        const targets = root.supportedMonitors;
        if (targets.length === 0)
            return "None of the monitors supports it";

        return targets.map(m => `${m.displayName}: ${root.statusForMonitor(m)}`).join(", ");
    }

    // Re-detect when displays are plugged in or removed.
    onMonitorsChanged: detectDebounce.restart()

    Timer {
        id: detectDebounce
        interval: 750
        onTriggered: {
            ddcProc.running = false;
            ddcProc.running = true;
            backlightProc.running = false;
            backlightProc.running = true;
        }
    }

    Process {
        id: ddcProc
        command: ["sh", "-c", "command -v ddcutil >/dev/null 2>&1 && ddcutil detect --brief 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                const blocks = text.trim().split(/\n\s*\n/);
                for (const block of blocks) {
                    const b = block.trim();
                    if (!/^Display\s+\d+/.test(b))
                        continue;
                    const bus = b.match(/I2C bus:\s*\/dev\/i2c-(\d+)/);
                    const connector = b.match(/DRM connector:\s*(?:card\d+-)?([A-Za-z0-9-]+)/);
                    if (bus && connector)
                        found.push({
                            busNum: bus[1],
                            connector: connector[1]
                        });
                }
                root.ddcMonitors = found;
            }
        }
    }

    Process {
        id: backlightProc
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do if [ -e \"$d/brightness\" ]; then basename \"$d\"; break; fi; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.backlightDevice = text.trim()
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.brightnessctlAvailable = text.trim() === "yes"
        }
    }

    IpcHandler {
        target: "brightness"

        function brightness(): string {
            return root.summary();
        }

        function increaseBrightness(): void {
            root.increaseBrightness();
        }

        function decreaseBrightness(): void {
            root.decreaseBrightness();
        }

        function toggleScreen(): void {
            root.toggleScreen();
        }
    }

    Variants {
        id: variants
        model: Quickshell.screens

        Monitor {}
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData

        readonly property string connector: modelData.name
        readonly property string displayName: {
            const model = modelData.model ? String(modelData.model).trim() : "";
            // Some panels report only an EDID product code (e.g. "0x161D"),
            // which is not a useful label; fall back to the connector then.
            if (model === "" || /^0x[0-9a-f]+$/i.test(model))
                return monitor.connector;
            return model;
        }
        readonly property string detail: (displayName === connector ? "" : connector + " • ")
            + (isDdc ? "DDC" : "internal")
        readonly property var ddcInfo: root.ddcMonitorMap[monitor.connector] ?? null
        readonly property bool isDdc: ddcInfo !== null
        readonly property bool isInternal: ddcInfo === null
            && /^(edp|lvds|dsi)/i.test(monitor.connector)
            && root.backlightDevice !== ""
        readonly property bool supported: isDdc || isInternal
        readonly property string busNum: ddcInfo ? String(ddcInfo.busNum) : ""

        property real brightness: 0
        property int rawMax: 100
        property bool ready: false
        property real queuedBrightness: NaN
        // Consecutive decrease requests made while already at 0%.
        property int minDecreaseCount: 0

        onSupportedChanged: {
            if (supported)
                initBrightness();
        }
        onBusNumChanged: {
            if (supported)
                initBrightness();
        }
        Component.onCompleted: {
            if (supported)
                initBrightness();
        }

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = text.trim();
                    if (out === "")
                        return;

                    if (monitor.isDdc) {
                        // "VCP 10 C <current> <max>"
                        const parts = out.split(/\s+/);
                        if (parts.length < 2)
                            return;
                        const max = parseInt(parts[parts.length - 1], 10);
                        const current = parseInt(parts[parts.length - 2], 10);
                        if (isNaN(current) || isNaN(max) || max <= 0)
                            return;
                        monitor.rawMax = max;
                        monitor.brightness = Math.max(0, Math.min(1, current / max));
                        monitor.ready = true;
                    } else {
                        // "<current>\n<max>"
                        const parts = out.split(/\s+/).map(Number);
                        if (parts.length < 2 || isNaN(parts[0]) || isNaN(parts[1]) || parts[1] <= 0)
                            return;
                        monitor.rawMax = parts[1];
                        monitor.brightness = Math.max(0, Math.min(1, parts[0] / parts[1]));
                        monitor.ready = true;
                    }
                }
            }
        }

        readonly property Timer writeTimer: Timer {
            interval: 400
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    monitor.applyBrightness(monitor.queuedBrightness);
                    monitor.queuedBrightness = NaN;
                }
            }
        }

        function initBrightness(): void {
            if (monitor.isDdc) {
                monitor.initProc.command = ["ddcutil", "-b", monitor.busNum, "getvcp", "10", "--brief"];
                monitor.initProc.running = false;
                monitor.initProc.running = true;
            } else if (monitor.isInternal && root.backlightDevice !== "") {
                const dev = root.backlightDevice;
                monitor.initProc.command = ["sh", "-c", `cat /sys/class/backlight/${dev}/brightness /sys/class/backlight/${dev}/max_brightness`];
                monitor.initProc.running = false;
                monitor.initProc.running = true;
            }
        }

        function adjustBrightness(delta): void {
            if (delta > 0) {
                // Waking first means an increase also recovers from a screen
                // we powered off at minimum brightness.
                root.setScreenPower(monitor.connector, true);
                monitor.minDecreaseCount = 0;
                monitor.setBrightness(monitor.brightness + delta);
                return;
            }

            if (monitor.brightness <= 0.0001) {
                if (!Theme.brightnessScreenOffAtMin) {
                    monitor.minDecreaseCount = 0;
                    root.osdRequested(monitor);
                    return;
                }
                monitor.minDecreaseCount += 1;
                if (monitor.minDecreaseCount >= 3) {
                    monitor.minDecreaseCount = 0;
                    root.setScreenPower(monitor.connector, false);
                } else {
                    root.osdRequested(monitor);
                }
                return;
            }

            monitor.minDecreaseCount = 0;
            monitor.setBrightness(monitor.brightness + delta);
        }

        function setBrightness(value): void {
            value = Math.max(0, Math.min(1, value));
            const rounded = Math.round(value * 100);
            monitor.minDecreaseCount = 0;
            if (monitor.ready && Math.round(monitor.brightness * 100) === rounded) {
                // Show the OSD even when the display is already at its limit.
                root.osdRequested(monitor);
                return;
            }

            monitor.brightness = value;
            monitor.ready = true;
            root.osdRequested(monitor);

            // DDC/CI is slow and some monitors dislike rapid writes, so only
            // the last value in a drag is sent. sysfs is cheap enough to write
            // immediately.
            if (monitor.isDdc && monitor.writeTimer.running) {
                monitor.queuedBrightness = value;
                return;
            }

            monitor.applyBrightness(value);
            if (monitor.isDdc)
                monitor.writeTimer.restart();
        }

        function applyBrightness(value): void {
            value = Math.max(0, Math.min(1, value));
            const percent = Math.round(value * 100);
            const raw = Math.round(value * monitor.rawMax);

            if (monitor.isDdc) {
                // VCP 10 takes the monitor's raw range, which is not always 0-100.
                Quickshell.execDetached(["ddcutil", "-b", monitor.busNum, "setvcp", "10", String(raw)]);
                return;
            }

            if (root.brightnessctlAvailable) {
                Quickshell.execDetached(["brightnessctl", "-d", root.backlightDevice, "set", `${percent}%`]);
                return;
            }

            const dev = root.backlightDevice;
            Quickshell.execDetached(["sh", "-c", `printf '%s' ${raw} > /sys/class/backlight/${dev}/brightness`]);
        }
    }
}

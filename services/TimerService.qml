pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import PeakShell

Singleton {
    id: root

    // Authoritative countdown in milliseconds; endTime is the epoch-ms target
    // so the remaining time is recomputed (and never drifts) on each tick.
    property real remainingMs: 0
    property int presetSeconds: 0
    property bool running: false
    property bool finished: false
    property double endTime: 0

    readonly property int remaining: Math.ceil(remainingMs / 1000)
    readonly property bool active: running || finished || remainingMs > 0
    readonly property string formatted: format(remainingMs)
    // Compact hh:mm:ss / mm:ss for the bar module (no milliseconds).
    readonly property string compact: formatCompact(remainingMs)
    readonly property string state: finished ? "finished" : (running ? "running" : (remainingMs > 0 ? "paused" : "idle"))

    function pad(n) {
        return (n < 10 ? "0" : "") + n;
    }

    function pad3(n) {
        if (n < 10)
            return "00" + n;
        if (n < 100)
            return "0" + n;
        return "" + n;
    }

    // Below an hour the display carries milliseconds (mm:ss:mmm); at or above
    // an hour it drops to hh:mm:ss.
    function format(ms) {
        const total = Math.max(0, Math.floor(ms));
        const hours = Math.floor(total / 3600000);
        const minutes = Math.floor((total % 3600000) / 60000);
        const secs = Math.floor((total % 60000) / 1000);
        if (hours > 0)
            return pad(hours) + ":" + pad(minutes) + ":" + pad(secs);
        return pad(minutes) + ":" + pad(secs) + ":" + pad3(total % 1000);
    }

    function formatCompact(ms) {
        const total = Math.max(0, Math.floor(ms / 1000));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        const secs = total % 60;
        if (hours > 0)
            return pad(hours) + ":" + pad(minutes) + ":" + pad(secs);
        return pad(minutes) + ":" + pad(secs);
    }

    // Accepts plain seconds ("90"), suffixed durations ("5m", "1h30m") or
    // clock notation ("10:00", "1:30:00"); returns 0 when unparseable.
    function parseDuration(input) {
        const text = String(input ?? "").trim().toLowerCase();
        if (text.length === 0)
            return 0;
        if (/^\d+$/.test(text))
            return parseInt(text, 10);
        const clock = text.match(/^(\d+):([0-5]?\d)(?::([0-5]?\d))?$/);
        if (clock) {
            const a = parseInt(clock[1], 10);
            const b = parseInt(clock[2], 10);
            return clock[3] === undefined ? a * 60 + b : a * 3600 + b * 60 + parseInt(clock[3], 10);
        }
        let total = 0;
        let matched = false;
        const re = /(\d+)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)/g;
        let m;
        while ((m = re.exec(text)) !== null) {
            matched = true;
            const value = parseInt(m[1], 10);
            const unit = m[2][0];
            total += unit === "h" ? value * 3600 : (unit === "m" ? value * 60 : value);
        }
        return matched ? total : 0;
    }

    function start(seconds) {
        const total = Math.floor(Number(seconds));
        if (!(total > 0))
            return;
        presetSeconds = total;
        remainingMs = total * 1000;
        endTime = Date.now() + remainingMs;
        finished = false;
        running = true;
    }

    function startFromString(input) {
        start(parseDuration(input));
    }

    // Set the duration without starting (used when editing the clock).
    function setDuration(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds)));
        presetSeconds = total;
        remainingMs = total * 1000;
        running = false;
        finished = false;
    }

    function toggleRunning() {
        if (finished)
            start(presetSeconds);
        else if (remainingMs > 0)
            running ? pause() : resume();
    }

    function pause() {
        if (!running)
            return;
        remainingMs = Math.max(0, endTime - Date.now());
        running = false;
    }

    function resume() {
        if (finished || remainingMs <= 0)
            return;
        endTime = Date.now() + remainingMs;
        running = true;
    }

    function reset() {
        running = false;
        finished = false;
        remainingMs = presetSeconds * 1000;
    }

    function cancel() {
        running = false;
        finished = false;
        presetSeconds = 0;
        remainingMs = 0;
    }

    function complete() {
        running = false;
        finished = true;
        remainingMs = 0;
        Utils.notify("Timer finished", Utils.formatSeconds(presetSeconds) + " timer complete", "alarm-clock-triggered");
    }

    Timer {
        interval: 50
        repeat: true
        running: root.running
        onTriggered: {
            root.remainingMs = Math.max(0, root.endTime - Date.now());
            if (root.remainingMs <= 0)
                root.complete();
        }
    }

    IpcHandler {
        target: "timer"

        function start(seconds: string) {
            root.startFromString(seconds);
        }
        function toggle() {
            root.toggleRunning();
        }
        function pause() {
            root.pause();
        }
        function resume() {
            root.resume();
        }
        function reset() {
            root.reset();
        }
        function cancel() {
            root.cancel();
        }
        function remaining(): string {
            return String(root.remaining);
        }
        function state(): string {
            return root.state;
        }
    }
}

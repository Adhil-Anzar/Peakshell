pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import PeakShell
import "root:/"

// A SwayOSD-compatible on-screen display.
//
// The display itself lives in components/OsdOverlay.qml; this singleton owns
// the state and decides when the OSD should be shown. Volume, mute and
// brightness changes are detected automatically. Lock-key state is read from
// the kernel LED class because Wayland does not expose it any other way.
Singleton {
    id: root

    property bool showMediaChanges: true

    // An empty monitor name means "show on every monitor", like SwayOSD.
    // Placement and timing are configured from the Settings app.
    readonly property string monitor: Theme.osdMonitor
    property int _durationOverride: 0
    readonly property int duration: _durationOverride > 0 ? _durationOverride : Theme.osdDuration

    property bool visible: false
    property string icon: ""
    property color iconColor: "transparent"
    property string text: ""
    property bool hasProgress: false
    property real progress: 0
    property bool hasSegments: false
    property int segmentValue: 0
    property int segmentCount: 0
    property real iconOpacity: 1
    property real progressOpacity: 1

    readonly property var lockStates: _lockStates

    // ---------------------------------------------------------------------
    // Presentation
    // ---------------------------------------------------------------------

    Timer {
        id: hideTimer
        interval: root.duration
        repeat: false
        onIntervalChanged: if (running) restart()
        onTriggered: {
            root.visible = false;
            root._durationOverride = 0;
        }
    }

    function hide(): void {
        hideTimer.stop();
        root.visible = false;
        root._durationOverride = 0;
    }

    function present(durationMs): void {
        const ms = Number(durationMs);
        root._durationOverride = ms > 0 ? ms : 0;
        root.visible = true;
        hideTimer.restart();
    }

    function clearContent(): void {
        root.icon = "";
        root.iconColor = "transparent";
        root.text = "";
        root.hasProgress = false;
        root.progress = 0;
        root.hasSegments = false;
        root.segmentValue = 0;
        root.segmentCount = 0;
        root.iconOpacity = 1;
        root.progressOpacity = 1;
    }

    function showMessage(message, iconName, durationMs): void {
        clearContent();
        root.icon = iconName || "";
        root.text = message || "";
        present(durationMs);
    }

    function showCustomProgress(value, label, iconName, durationMs): void {
        clearContent();
        root.icon = iconName || "";
        root.text = label || "";
        root.hasProgress = true;
        root.progress = Math.max(0, Math.min(1, Number(value)));
        present(durationMs);
    }

    function showCustomSegments(value, count, label, iconName, durationMs): void {
        clearContent();
        root.icon = iconName || "";
        root.text = label || "";
        root.hasSegments = true;
        root.segmentCount = Math.max(0, Math.round(Number(count)));
        root.segmentValue = Math.max(0, Math.min(root.segmentCount, Math.round(Number(value))));
        present(durationMs);
    }

    function showMedia(iconName, label): void {
        clearContent();
        root.icon = iconName || "";
        root.text = label || "";
        present();
    }

    // ---------------------------------------------------------------------
    // Volume
    // ---------------------------------------------------------------------

    property real _sinkVolume: -1
    property bool _sinkMuted: false
    property bool _sinkKnown: false
    property real _sourceVolume: -1
    property bool _sourceMuted: false
    property bool _sourceKnown: false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Connections {
        target: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

        function onVolumesChanged(): void {
            root.checkSink();
        }

        function onMutedChanged(): void {
            root.checkSink();
        }
    }

    Connections {
        target: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

        function onVolumesChanged(): void {
            root.checkSource();
        }

        function onMutedChanged(): void {
            root.checkSource();
        }
    }

    Connections {
        target: Pipewire

        function onDefaultAudioSinkChanged(): void {
            root.resetSink();
        }

        function onDefaultAudioSourceChanged(): void {
            root.resetSource();
        }
    }

    Component.onCompleted: {
        root.resetSink();
        root.resetSource();
    }

    // Default devices can take a moment to appear after startup or an output
    // switch. Poll only while the current node is still unknown.
    Timer {
        interval: 250
        repeat: true
        running: !root._sinkKnown || !root._sourceKnown
        onTriggered: {
            if (!root._sinkKnown)
                root.checkSink();
            if (!root._sourceKnown)
                root.checkSource();
        }
    }

    function resetSink(): void {
        root._sinkKnown = false;
        root._sinkVolume = -1;
        Qt.callLater(root.checkSink);
    }

    function resetSource(): void {
        root._sourceKnown = false;
        root._sourceVolume = -1;
        Qt.callLater(root.checkSource);
    }

    function checkSink(): void {
        const node = Pipewire.defaultAudioSink;
        if (!node || !node.audio)
            return;

        const volume = node.audio.volume;
        const muted = node.audio.muted;
        if (!root._sinkKnown) {
            root._sinkVolume = volume;
            root._sinkMuted = muted;
            root._sinkKnown = true;
            return;
        }
        if (volume === root._sinkVolume && muted === root._sinkMuted)
            return;

        root._sinkVolume = volume;
        root._sinkMuted = muted;
        root.showVolume("sink", node);
    }

    function checkSource(): void {
        const node = Pipewire.defaultAudioSource;
        if (!node || !node.audio)
            return;

        const volume = node.audio.volume;
        const muted = node.audio.muted;
        if (!root._sourceKnown) {
            root._sourceVolume = volume;
            root._sourceMuted = muted;
            root._sourceKnown = true;
            return;
        }
        if (volume === root._sourceVolume && muted === root._sourceMuted)
            return;

        root._sourceVolume = volume;
        root._sourceMuted = muted;
        root.showVolume("source", node);
    }

    function volumeIcon(kind, volume, muted): string {
        const sink = kind === "sink";
        const prefix = sink ? "audio-volume-" : "audio-input-microphone-";
        if (muted || volume <= 0.0001)
            return prefix + "muted";

        const percent = volume * 100;
        if (percent > 66)
            return prefix + "high";
        if (percent > 33)
            return prefix + "medium";
        return prefix + "low";
    }

    function showVolumeLevel(kind, volume, muted): void {
        clearContent();
        root.icon = volumeIcon(kind, volume, muted);
        root.hasProgress = true;
        root.progress = Math.max(0, Math.min(1, volume));
        root.progressOpacity = muted ? 0.35 : 1;
        present();
    }

    function showVolume(kind, node): void {
        if (!node || !node.audio)
            return;
        showVolumeLevel(kind, node.audio.volume, node.audio.muted);
    }

    function cacheVolume(kind, volume, muted): void {
        if (kind === "sink") {
            root._sinkVolume = volume;
            root._sinkMuted = muted;
            root._sinkKnown = true;
        } else {
            root._sourceVolume = volume;
            root._sourceMuted = muted;
            root._sourceKnown = true;
        }
    }

    // ---------------------------------------------------------------------
    // Brightness
    // ---------------------------------------------------------------------

    Connections {
        target: Brightness

        function onOsdRequested(monitor): void {
            root.showBrightness(monitor);
        }
    }

    function showBrightness(monitor): void {
        if (!monitor)
            return;

        const level = Math.max(0, Math.min(1, monitor.brightness));
        clearContent();
        root.icon = Brightness.iconForLevel(level);
        root.iconColor = Brightness.levelColor(level);
        root.hasProgress = true;
        root.progress = level;
        present();
    }

    // ---------------------------------------------------------------------
    // Lock keys
    // ---------------------------------------------------------------------

    property var _lockStates: ({})
    property var _lockKnown: ({})
    property var _ledValues: ({})
    property var _ledEntries: []
    property var _ledViews: []
    property var _pendingLocks: ({})

    Process {
        id: ledScan
        running: true
        command: [
            "sh", "-c",
            "for t in capslock numlock scrolllock; do " +
            "for f in /sys/class/leds/*::$t/brightness; do " +
            "[ -e \"$f\" ] && printf '%s %s\\n' \"$t\" \"$f\"; " +
            "done; done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const entries = [];
                const lines = text.trim().split("\n");
                for (const line of lines) {
                    const split = line.indexOf(" ");
                    if (split <= 0)
                        continue;
                    entries.push({
                        kind: line.slice(0, split),
                        path: line.slice(split + 1)
                    });
                }
                root._ledEntries = entries;
            }
        }
    }

    Instantiator {
        model: root._ledEntries

        delegate: FileView {
            required property var modelData
            readonly property string ledKind: modelData.kind
            readonly property string ledPath: modelData.path
            property bool initialized: false

            path: ledPath
            preload: true
            watchChanges: true
            printErrors: false

            onLoaded: {
                if (!initialized) {
                    initialized = true;
                    root.recordLed(ledPath, text().trim() === "1", false);
                }
            }

            onTextChanged: {
                if (initialized)
                    root.recordLed(ledPath, text().trim() === "1", true);
            }
        }

        onObjectAdded: (index, object) => {
            const views = root._ledViews.slice();
            views.push(object);
            root._ledViews = views;
        }

        onObjectRemoved: (index, object) => {
            root._ledViews = root._ledViews.filter(view => view !== object);
        }
    }

    // sysfs attributes do not reliably generate inotify events, so poll the
    // small number of LED files. A 120 ms interval is quick enough to feel
    // instant without any measurable overhead.
    Timer {
        interval: 120
        repeat: true
        running: root._ledViews.length > 0
        onTriggered: {
            for (const view of root._ledViews)
                view.reload();
        }
    }

    Timer {
        id: lockDebounce
        interval: 60
        repeat: false
        onTriggered: {
            const pending = root._pendingLocks;
            root._pendingLocks = ({});
            for (const kind in pending)
                root.showLock(kind, pending[kind]);
        }
    }

    function recordLed(path, on, live): void {
        const values = Object.assign({}, root._ledValues);
        values[path] = on;
        root._ledValues = values;

        let kind = "";
        for (const entry of root._ledEntries) {
            if (entry.path === path) {
                kind = entry.kind;
                break;
            }
        }
        if (kind === "")
            return;

        // Several keyboards can expose an LED of the same type. Treat the
        // aggregate as "on" when any of them is on.
        let state = false;
        for (const entry of root._ledEntries) {
            if (entry.kind === kind && root._ledValues[entry.path] === true)
                state = true;
        }

        if (root._lockKnown[kind] !== true) {
            const known = Object.assign({}, root._lockKnown);
            known[kind] = true;
            root._lockKnown = known;
            const states = Object.assign({}, root._lockStates);
            states[kind] = state;
            root._lockStates = states;
            return;
        }

        if (root._lockStates[kind] === state)
            return;

        const states = Object.assign({}, root._lockStates);
        states[kind] = state;
        root._lockStates = states;

        if (!live)
            return;

        const pending = Object.assign({}, root._pendingLocks);
        pending[kind] = state;
        root._pendingLocks = pending;
        lockDebounce.restart();
    }

    function lockInfo(kind): var {
        switch (kind) {
        case "numlock":
            return { label: "Num Lock", icon: "num-lock-symbolic", fallback: "input-keyboard-symbolic" };
        case "scrolllock":
            return { label: "Scroll Lock", icon: "scroll-lock-symbolic", fallback: "input-keyboard-symbolic" };
        case "capslock":
        default:
            return { label: "Caps Lock", icon: "caps-lock-symbolic", fallback: "keyboard-caps-locked-symbolic" };
        }
    }

    function showLock(kind, state): void {
        const info = lockInfo(kind);
        clearContent();
        root.icon = info.icon;
        root.text = info.label + (state ? " On" : " Off");
        root.iconOpacity = state ? 1 : 0.5;
        present();
    }

    function toggleLockOsd(kind): void {
        showLock(kind, root._lockStates[kind] === true);
    }

    // ---------------------------------------------------------------------
    // Media
    // ---------------------------------------------------------------------

    Connections {
        target: MprisController.activePlayer

        function onPlaybackStateChanged(): void {
            if (!root.showMediaChanges)
                return;
            const player = MprisController.activePlayer;
            if (!player)
                return;

            const state = player.playbackState;
            let iconName = "media-playback-pause-symbolic";
            if (state === MprisPlaybackState.Playing)
                iconName = "media-playback-start-symbolic";
            else if (state === MprisPlaybackState.Stopped)
                iconName = "media-playback-stop-symbolic";

            root.showMedia(iconName, MprisController.nowPlayingLabel);
        }
    }

    // ---------------------------------------------------------------------
    // Public actions (also exposed over IPC)
    // ---------------------------------------------------------------------

    function bumpVolume(kind, delta): void {
        const node = kind === "sink" ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;
        if (!node || !node.audio)
            return;
        const volume = Math.max(0, Math.min(1, node.audio.volume + delta));
        const muted = node.audio.muted;
        node.audio.volume = volume;
        root.cacheVolume(kind, volume, muted);
        root.showVolumeLevel(kind, volume, muted);
    }

    function setVolume(kind, value): void {
        const node = kind === "sink" ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;
        if (!node || !node.audio)
            return;
        const volume = Math.max(0, Math.min(1, Number(value)));
        const muted = node.audio.muted;
        node.audio.volume = volume;
        root.cacheVolume(kind, volume, muted);
        root.showVolumeLevel(kind, volume, muted);
    }

    function toggleMute(kind): void {
        const node = kind === "sink" ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;
        if (!node || !node.audio)
            return;
        const volume = node.audio.volume;
        const muted = !node.audio.muted;
        node.audio.muted = muted;
        root.cacheVolume(kind, volume, muted);
        root.showVolumeLevel(kind, volume, muted);
    }

    function playMedia(action): void {
        switch (action) {
        case "play-pause":
            MprisController.togglePlaying();
            break;
        case "play":
            if (MprisController.activePlayer && MprisController.activePlayer.canPlay)
                MprisController.activePlayer.play();
            break;
        case "pause":
            if (MprisController.activePlayer && MprisController.activePlayer.canPause)
                MprisController.activePlayer.pause();
            break;
        case "next":
            MprisController.next();
            break;
        case "prev":
            MprisController.previous();
            break;
        case "shuffle":
            MprisController.setShuffle(!MprisController.hasShuffle);
            break;
        }
    }

    IpcHandler {
        target: "osd"

        // Named "message" instead of "show" because "show" is also a
        // quickshell IPC subcommand and would be parsed as one.
        function message(message: string, icon: string, durationMs: int): void {
            root.showMessage(message, icon, durationMs);
        }

        function progress(value: real, label: string, icon: string, durationMs: int): void {
            root.showCustomProgress(value, label, icon, durationMs);
        }

        function segments(value: int, count: int, label: string, icon: string): void {
            root.showCustomSegments(value, count, label, icon);
        }

        function volumeRaise(): void {
            root.bumpVolume("sink", 0.05);
        }

        function volumeLower(): void {
            root.bumpVolume("sink", -0.05);
        }

        function volumeMute(): void {
            root.toggleMute("sink");
        }

        function volumeSet(percent: int): void {
            root.setVolume("sink", percent / 100);
        }

        function inputVolumeRaise(): void {
            root.bumpVolume("source", 0.05);
        }

        function inputVolumeLower(): void {
            root.bumpVolume("source", -0.05);
        }

        function inputVolumeMute(): void {
            root.toggleMute("source");
        }

        function brightnessRaise(): void {
            Brightness.increaseBrightness();
        }

        function brightnessLower(): void {
            Brightness.decreaseBrightness();
        }

        function capsLock(): void {
            root.toggleLockOsd("capslock");
        }

        function numLock(): void {
            root.toggleLockOsd("numlock");
        }

        function scrollLock(): void {
            root.toggleLockOsd("scrolllock");
        }

        function media(action: string): void {
            root.playMedia(action);
        }

        function monitorName(): string {
            return root.monitor;
        }

        function setMonitor(name: string): void {
            Settings.osdMonitor = name;
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import PeakShell.Apps

Singleton {
    id: root

    // The native C++ scanner handles all .desktop parsing and file I/O.
    readonly property var apps: AppScanner.apps
    readonly property bool loaded: AppScanner.loaded

    signal scanComplete()

    function scan() {
        AppScanner.scan();
    }

    function launch(entry) {
        AppScanner.launch(entry);
        root.close();
    }

    // Overridden by LauncherPanel via Connections
    function close() {}

    Connections {
        target: AppScanner
        function onScanComplete() { root.scanComplete(); }
    }
}

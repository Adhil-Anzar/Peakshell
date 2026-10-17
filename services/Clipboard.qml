pragma Singleton

import QtQuick
import Quickshell
import PeakShell.Apps

Singleton {
    id: root

    readonly property int count: ClipboardManager.count

    signal historyChanged()

    function search(query) {
        return ClipboardManager.search(query);
    }

    function copy(id) {
        ClipboardManager.copy(id);
    }

    function copyAndPaste(id) {
        ClipboardManager.copyAndPaste(id);
    }

    function remove(id) {
        ClipboardManager.remove(id);
    }

    function clear() {
        ClipboardManager.clear();
    }

    function refresh() {
        ClipboardManager.refresh();
    }

    function ingestText(text) {
        ClipboardManager.ingestText(text);
    }

    Connections {
        target: ClipboardManager
        function onHistoryChanged() {
            root.historyChanged();
        }
    }
}

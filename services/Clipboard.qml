pragma Singleton

import QtQuick
import Quickshell
import PeakShell.Apps

Singleton {
    id: root

    readonly property int count: ClipboardManager.count

    signal historyChanged

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

    // Returns { kind: "image" | "text" | "unsupported", mime, text,
    // imageSource, truncated, ... } for a file clipboard entry.
    function previewFile(path) {
        return ClipboardManager.previewFile(path || "");
    }

    // Rich-text HTML for the clipboard preview. Falls back to escaped plain
    // text when no syntax definition matches.
    function highlightText(text, mimeType, colors) {
        return SyntaxHighlighter.highlight(text || "", mimeType || "", colors || ({}));
    }

    // Per-line rich text for virtualized previews.
    function highlightLines(text, mimeType, colors) {
        return SyntaxHighlighter.highlightLines(text || "", mimeType || "", colors || ({}));
    }

    // Per-line rich text that lets the file name pick the syntax definition.
    function highlightFileLines(text, fileName, mimeType, colors) {
        return SyntaxHighlighter.highlightFileLines(text || "", fileName || "", mimeType || "", colors || ({}));
    }

    Connections {
        target: ClipboardManager
        function onHistoryChanged() {
            root.historyChanged();
        }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import PeakShell
import "root:/"
import "root:/services"

// Reusable file preview surface (images, highlighted text, unsupported files).
// The launcher uses it for Ctrl+Space; the clipboard can reuse it for file
// entries without duplicating the preview pipeline.
Rectangle {
    id: root

    signal toggleRequested

    property string filePath: ""
    property string fileName: ""
    property string fileIcon: "text-x-generic"
    property int maxChars: 12000
    property int maxLines: 200

    property var preview: ({})
    property var previewLines: []

    readonly property string previewMode: preview.kind || ""
    readonly property string imageSource: preview.imageSource || ""
    readonly property string headerTitle: fileName.length > 0 ? fileName : "File preview"
    readonly property string modeLabel: previewMode === "image" ? "Image" : (previewMode === "text" ? "Text" : "")

    color: Theme.bgColorFilled
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerLargeRadius
    clip: true

    // Match the clipboard's short debounce: scrolling through files with the
    // arrow keys should only read/highlight the file that stays selected.
    Timer {
        id: refreshDebounce
        interval: 40
        repeat: false
        onTriggered: root.refresh()
    }

    onFilePathChanged: {
        if (filePath === "") {
            refreshDebounce.stop();
            preview = ({});
            previewLines = [];
        } else {
            refreshDebounce.restart();
        }
    }

    Component.onCompleted: {
        if (filePath !== "")
            refreshDebounce.restart();
    }

    Connections {
        target: Theme
        function onAccentChanged() {
            if (root.visible)
                refreshDebounce.restart();
        }
    }

    function refresh() {
        preview = ({});
        previewLines = [];
        if (filePath === "")
            return;

        let info;
        try {
            info = Clipboard.previewFile(filePath);
        } catch (e) {
            preview = ({
                    kind: "unsupported"
                });
            return;
        }
        preview = info;
        if (info.kind !== "text")
            return;
        const rawText = info.text || "";
        let text = rawText.substring(0, root.maxChars);
        let truncated = info.truncated === true || text.length < rawText.length;

        const lines = text.split("\n");
        if (lines.length > root.maxLines) {
            text = lines.slice(0, root.maxLines).join("\n");
            truncated = true;
        }

        const highlighted = Clipboard.highlightFileLines(text, filePath, info.mime || "", Theme.syntaxPalette);
        const result = [];
        for (let i = 0; i < highlighted.length; ++i)
            result.push(highlighted[i]);
        if (result.length === 0)
            result.push("<span style=\"font-style:italic\">Empty file</span>");
        if (truncated)
            result.push("<span style=\"font-style:italic\">Preview limited for performance. The full item is still opened.</span>");
        previewLines = result;
    }

    // PageUp/PageDown move by most of a viewport, leaving a little context.
    function scrollPage(direction) {
        if (previewMode !== "text")
            return;
        const maxY = Math.max(0, previewList.contentHeight - previewList.height);
        const step = Math.max(24, previewList.height * 0.8);
        previewList.contentY = Math.max(0, Math.min(maxY, previewList.contentY + direction * step));
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconImage {
                Layout.alignment: Qt.AlignVCenter
                implicitSize: 18
                source: Quickshell.iconPath(root.fileIcon || "text-x-generic")
            }

            Text {
                Layout.fillWidth: true
                text: root.headerTitle
                color: Theme.fgColor
                font.bold: true
                font.pointSize: Theme.labelFontSize + 1
                font.family: Theme.labelFontFamily
                elide: Text.ElideRight
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.modeLabel
                color: Theme.mutedFgColor
                font.pointSize: Theme.labelFontSize * 0.85
                font.family: Theme.labelFontFamily
            }
        }

        Image {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.previewMode === "image"
            source: root.imageSource
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
        }

        // One delegate per line keeps rich-text layout bounded to the lines
        // currently visible in the viewport.
        ListView {
            id: previewList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.previewMode === "text"
            clip: true
            model: root.previewLines
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 200
            spacing: 0
            focus: false
            activeFocusOnTab: false
            ScrollBar.vertical: RoundedScrollBar {}

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Space && (event.modifiers & Qt.ControlModifier)) {
                    root.toggleRequested();
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                    root.scrollPage(event.key === Qt.Key_PageUp ? -1 : 1);
                    event.accepted = true;
                }
            }

            delegate: Text {
                width: ListView.view.width
                height: implicitHeight
                text: modelData.length > 0 ? modelData : "\u200b"
                textFormat: Text.RichText
                color: Theme.fgColor
                font.pointSize: Theme.labelFontSize
                font.family: Theme.labelFontFamily
                wrapMode: Text.WrapAnywhere
                renderType: Text.CurveRendering
                antialiasing: true
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.previewMode === "unsupported"
            text: "Unsupported preview :("
            color: Theme.mutedFgColor
            font.pointSize: Theme.labelFontSize
            font.family: Theme.labelFontFamily
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            renderType: Text.CurveRendering
            antialiasing: true
        }
    }
}

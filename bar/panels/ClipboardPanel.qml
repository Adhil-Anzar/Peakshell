import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import PeakShell
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root
    property var panelHost

    component SpatialAnim: Anim {
        type: Anim.DefaultSpatial
    }
    component EffectsAnim: Anim {
        type: Anim.DefaultEffects
    }

    readonly property int maxVisibleItems: Theme.clipboardMaxVisibleItems
    readonly property int itemSpacing: 6

    property var results: []
    property bool previewActive: false
    property bool altHeld: false
    property double now: Date.now()
    // Rotating friendly help shown in the search field, re-picked on each open.
    property string placeholderText: ""
    property int _placeholderIndex: -1
    readonly property var placeholderPool: {
        var pool = ["Enter copies and pastes it · Shift+Enter just copies", "Ctrl+Space to preview an item", "Hold Alt to reveal the shortcuts", "Hold Alt to see exact timestamps", "Delete removes an item from history", "Ctrl+Delete clears the whole history", "Escape closes the panel", "Text, images and files all wait here", "Copy anything and it lands right here", "What are we copying next?", "Your recent copies, one search away"];
        if (Settings.clipboardFuzzy)
            pool.splice(3, 0, "Type to search: fuzzy, so typos are welcome");
        return pool;
    }

    readonly property int visibleCount: results.length
    readonly property int displayCount: Math.min(visibleCount, maxVisibleItems)
    readonly property int selectedIndex: (clipList.currentIndex >= 0) ? clipList.currentIndex : (visibleCount > 0 ? 0 : -1)
    readonly property var previewEntry: (selectedIndex >= 0 && selectedIndex < results.length) ? results[selectedIndex] : null

    readonly property real listHeight: visibleCount > 0 ? displayCount * Theme.clipboardItemHeight + Math.max(0, displayCount - 1) * itemSpacing : 0
    // Reserve room for the empty-state message so it is actually visible.
    readonly property real emptyHeight: Math.max(48, Theme.clipboardItemHeight)
    readonly property bool showPreview: previewActive && previewEntry !== null
    readonly property real previewHeight: {
        var screenH = root.screen ? root.screen.height : 900;
        return Math.min(560, Math.max(240, screenH * 0.6));
    }
    readonly property real bodyHeight: showPreview ? previewHeight : (visibleCount > 0 ? listHeight : emptyHeight)
    readonly property real totalHeight: Theme.launcherSearchHeight + (bodyHeight > 0 ? itemSpacing + bodyHeight : 0)

    Timer {
        id: searchDebounce
        interval: 60
        repeat: false
        onTriggered: root.updateFilter()
    }

    // Keeps the relative timestamps fresh while the panel is open.
    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    function exactTime(ms) {
        if (!ms)
            return "";
        return Qt.formatDateTime(new Date(ms), "yyyy-MM-dd HH:mm");
    }

    function friendlyTime(ms) {
        if (!ms)
            return "";
        var diff = root.now - ms;
        if (diff < 60000)
            return "just now";
        if (diff < 3600000) {
            var minutes = Math.floor(diff / 60000);
            return minutes + (minutes === 1 ? " minute ago" : " minutes ago");
        }
        if (diff < 86400000) {
            var hours = Math.floor(diff / 3600000);
            return hours + (hours === 1 ? " hour ago" : " hours ago");
        }
        var date = new Date(ms);
        var yest = new Date(root.now - 86400000);
        if (date.getFullYear() === yest.getFullYear() && date.getMonth() === yest.getMonth() && date.getDate() === yest.getDate())
            return "yesterday";
        return Qt.formatDateTime(date, "yyyy-MM-dd");
    }

    function timeLabel(ms) {
        return root.altHeld ? exactTime(ms) : friendlyTime(ms);
    }

    function previewTitle(entry) {
        if (!entry)
            return "";
        if (entry.kind === "image")
            return "Image preview";
        if (entry.kind === "file")
            return "File preview";
        return "Text preview";
    }

    function previewBody(entry) {
        if (!entry)
            return "";
        if (entry.kind === "file" && entry.paths)
            return entry.paths.join("\n");
        return entry.text || "";
    }

    function updateFilter() {
        root.results = Clipboard.search(searchInput.text.trim());
        clipList.currentIndex = root.results.length > 0 ? 0 : -1;
        clipList.forceLayout();
        if (root.results.length > 0)
            clipList.positionViewAtBeginning();
    }

    // Picks a fresh help line, never repeating the previous one.
    function pickPlaceholder() {
        var pool = root.placeholderPool;
        if (pool.length === 0) {
            root.placeholderText = "";
            return;
        }
        var i = Math.floor(Math.random() * pool.length);
        if (pool.length > 1 && i === root._placeholderIndex)
            i = (i + 1) % pool.length;
        root._placeholderIndex = i;
        root.placeholderText = pool[i];
    }

    function open() {
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("clipboard");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["clipboard"] = root;
        Clipboard.refresh();
        pickPlaceholder();
        searchInput.text = "";
        previewActive = false;
        altHeld = false;
        now = Date.now();
        updateFilter();
        searchInput.forceActiveFocus();
    }

    function close() {
        searchInput.forceActiveFocus();
        searchInput.focus = false;
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["clipboard"] = false;
        searchDebounce.stop();
        searchInput.text = "";
        results = [];
        clipList.currentIndex = -1;
        previewActive = false;
        altHeld = false;
    }

    function toggle() {
        visible ? close() : open();
    }

    function moveSelection(delta) {
        if (results.length === 0)
            return;
        var current = (clipList.currentIndex < 0) ? 0 : clipList.currentIndex;
        var next = Math.max(0, Math.min(current + delta, results.length - 1));
        clipList.currentIndex = next;
        clipList.positionViewAtIndex(next, ListView.Contain);
    }

    function copyCurrent(paste) {
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= results.length)
            return;
        root.activate(results[idx], paste === true);
    }

    function activate(entry, paste) {
        if (!entry)
            return;
        if (paste)
            Clipboard.copyAndPaste(entry.id);
        else
            Clipboard.copy(entry.id);
        Utils.notify(paste ? "Copied and pasted" : "Copied to clipboard", entry.kind === "image" ? "Image" : entry.name, entry.icon);
        close();
    }

    function removeCurrent() {
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= results.length)
            return;
        var entry = results[idx];
        Clipboard.remove(entry.id);
        updateFilter();
    }

    function clearAll() {
        if (Clipboard.count === 0)
            return;
        Clipboard.clear();
        updateFilter();
        Utils.notify("Clipboard cleared", "", "edit-clear");
    }

    visible: false
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Alt) {
                root.altHeld = true;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Space && (event.modifiers & Qt.ControlModifier)) {
                root.previewActive = true;
                event.accepted = true;
                return;
            }
            switch (event.key) {
            case Qt.Key_Escape:
                root.close();
                event.accepted = true;
                break;
            case Qt.Key_Up:
                root.moveSelection(-1);
                event.accepted = true;
                break;
            case Qt.Key_Down:
                root.moveSelection(1);
                event.accepted = true;
                break;
            case Qt.Key_Delete:
                if (event.modifiers & Qt.ControlModifier)
                    root.clearAll();
                else
                    root.removeCurrent();
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.copyCurrent((event.modifiers & Qt.ShiftModifier) === 0);
                event.accepted = true;
                break;
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt) {
                root.altHeld = false;
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Space) {
                root.previewActive = false;
                event.accepted = true;
            }
        }

        Item {
            id: panel
            anchors.centerIn: parent
            width: Theme.clipboardWidth
            height: root.totalHeight
            Behavior on height {
                SpatialAnim {}
            }

            opacity: root.visible ? 1 : 0
            scale: root.visible ? 1 : 0.94
            transformOrigin: Item.Center
            Behavior on opacity {
                EffectsAnim {}
            }
            Behavior on scale {
                SpatialAnim {}
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Rectangle {
                id: searchBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.launcherSearchHeight
                radius: Theme.cornerLargeRadius
                color: Theme.bgColor
                border.color: searchInput.activeFocus ? Theme.accent : Theme.mutedAccent
                border.width: Theme.generalThickness
                antialiasing: true
                smooth: true
                Behavior on border.color {
                    CAnim {}
                }

                HoverHandler {
                    id: searchBarHover
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 16
                        rightMargin: 12
                    }
                    spacing: 12

                    IconImage {
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: Theme.launcherIconSize
                        source: Quickshell.iconPath("edit-paste", "system-search")
                        smooth: true
                        mipmap: true
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            brightness: 1.0
                            colorizationColor: Theme.mutedFgColor
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            color: Theme.fgColor
                            font.pointSize: Theme.launcherSearchFontSize
                            font.family: Theme.labelFontFamily
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            antialiasing: true

                            onTextChanged: searchDebounce.restart()

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Alt) {
                                    root.altHeld = true;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Space && (event.modifiers & Qt.ControlModifier)) {
                                    root.previewActive = true;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.copyCurrent((event.modifiers & Qt.ShiftModifier) === 0);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Delete) {
                                    // Handled here because the focused TextInput
                                    // otherwise swallows Delete before it reaches
                                    // the panel's FocusScope handler.
                                    if (event.modifiers & Qt.ControlModifier)
                                        root.clearAll();
                                    else
                                        root.removeCurrent();
                                    event.accepted = true;
                                }
                            }
                            Keys.onReleased: event => {
                                if (event.key === Qt.Key_Alt) {
                                    root.altHeld = false;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Space) {
                                    root.previewActive = false;
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            anchors.fill: parent
                            text: root.placeholderText
                            color: Theme.mutedFgColor
                            font.pointSize: Theme.launcherSearchFontSize
                            font.family: Theme.labelFontFamily
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            visible: searchInput.text.length === 0
                            renderType: Text.CurveRendering
                            antialiasing: true
                        }
                    }

                    ClickButton {
                        id: clearSearchBtn
                        visible: opacity > 0
                        opacity: (searchInput.text.length > 0 && (searchBarHover.hovered || clearSearchBtn.isHovered)) ? 1.0 : 0.0
                        symbol: "edit-clear"
                        size: Theme.iconFontSize
                        bgColor: "transparent"
                        cornerRadius: Theme.cornerRadius
                        iconColor: clearSearchBtn.isHovered ? Theme.fgColor : Theme.mutedFgColor
                        onPress: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                        Behavior on opacity {
                            EffectsAnim {}
                        }
                    }
                }
            }

            Item {
                id: resultsArea
                anchors.top: searchBar.bottom
                anchors.topMargin: root.itemSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.max(0, panel.height - searchBar.height - root.itemSpacing)
                clip: true
                opacity: root.visible && !root.showPreview ? 1 : 0
                Behavior on opacity {
                    EffectsAnim {}
                }

                ScriptModel {
                    id: clipModel
                    values: root.results
                }

                ListView {
                    id: clipList
                    anchors.fill: parent
                    clip: true
                    spacing: root.itemSpacing
                    model: clipModel
                    currentIndex: -1
                    highlight: null
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                        visible: false
                    }

                    delegate: Item {
                        id: del
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: del.index === root.selectedIndex
                        readonly property bool hovered: delMa.containsMouse

                        width: clipList.width
                        height: Theme.clipboardItemHeight
                        transformOrigin: Item.Center
                        scale: del.isSelected ? 1.0 : (del.hovered ? 0.99 : 0.96)
                        z: del.isSelected ? 20 : 10
                        Behavior on scale {
                            SpatialAnim {}
                        }

                        Rectangle {
                            id: card
                            anchors.fill: parent
                            radius: Theme.cornerLargeRadius
                            color: del.isSelected ? Theme.hoveredBgColor : (del.hovered ? Theme.mutedBgColor : Theme.bgColor)
                            border.color: del.isSelected ? Theme.accent : Theme.mutedAccent
                            border.width: del.isSelected ? Theme.generalThickness : 1
                            antialiasing: true
                            smooth: true
                            clip: true

                            Behavior on color {
                                CAnim {}
                            }
                            Behavior on border.color {
                                CAnim {}
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 14
                                    rightMargin: 16
                                }
                                spacing: 14

                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: Theme.launcherIconSize + 16
                                    implicitHeight: Theme.launcherIconSize + 16
                                    radius: Theme.cornerRadius
                                    color: Theme.mutedBgColor
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        visible: del.modelData.kind === "image"
                                        source: del.modelData.imageSource || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                    }

                                    IconImage {
                                        anchors.centerIn: parent
                                        visible: del.modelData.kind !== "image"
                                        implicitSize: Theme.launcherIconSize
                                        source: Quickshell.iconPath(del.modelData.icon || "text-x-generic", "text-x-generic")
                                        smooth: true
                                        mipmap: true
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: del.modelData.name || ""
                                        color: Theme.fgColor
                                        font.bold: true
                                        font.pointSize: Theme.labelFontSize + 1
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: del.modelData.comment || del.modelData.mime || ""
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.9
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: del.modelData ? root.timeLabel(del.modelData.timestamp) : ""
                                    color: Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize * 0.85
                                    font.family: Theme.labelFontFamily
                                    renderType: Text.CurveRendering
                                    antialiasing: true
                                }
                            }
                        }

                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: clipList.currentIndex = del.index
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    root.removeCurrent();
                                else
                                    root.activate(del.modelData);
                            }
                        }
                    }
                }

                Text {
                    visible: root.results.length === 0
                    anchors.centerIn: parent
                    text: Clipboard.count === 0 ? "Clipboard is empty" : "No matching items"
                    color: Theme.mutedFgColor
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                    renderType: Text.CurveRendering
                    antialiasing: true
                }
            }

            Rectangle {
                id: previewCard
                anchors.top: searchBar.bottom
                anchors.topMargin: root.itemSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.previewHeight
                radius: Theme.cornerLargeRadius
                color: Theme.bgColorFilled
                border.color: Theme.accent
                border.width: Theme.generalThickness
                clip: true
                visible: root.showPreview
                opacity: visible ? 1 : 0
                z: 50
                Behavior on opacity {
                    EffectsAnim {}
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
                            source: Quickshell.iconPath(root.previewEntry && root.previewEntry.icon ? root.previewEntry.icon : "text-x-generic")
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.previewTitle(root.previewEntry)
                            color: Theme.fgColor
                            font.bold: true
                            font.pointSize: Theme.labelFontSize + 1
                            font.family: Theme.labelFontFamily
                        }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: root.previewEntry ? root.timeLabel(root.previewEntry.timestamp) : ""
                            color: Theme.mutedFgColor
                            font.pointSize: Theme.labelFontSize * 0.85
                            font.family: Theme.labelFontFamily
                        }
                    }

                    Image {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.previewEntry !== null && root.previewEntry.kind === "image"
                        source: root.previewEntry ? (root.previewEntry.imageSource || "") : ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        mipmap: true
                    }

                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.previewEntry !== null && root.previewEntry.kind !== "image"
                        clip: true
                        contentWidth: width
                        contentHeight: previewText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }

                        Text {
                            id: previewText
                            width: parent.width
                            text: root.previewBody(root.previewEntry)
                            color: Theme.fgColor
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            wrapMode: Text.WrapAnywhere
                            renderType: Text.CurveRendering
                            antialiasing: true
                        }
                    }
                }
            }

            Rectangle {
                id: hintBar
                anchors.top: parent.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: hintText.implicitWidth + 28
                implicitHeight: hintText.implicitHeight + 14
                radius: height * 0.5
                color: Theme.bgColor
                border.color: Theme.mutedAccent
                border.width: 1
                // Revealed only while Alt is held (an on-demand help overlay).
                opacity: (root.visible && root.altHeld) ? 1 : 0
                Behavior on opacity {
                    EffectsAnim {}
                }

                Text {
                    id: hintText
                    anchors.centerIn: parent
                    text: root.previewActive ? "Release Ctrl+Space to close preview · ↑↓ browse" : "Enter copy & paste · Shift+Enter copy · Ctrl+Space preview · Alt exact time · Del remove · Ctrl+Del clear · Esc close"
                    color: Theme.mutedFgColor
                    font.pointSize: Theme.labelFontSize * 0.85
                    font.family: Theme.labelFontFamily
                    renderType: Text.CurveRendering
                    antialiasing: true
                }
            }
        }
    }

    Connections {
        target: Clipboard
        function onHistoryChanged() {
            if (root.visible)
                root.updateFilter();
        }
    }

    Component.onCompleted: {
        pickPlaceholder();
        updateFilter();
    }
}

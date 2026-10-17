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

    // Shorthands so each Behavior/Transition is a one-liner.
    component SpatialAnim: Anim {
        type: Anim.DefaultSpatial
    }
    component EffectsAnim: Anim {
        type: Anim.DefaultEffects
    }

    readonly property int maxVisibleItems: Theme.launcherMaxItems
    readonly property int itemSpacing: 6

    property var filteredApps: []
    // Previous result window (key -> {obj, idx}) used to keep row identity
    // across searches so the ListView can slide rows instead of rebuilding
    // them. Only rows inside the visible window are tracked: sliding a row in
    // from (or out to) far off-screen strands its delegate outside the view.
    property var _prevRows: ({})
    // Bumped after every search. Web/calc rows keep their object identity (so
    // they slide) while their fields are updated in place; plain JS objects
    // aren't reactive, so delegate bindings depend on this to re-read them.
    property int rowRevision: 0
    // Latest contents of per-query rows (web/calc), key -> row. The model only
    // keeps the snapshot a row had when it was inserted, so delegates read
    // these rows from here instead of from modelData.
    property var _live: ({})

    // Identity key for per-query rows ("" for everything else).
    function _queryRowKey(r) {
        if (r && (r.kind === "web" || r.kind === "calc") && r.uid !== undefined && r.uid !== "")
            return r.kind + ":" + r.uid;
        return "";
    }
    // While held, Alt previews the selected row's hover tags (same logic as
    // hovering; pairs with Alt+Enter copy). Reset on open/close.
    property bool altHeld: false
    readonly property int visibleCount: filteredApps.length
    readonly property int displayCount: Math.min(visibleCount, maxVisibleItems)
    readonly property bool hasResults: visibleCount > 0 && searchInput.text.trim().length > 0

    // Currently active/selected index (defaults to first item when results are shown)
    readonly property int selectedIndex: (appList.currentIndex >= 0) ? appList.currentIndex : (hasResults ? 0 : -1)

    // Rotating friendly help shown in the search field, re-picked on each open.
    property string placeholderText: ""
    property int _placeholderIndex: -1
    readonly property var placeholderPool: {
        var pool = ["Type to explore apps, actions and answers", "Hold Alt to preview a result's details", "Alt+Enter copies the highlighted command", "Enter opens the highlighted result", "Right-click a result to copy its command", "Arrow keys to move · Enter to open", "What are we looking for?"];
        if (Settings.launcherCalc)
            pool.splice(3, 0, "Try a calculation: 12*8 works");
        if (Settings.launcherWebSearch)
            pool.splice(4, 0, "Type anything to search the web");
        if (Settings.launcherFuzzy)
            pool.splice(5, 0, "Fuzzy search: typos are welcome");
        return pool;
    }

    // Debounce timer: only recalculates at the end of each text change
    Timer {
        id: searchDebounce
        interval: 60
        repeat: false
        onTriggered: root.updateFilter()
    }

    function updateFilter() {
        var q = searchInput.text.trim();
        if (!q) {
            root._prevRows = ({});
            root.filteredApps = [];
            appList.currentIndex = -1;
            appList.forceLayout();
            return;
        }

        // Ranked OpenSearch-style search (C++): fuzzy apps + ii1qe toggle
        // actions + exprtk calculator + smart web-search fallback.
        var results = AppScanner.search(q);
        results = root._stableize(results);
        root.filteredApps = results;
        root.rowRevision++;
        appList.currentIndex = results.length > 0 ? 0 : -1;
        appList.forceLayout();
        if (results.length > 0) {
            appList.positionViewAtBeginning();
        }
    }

    // Keep object identity only for app/ipc rows that sit inside the visible
    // window both before and after this search (short slides). Everything else
    // is a fresh row. Rows that collide (same identity key or uid) are dropped
    // so no object appears twice.
    function _stableize(results) {
        var win = root.maxVisibleItems;
        var out = [];
        var seen = ({});
        var next = ({});
        var live = ({});
        for (var i = 0; i < results.length; i++) {
            var r = results[i];
            var key = "";
            if (r.kind === "app")
                key = "app:" + r.exec + "\n" + r.name;
            else if (r.kind === "ipc")
                key = "ipc:" + r.ipcFunction;
            else
                key = root._queryRowKey(r);
            var uidKey = (r.uid !== undefined && r.uid !== "") ? "uid:" + r.uid : "";
            if ((key && seen[key]) || (uidKey && seen[uidKey]))
                continue;
            if (key)
                seen[key] = true;
            if (uidKey)
                seen[uidKey] = true;

            var row = r;
            if (key) {
                var prev = root._prevRows[key];
                if (prev && prev.idx < win && out.length < win) {
                    row = prev.obj;
                    // Per-query rows: same object, fresh contents.
                    if (r.kind === "web" || r.kind === "calc") {
                        for (var k in row)
                            if (!(k in r))
                                delete row[k];
                        for (var k2 in r)
                            row[k2] = r[k2];
                    }
                }
                if (out.length < win)
                    next[key] = {
                        obj: row,
                        idx: out.length
                    };
            }
            var qk = root._queryRowKey(r);
            if (qk)
                live[qk] = r;
            out.push(row);
        }
        root._live = live;
        root._prevRows = next;
        return out;
    }

    // Extra height reserved for the selected row's command line.
    readonly property real commandExtra: 23
    readonly property real listHeight: hasResults ? displayCount * Theme.launcherItemHeight + Math.max(0, displayCount - 1) * itemSpacing + ((appList.currentIndex >= 0) ? commandExtra : 0) : 0

    readonly property real totalHeight: Theme.launcherSearchHeight + (hasResults ? itemSpacing + listHeight : 0)

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
            panelHost.hideAllPanelExcept("launcher");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["launcher"] = root;
        searchInput.text = "";
        pickPlaceholder();
        _prevRows = ({});
        filteredApps = [];
        appList.currentIndex = -1;
        searchInput.forceActiveFocus();
    }

    function close() {
        // Release text-input focus while the surface is still mapped (first
        // funneling focus through the search field so a focused command field
        // also lets go cleanly). Hiding with a focused input makes Qt log
        // disableSurface warnings about a null focused surface.
        searchInput.forceActiveFocus();
        searchInput.focus = false;
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["launcher"] = false;
        searchDebounce.stop();
        searchInput.text = "";
        filteredApps = [];
        appList.currentIndex = -1;
        altHeld = false;
    }

    function toggle() {
        visible ? close() : open();
    }

    // The freshest contents for a row (per-query rows are updated in place).
    function _latest(entry) {
        var k = root._queryRowKey(entry);
        return (k && root._live[k]) ? root._live[k] : entry;
    }

    function launchCurrent() {
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= filteredApps.length)
            return;
        root.activateItem(root._latest(filteredApps[idx]));
    }

    // Dispatches a ranked result map. Calculator results are copied to the
    // clipboard, echoed back into the search box (mirrors OpenSearch), and
    // confirmed through the system notification daemon; the launcher stays
    // open. Everything else closes the launcher after activation.
    function activateItem(entry) {
        if (!entry)
            return;
        if (entry.kind === "calc") {
            AppScanner.activateResult(entry);
            searchInput.text = entry.name;
            Utils.notify("Copied to clipboard", entry.name, "accessories-calculator");
            return;
        }
        AppScanner.activateResult(entry);
        close();
    }

    // The exact string that activating this entry would execute.
    function commandFor(entry) {
        if (!entry)
            return "";
        if (entry.kind === "ipc")
            return "peakshell ipc call ii1qe " + entry.ipcFunction;
        if (entry.kind === "calc")
            return entry.name;
        return entry.exec || "";
    }

    // Copies an entry's command and confirms via the system notification daemon.
    function copyCommand(entry) {
        var cmd = root.commandFor(entry);
        if (!cmd)
            return;
        AppScanner.copyToClipboard(cmd);
        Utils.notify("Copied to clipboard", cmd, "edit-copy");
    }

    function copyCurrent() {
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= filteredApps.length)
            return;
        root.copyCommand(root._latest(filteredApps[idx]));
    }

    // First ";" separated token of a .desktop list field (Keywords/Categories),
    // capitalized for pill display.
    function _firstListToken(s) {
        if (!s)
            return "";
        var parts = s.split(";");
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].trim();
            if (t.length > 0)
                return t.charAt(0).toUpperCase() + t.slice(1);
        }
        return "";
    }

    function moveSelection(delta) {
        if (filteredApps.length === 0)
            return;
        var current = (appList.currentIndex < 0) ? 0 : appList.currentIndex;
        var next = Math.max(0, Math.min(current + delta, filteredApps.length - 1));
        appList.currentIndex = next;
        root.ensureVisible(next);
    }

    // Scrolls just far enough to show row idx including the extra height of
    // its expanded command line. ListView.Contain only knows the fixed slot
    // height, so it would clip the bottom of the expanded card.
    function ensureVisible(idx) {
        var step = Theme.launcherItemHeight + itemSpacing;
        var top = idx * step;
        var bottom = top + Theme.launcherItemHeight + commandExtra;
        var viewH = appList.height;
        var cy = appList.contentY - appList.originY;
        if (top < cy)
            cy = top;
        else if (bottom > cy + viewH)
            cy = bottom - viewH;
        var maxY = Math.max(0, appList.contentHeight + appList.bottomMargin - viewH);
        cy = Math.max(0, Math.min(cy, maxY));
        appList.contentY = cy + appList.originY;
    }

    Connections {
        target: AppScanner
        function onScanComplete() {
            // App data may have changed; drop stabilized identities once.
            root._prevRows = ({});
            root.updateFilter();
        }
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
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (event.modifiers & Qt.AltModifier)
                    root.copyCurrent();
                else
                    root.launchCurrent();
                event.accepted = true;
                break;
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt)
                root.altHeld = false;
        }

        Item {
            id: launcher
            anchors.centerIn: parent
            width: Theme.launcherWidth

            // The only height animation: resultsArea follows this value.
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

            // Search bar pill
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
                        id: searchIcon
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: Theme.launcherIconSize
                        source: Quickshell.iconPath("system-search", "edit-find")
                        backer.mirror: true
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

                            // Debounce filtering to the end of keystrokes for high performance
                            onTextChanged: {
                                searchDebounce.restart();
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
                        id: clearBtn
                        visible: opacity > 0
                        opacity: (searchInput.text.length > 0 && (searchBarHover.hovered || clearBtn.isHovered)) ? 1.0 : 0.0
                        symbol: "edit-clear"
                        size: Theme.iconFontSize
                        bgColor: "transparent"
                        cornerRadius: Theme.cornerRadius
                        iconColor: clearBtn.isHovered ? Theme.fgColor : Theme.mutedFgColor
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

            // Results list container (fixed viewport of up to 5 items, scrollable)
            Item {
                id: resultsArea
                anchors.top: searchBar.bottom
                anchors.topMargin: root.itemSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                // Follows the launcher's animated height (no second animation).
                height: Math.max(0, launcher.height - searchBar.height - root.itemSpacing)
                clip: true

                opacity: root.hasResults ? 1 : 0
                Behavior on opacity {
                    EffectsAnim {}
                }

                ScriptModel {
                    id: appScriptModel
                    values: root.filteredApps
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    clip: true
                    spacing: root.itemSpacing
                    model: appScriptModel
                    currentIndex: -1
                    highlight: null
                    boundsBehavior: Flickable.StopAtBounds
                    // Rows have a fixed slot height; the selected card grows
                    // visually by commandExtra, so keep that room at the end.
                    bottomMargin: root.commandExtra

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                        visible: false
                    }

                    // Shuffle & displacement transitions
                    // Rows slide to their new slots. `displaced` also covers
                    // add/remove displacement. (No `add` fade for now.)
                    displaced: Transition {
                        SpatialAnim {
                            property: "y"
                        }
                    }
                    move: Transition {
                        SpatialAnim {
                            property: "y"
                        }
                    }

                    delegate: Item {
                        id: del
                        required property var modelData
                        required property int index

                        // Avoid animating scale when delegate is initially scrolled in
                        property bool ready: false

                        // Cascade entrance ("shuffle")
                        // 0 -> 1 when this row is created. Drives a drop-in
                        // (translate), a small scale-up and a fade, staggered by
                        // row position. Owned entirely by the row, so it can't
                        // leave anything stranded by the ListView.
                        property real enter: 0

                        // Reads a field of the row; depends on rowRevision so
                        // in-place updates to a reused row refresh the UI.
                        function liveRow() {
                            root.rowRevision;
                            return root._latest(del.modelData);
                        }
                        function field(name) {
                            return del.liveRow()[name];
                        }
                        SequentialAnimation {
                            id: enterAnim
                            PauseAnimation {
                                duration: Math.max(0, Math.min(del.index, 6)) * 35
                            }
                            SpatialAnim {
                                target: del
                                property: "enter"
                                from: 0
                                to: 1
                            }
                        }
                        Component.onCompleted: {
                            ready = true;
                            enterAnim.start();
                        }
                        opacity: Math.min(1, del.enter)

                        readonly property int distance: Math.abs(del.index - root.selectedIndex)
                        readonly property bool isSelected: del.index === root.selectedIndex

                        // Pills for the tag row: the kind pill plus, on hover,
                        // keyword/category info pills (or a sensible fallback).
                        // On hover the kind pill steps aside whenever keyword
                        // or category pills take over.
                        // Hovered rows show the extended tag logic; holding Alt
                        // previews the same for the selected row.
                        readonly property bool tagsHover: delMa.containsMouse || (root.altHeld && del.isSelected)
                        readonly property string kindLabel: {
                            root.rowRevision;
                            var d = del.liveRow();
                            if (d.kind === "ipc")
                                return "Action";
                            if (d.kind === "calc")
                                return "Calc";
                            if (d.kind === "web")
                                return "Web";
                            return d.terminal ? "CLI" : "App";
                        }
                        // The timer action shows the live countdown in place of
                        // its description while a timer is active.
                        readonly property bool isTimerRow: {
                            root.rowRevision;
                            var d = del.liveRow();
                            return d.kind === "ipc" && d.ipcFunction === "timer";
                        }
                        readonly property string timerText: {
                            if (!del.isTimerRow || !TimerService.running)
                                return "";
                            return TimerService.formatted + " remaining";
                        }
                        readonly property bool kindStepsAside: {
                            root.rowRevision;
                            var d = del.liveRow();
                            if (!del.tagsHover || d.kind !== "app")
                                return false;
                            return root._firstListToken(d.keywords).length > 0 || root._firstListToken(d.categories).length > 0;
                        }
                        readonly property var infoPills: {
                            root.rowRevision;
                            if (!del.tagsHover)
                                return [];
                            var d = del.liveRow();
                            var pills = [];
                            if (d.kind === "app") {
                                var kw = root._firstListToken(d.keywords);
                                var cat = root._firstListToken(d.categories);
                                if (kw.length > 0)
                                    pills.push(kw);
                                if (cat.length > 0)
                                    pills.push(cat);
                                if (pills.length === 0)
                                    pills.push(d.terminal ? "Terminal" : "Application");
                            } else if (d.kind === "ipc") {
                                pills.push(d.ipcFunction);
                            } else if ((d.kind === "calc" || d.kind === "web") && d.detail) {
                                pills.push(d.detail);
                            }
                            return pills;
                        }

                        width: appList.width
                        // Fixed slot height: the ListView never has to re-measure
                        // rows when the selection changes, so row positions (and
                        // the shuffle transitions' targets) can't go stale.
                        height: Theme.launcherItemHeight
                        transformOrigin: Item.Center

                        // The one animated value for the selection expansion:
                        // extra card height for the selected row's command line.
                        property real extraH: del.isSelected ? root.commandExtra : 0
                        Behavior on extraH {
                            enabled: del.ready
                            SpatialAnim {}
                        }
                        // 0..1 progress derived from extraH; drives the command
                        // row and tag row so they need no animations of their own.
                        readonly property real expand: del.extraH / root.commandExtra

                        // Rows below the selected one are pushed down visually
                        // (a transform, not layout) to make room for that extra.
                        property real pushY: (root.selectedIndex >= 0 && del.index > root.selectedIndex) ? root.commandExtra : 0
                        Behavior on pushY {
                            enabled: del.ready
                            SpatialAnim {}
                        }
                        transform: [
                            Translate {
                                y: del.pushY + (1 - del.enter) * -18
                            },
                            Scale {
                                origin.x: del.width / 2
                                origin.y: del.height / 2
                                xScale: 0.92 + 0.08 * del.enter
                                yScale: 0.92 + 0.08 * del.enter
                            }
                        ]

                        // Max scale is 1.0 (matches the search bar width); siblings
                        // shrink with distance from the selected row.
                        readonly property real baseScale: Math.max(0.88, 1.0 - del.distance * 0.03)
                        readonly property real targetScale: del.isSelected ? 1.0 : (delMa.containsMouse ? Math.min(0.99, del.baseScale + 0.03) : del.baseScale)
                        scale: del.targetScale
                        Behavior on scale {
                            enabled: del.ready
                            SpatialAnim {}
                        }

                        z: del.isSelected ? 20 : (15 - Math.min(10, del.distance))

                        // Floating Card with matching cornerLargeRadius
                        Rectangle {
                            id: itemCard
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: Theme.launcherItemHeight + del.extraH
                            radius: Theme.cornerLargeRadius
                            color: del.isSelected ? Theme.hoveredBgColor : (delMa.containsMouse ? Theme.mutedBgColor : Theme.bgColor)
                            border.color: del.isSelected ? Theme.accent : Theme.mutedAccent
                            border.width: del.isSelected ? Theme.generalThickness : 1
                            antialiasing: true
                            smooth: true

                            opacity: (del.isSelected || delMa.containsMouse) ? 1.0 : Math.max(0.65, 1.0 - del.distance * 0.08)
                            Behavior on opacity {
                                EffectsAnim {}
                            }

                            Behavior on color {
                                CAnim {}
                            }
                            Behavior on border.color {
                                CAnim {}
                            }
                            Behavior on border.width {
                                NumberAnimation {
                                    duration: Theme.fastEffectsDuration
                                }
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 18
                                    rightMargin: 18
                                }
                                spacing: 14

                                IconImage {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitSize: Theme.launcherIconSize
                                    source: Quickshell.iconPath(del.field("icon") || "application-x-executable", "application-x-executable")
                                    smooth: true
                                    mipmap: true
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: del.field("name") || ""
                                        color: Theme.fgColor
                                        font.bold: true
                                        font.pointSize: Theme.labelFontSize + 2
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: del.timerText.length > 0 ? del.timerText : (del.field("comment") || del.field("genericName") || "")
                                        color: del.timerText.length > 0 ? Theme.accent : Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.9
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }

                                    // Command line: what will be executed (selectable)
                                    Row {
                                        width: parent.width
                                        height: 20 * del.expand
                                        visible: height > 0
                                        opacity: del.expand
                                        spacing: 6
                                        clip: true

                                        Text {
                                            id: commandLabel
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            text: "command:"
                                            color: Theme.mutedFgColor
                                            font.pointSize: Theme.labelFontSize * 0.85
                                            font.family: Theme.labelFontFamily
                                            renderType: Text.CurveRendering
                                            antialiasing: true
                                        }

                                        TextInput {
                                            id: commandField
                                            width: parent.width - commandLabel.width - parent.spacing
                                            height: parent.height
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: {
                                                root.rowRevision;
                                                return root.commandFor(del.liveRow());
                                            }
                                            color: Theme.fgColor
                                            selectionColor: Theme.accent
                                            selectedTextColor: Theme.fgColor
                                            font.pointSize: Theme.labelFontSize * 0.85
                                            font.family: Theme.labelFontFamily
                                            readOnly: true
                                            selectByMouse: true
                                            clip: true
                                            cursorVisible: activeFocus
                                            renderType: Text.CurveRendering

                                            Keys.onPressed: event => {
                                                switch (event.key) {
                                                case Qt.Key_Escape:
                                                    searchInput.forceActiveFocus();
                                                    root.close();
                                                    event.accepted = true;
                                                    break;
                                                case Qt.Key_Up:
                                                    root.moveSelection(-1);
                                                    searchInput.forceActiveFocus();
                                                    event.accepted = true;
                                                    break;
                                                case Qt.Key_Down:
                                                    root.moveSelection(1);
                                                    searchInput.forceActiveFocus();
                                                    event.accepted = true;
                                                    break;
                                                case Qt.Key_Return:
                                                case Qt.Key_Enter:
                                                    if (event.modifiers & Qt.AltModifier)
                                                        root.copyCurrent();
                                                    else
                                                        root.launchCurrent();
                                                    event.accepted = true;
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                }

                                // Tag row: info pills + kind pill
                                // Selected row only. On hover the kind pill steps
                                // aside (animated, to the right) whenever keyword
                                // or category pills take over.
                                Row {
                                    id: tagRow
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: Math.min(tagRow.implicitWidth, appList.width * 0.5) * del.expand
                                    spacing: 6
                                    clip: true
                                    opacity: del.expand
                                    visible: Layout.preferredWidth > 1

                                    Row {
                                        id: infoRow
                                        spacing: 6

                                        Repeater {
                                            model: del.infoPills
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: Math.min(infoPillLabel.implicitWidth + 20, 140)
                                                height: infoPillLabel.implicitHeight + 10
                                                radius: height * 0.5
                                                color: "transparent"
                                                border.color: Theme.mutedAccent
                                                border.width: 1
                                                clip: true

                                                Text {
                                                    id: infoPillLabel
                                                    width: Math.max(0, Math.min(implicitWidth, parent.width - 20))
                                                    height: implicitHeight
                                                    anchors.centerIn: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    elide: Text.ElideRight
                                                    text: modelData
                                                    color: Theme.mutedFgColor
                                                    font.pointSize: Theme.labelFontSize * 0.85
                                                    font.family: Theme.labelFontFamily
                                                    renderType: Text.CurveRendering
                                                    antialiasing: true
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        id: kindPill
                                        width: del.kindStepsAside ? 0 : Math.min(kindPillLabel.implicitWidth + 20, 140)
                                        height: kindPillLabel.implicitHeight + 10
                                        visible: width > 1
                                        radius: height * 0.5
                                        color: Theme.accent
                                        opacity: del.kindStepsAside ? 0 : 1
                                        scale: del.kindStepsAside ? 0.7 : 1
                                        transformOrigin: Item.Right
                                        clip: true

                                        Behavior on width {
                                            SpatialAnim {}
                                        }
                                        Behavior on opacity {
                                            EffectsAnim {}
                                        }
                                        Behavior on scale {
                                            SpatialAnim {}
                                        }

                                        Text {
                                            id: kindPillLabel
                                            width: Math.max(0, Math.min(implicitWidth, parent.width - 20))
                                            height: implicitHeight
                                            anchors.centerIn: parent
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                            text: del.kindLabel
                                            color: Theme.fgColor
                                            font.bold: true
                                            font.pointSize: Theme.labelFontSize * 0.85
                                            font.family: Theme.labelFontFamily
                                            renderType: Text.CurveRendering
                                            antialiasing: true
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: delMa
                            anchors.fill: itemCard
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    appList.currentIndex = del.index;
                                    root.copyCommand(del.liveRow());
                                } else {
                                    root.activateItem(del.liveRow());
                                }
                            }
                            onEntered: {
                                appList.currentIndex = del.index;
                            }
                            onWheel: wheel => {
                                wheel.accepted = false; // Allow ListView to handle scrolling
                            }
                        }
                    }

                    Text {
                        visible: root.filteredApps.length === 0 && AppScanner.loaded && searchInput.text.trim().length > 0
                        anchors.centerIn: parent
                        text: "No results for \"" + searchInput.text.trim() + "\""
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        renderType: Text.CurveRendering
                        antialiasing: true
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        pickPlaceholder();
        if (!AppScanner.loaded)
            AppScanner.scan();
    }
}

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

    readonly property int maxVisibleItems: 5
    readonly property int itemSpacing: 6

    property var filteredApps: []
    // Stable identity cache for result rows. The ListView shuffle/move
    // transitions track rows by object identity, so app/ipc rows (whose
    // display fields never change) reuse the same object across searches.
    // Calculator/web rows carry per-query text and stay fresh objects.
    property var _entryCache: ({})
    readonly property int visibleCount: filteredApps.length
    readonly property int displayCount: Math.min(visibleCount, maxVisibleItems)
    readonly property bool hasResults: visibleCount > 0 && searchInput.text.trim().length > 0

    // Currently active/selected index (defaults to first item when results are shown)
    readonly property int selectedIndex: (appList.currentIndex >= 0) ? appList.currentIndex : (hasResults ? 0 : -1)

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
            root.filteredApps = [];
            appList.currentIndex = -1;
            return;
        }

        // Ranked OpenSearch-style search (C++): fuzzy apps + ii1qe toggle
        // actions + exprtk calculator + smart web-search fallback.
        var results = AppScanner.search(q);
        results = root._stableize(results);
        root.filteredApps = results;
        appList.currentIndex = results.length > 0 ? 0 : -1;
        if (results.length > 0) {
            appList.positionViewAtBeginning();
        }
    }

    // Reuse cached objects for rows with static display fields so the
    // ListView move/displaced transitions keep working across keystrokes.
    function _stableize(results) {
        var out = [];
        for (var i = 0; i < results.length; i++) {
            var r = results[i];
            var key = "";
            if (r.kind === "app")
                key = "app:" + r.exec + "\n" + r.name;
            else if (r.kind === "ipc")
                key = "ipc:" + r.ipcFunction;
            if (key) {
                var old = root._entryCache[key];
                if (old) {
                    out.push(old);
                    continue;
                }
                root._entryCache[key] = r;
            }
            out.push(r);
        }
        return out;
    }

    // Extra height reserved for the selected row's command line.
    readonly property real commandExtra: 23
    readonly property real listHeight: hasResults ? displayCount * Theme.launcherItemHeight + Math.max(0, displayCount - 1) * itemSpacing + ((appList.currentIndex >= 0) ? commandExtra : 0) : 0

    readonly property real totalHeight: Theme.launcherSearchHeight + (hasResults ? itemSpacing + listHeight : 0)

    function open() {
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("launcher");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["launcher"] = root;
        searchInput.text = "";
        filteredApps = [];
        appList.currentIndex = -1;
        searchInput.forceActiveFocus();
    }

    function close() {
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["launcher"] = false;
        searchDebounce.stop();
        searchInput.text = "";
        filteredApps = [];
        appList.currentIndex = -1;
    }

    function toggle() {
        visible ? close() : open();
    }

    function launchCurrent() {
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= filteredApps.length)
            return;
        root.activateItem(filteredApps[idx]);
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
        root.copyCommand(filteredApps[idx]);
    }

    // First ";" separated token of a .desktop list field (Keywords/Categories).
    function _firstListToken(s) {
        if (!s)
            return "";
        var parts = s.split(";");
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].trim();
            if (t.length > 0)
                return t;
        }
        return "";
    }

    function moveSelection(delta) {
        if (filteredApps.length === 0)
            return;
        var current = (appList.currentIndex < 0) ? 0 : appList.currentIndex;
        var next = Math.max(0, Math.min(current + delta, filteredApps.length - 1));
        appList.currentIndex = next;
        appList.positionViewAtIndex(next, ListView.Contain);
    }

    Connections {
        target: AppScanner
        function onScanComplete() {
            // App data may have changed; drop stabilized identities once.
            root._entryCache = ({});
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

        Item {
            id: launcher
            anchors.centerIn: parent
            width: Theme.launcherWidth

            // Smooth fluid height animation using M3 expressive bezier curve
            height: root.totalHeight
            Behavior on height {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            opacity: root.visible ? 1 : 0
            scale: root.visible ? 1 : 0.94
            transformOrigin: Item.Center
            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
            Behavior on scale {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            // ── Search bar pill ─────────────────────────────────────────────
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
                            text: "Type to explore…"
                            color: Theme.mutedFgColor
                            font.pointSize: Theme.launcherSearchFontSize
                            font.family: Theme.labelFontFamily
                            verticalAlignment: Text.AlignVCenter
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
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }
                }
            }

            // ── Results list container (fixed viewport of up to 5 items, scrollable) ─
            Item {
                id: resultsArea
                anchors.top: searchBar.bottom
                anchors.topMargin: root.itemSpacing
                anchors.left: parent.left
                anchors.right: parent.right
                height: root.listHeight
                clip: true

                Behavior on height {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                opacity: root.hasResults ? 1 : 0
                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                ScriptModel {
                    id: appScriptModel
                    values: root.filteredApps
                    // Compare rows by stable uid so reorders animate instead
                    // of rebuilding every delegate (incl. the web row).
                    objectProp: "uid"
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

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AlwaysOff
                        visible: false
                    }

                    // ── Shuffle & displacement transitions ───────────────────
                    add: Transition {
                        Anim {
                            property: "opacity"
                            from: 0
                            to: 1
                            type: Anim.DefaultEffects
                        }
                    }

                    move: Transition {
                        Anim {
                            property: "y"
                            type: Anim.DefaultSpatial
                        }
                    }

                    addDisplaced: Transition {
                        Anim {
                            property: "y"
                            type: Anim.DefaultSpatial
                        }
                    }

                    displaced: Transition {
                        Anim {
                            property: "y"
                            type: Anim.DefaultSpatial
                        }
                    }

                    delegate: Item {
                        id: del
                        required property var modelData
                        required property int index

                        // Avoid animating scale when delegate is initially scrolled in
                        property bool ready: false
                        Component.onCompleted: ready = true

                        readonly property int distance: Math.abs(del.index - root.selectedIndex)
                        readonly property bool isSelected: del.index === root.selectedIndex

                        Connections {
                            target: appList
                            function onCurrentIndexChanged() {
                                appList.forceLayout();
                            }
                        }

                        // Pills for the tag row: kind first, then keyword /
                        // category info (or a sensible fallback) on hover.
                        readonly property var pillDefs: {
                            var d = del.modelData;
                            var pills = [
                                {
                                    "label": "App",
                                    "accent": true
                                }
                            ];
                            if (d.kind === "ipc")
                                pills[0].label = "Action";
                            else if (d.kind === "calc")
                                pills[0].label = "Calc";
                            else if (d.kind === "web")
                                pills[0].label = "Web";
                            else if (d.terminal)
                                pills[0].label = "CLI";
                            if (!delMa.containsMouse)
                                return pills;
                            if (d.kind === "app") {
                                var kw = root._firstListToken(d.keywords);
                                var cat = root._firstListToken(d.categories);
                                if (kw.length > 0)
                                    pills.push({
                                        "label": kw,
                                        "accent": false
                                    });
                                if (cat.length > 0)
                                    pills.push({
                                        "label": cat,
                                        "accent": false
                                    });
                                if (kw.length === 0 && cat.length === 0)
                                    pills.push({
                                        "label": d.terminal ? "Terminal" : "Application",
                                        "accent": false
                                    });
                            } else if (d.kind === "ipc") {
                                pills.push({
                                    "label": d.ipcFunction,
                                    "accent": false
                                });
                            } else if (d.kind === "calc" && d.detail) {
                                pills.push({
                                    "label": d.detail,
                                    "accent": false
                                });
                            } else if (d.kind === "web" && d.detail) {
                                pills.push({
                                    "label": d.detail,
                                    "accent": false
                                });
                            }
                            return pills;
                        }

                        width: appList.width
                        height: Theme.launcherItemHeight + (del.isSelected ? root.commandExtra : 0)
                        transformOrigin: Item.Center

                        // Maximum scale is strictly 1.0 (matching the search bar width).
                        // Sibling items progressively shrink down based on distance from selected index.
                        readonly property real baseScale: Math.max(0.88, 1.0 - del.distance * 0.03)
                        readonly property real targetScale: del.isSelected ? 1.0 : (delMa.containsMouse ? Math.min(0.99, del.baseScale + 0.03) : del.baseScale)

                        scale: del.targetScale
                        Behavior on scale {
                            enabled: del.ready
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }

                        z: del.isSelected ? 20 : (15 - Math.min(10, del.distance))

                        // Floating Card with matching cornerLargeRadius
                        Rectangle {
                            id: itemCard
                            anchors.fill: parent
                            radius: Theme.cornerLargeRadius
                            color: del.isSelected ? Theme.hoveredBgColor : (delMa.containsMouse ? Theme.mutedBgColor : Theme.bgColor)
                            border.color: del.isSelected ? Theme.accent : Theme.mutedAccent
                            border.width: del.isSelected ? Theme.generalThickness : 1
                            antialiasing: true
                            smooth: true

                            opacity: (del.isSelected || delMa.containsMouse) ? 1.0 : Math.max(0.65, 1.0 - del.distance * 0.08)
                            Behavior on opacity {
                                Anim {
                                    type: Anim.DefaultEffects
                                }
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
                                    source: Quickshell.iconPath(del.modelData.icon || "application-x-executable", "application-x-executable")
                                    smooth: true
                                    mipmap: true
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
                                        font.pointSize: Theme.labelFontSize + 2
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }

                                    Text {
                                        width: parent.width
                                        text: del.modelData.comment || del.modelData.genericName || ""
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.9
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }

                                    // ── Command line: what will be executed (selectable) ──
                                    Row {
                                        width: parent.width
                                        height: del.isSelected ? 20 : 0
                                        visible: height > 0
                                        opacity: del.isSelected ? 1 : 0
                                        spacing: 6
                                        clip: true

                                        Behavior on height {
                                            Anim {
                                                type: Anim.DefaultSpatial
                                            }
                                        }
                                        Behavior on opacity {
                                            Anim {
                                                type: Anim.DefaultEffects
                                            }
                                        }

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
                                            text: root.commandFor(del.modelData)
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

                                // ── Tag row: kind pill + keyword/category pills ──
                                // Selected row only; hovering extends it with
                                // keyword/category pills (or a sensible fallback).
                                Row {
                                    id: tagRow
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: del.isSelected ? Math.min(tagRow.implicitWidth, appList.width * 0.5) : 0
                                    spacing: 6
                                    clip: true
                                    opacity: del.isSelected ? 1 : 0
                                    scale: del.isSelected ? 1 : 0.7
                                    transformOrigin: Item.Right
                                    visible: Layout.preferredWidth > 1

                                    Behavior on Layout.preferredWidth {
                                        Anim {
                                            type: Anim.DefaultSpatial
                                        }
                                    }
                                    Behavior on opacity {
                                        Anim {
                                            type: Anim.DefaultEffects
                                        }
                                    }
                                    Behavior on scale {
                                        Anim {
                                            type: Anim.DefaultSpatial
                                        }
                                    }

                                    Repeater {
                                        model: del.pillDefs
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: Math.min(pillLabel.implicitWidth + 20, 140)
                                            height: pillLabel.implicitHeight + 10
                                            radius: height * 0.5
                                            color: modelData.accent ? Theme.accent : "transparent"
                                            border.color: modelData.accent ? Theme.accent : Theme.mutedAccent
                                            border.width: 1
                                            clip: true

                                            Text {
                                                id: pillLabel
                                                width: Math.max(0, Math.min(implicitWidth, parent.width - 20))
                                                height: implicitHeight
                                                anchors.centerIn: parent
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                                text: modelData.label
                                                color: modelData.accent ? Theme.fgColor : Theme.mutedFgColor
                                                font.bold: modelData.accent
                                                font.pointSize: Theme.labelFontSize * 0.85
                                                font.family: Theme.labelFontFamily
                                                renderType: Text.CurveRendering
                                                antialiasing: true
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    appList.currentIndex = del.index;
                                    root.copyCommand(del.modelData);
                                } else {
                                    root.activateItem(del.modelData);
                                }
                            }
                            onEntered: appList.currentIndex = del.index
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
        if (!AppScanner.loaded)
            AppScanner.scan();
    }
}

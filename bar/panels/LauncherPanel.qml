import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root
    property var panelHost

    readonly property int maxVisibleItems: 5
    readonly property int itemSpacing:     6

    property var filteredApps: []
    readonly property int visibleCount:    filteredApps.length
    readonly property int displayCount:    Math.min(visibleCount, maxVisibleItems)
    readonly property bool hasResults:     visibleCount > 0 && searchInput.text.trim().length > 0

    // Currently active/selected index (defaults to first item when results are shown)
    readonly property int selectedIndex: (appList.currentIndex >= 0)
        ? appList.currentIndex
        : (hasResults ? 0 : -1)

    // Debounce timer: only recalculates at the end of each text change
    Timer {
        id: searchDebounce
        interval: 60
        repeat: false
        onTriggered: root.updateFilter()
    }

    function updateFilter() {
        var q = searchInput.text.toLowerCase().trim();
        if (!q) {
            root.filteredApps = [];
            appList.currentIndex = -1;
            return;
        }

        var results = [];
        var all = AppScanner.apps;
        for (var i = 0; i < all.length; i++) {
            if (root._matches(all[i], q)) {
                results.push(all[i]);
            }
        }
        root.filteredApps = results;
        appList.currentIndex = results.length > 0 ? 0 : -1;
        if (results.length > 0) {
            appList.positionViewAtBeginning();
        }
    }

    readonly property real listHeight: hasResults
        ? displayCount * Theme.launcherItemHeight
          + Math.max(0, displayCount - 1) * itemSpacing
        : 0

    readonly property real totalHeight: Theme.launcherSearchHeight
        + (hasResults ? itemSpacing + listHeight : 0)

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

    function toggle() { visible ? close() : open(); }

    function launchCurrent() {
        var idx = root.selectedIndex;
        if (idx < 0 || idx >= filteredApps.length) return;
        AppScanner.launch(filteredApps[idx]);
        close();
    }

    function moveSelection(delta) {
        if (filteredApps.length === 0) return;
        var current = (appList.currentIndex < 0) ? 0 : appList.currentIndex;
        var next = Math.max(0, Math.min(current + delta, filteredApps.length - 1));
        appList.currentIndex = next;
        appList.positionViewAtIndex(next, ListView.Contain);
    }

    function _matches(app, q) {
        return (app.name        && app.name.toLowerCase().includes(q))
            || (app.genericName && app.genericName.toLowerCase().includes(q))
            || (app.comment     && app.comment.toLowerCase().includes(q))
            || (app.keywords    && app.keywords.toLowerCase().includes(q));
    }

    Connections {
        target: AppScanner
        function onScanComplete() {
            root.updateFilter();
        }
    }

    visible: false
    focusable: true
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }

    MouseArea { anchors.fill: parent; onClicked: root.close() }

    FocusScope {
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:  root.close();         event.accepted = true; break;
            case Qt.Key_Up:      root.moveSelection(-1); event.accepted = true; break;
            case Qt.Key_Down:    root.moveSelection(1);  event.accepted = true; break;
            case Qt.Key_Return:
            case Qt.Key_Enter:   root.launchCurrent();  event.accepted = true; break;
            }
        }

        Item {
            id: launcher
            anchors.centerIn: parent
            width: Theme.launcherWidth

            // Smooth fluid height animation using M3 expressive bezier curve
            height: root.totalHeight
            Behavior on height {
                Anim { type: Anim.DefaultSpatial }
            }

            opacity: root.visible ? 1 : 0
            scale:   root.visible ? 1 : 0.94
            transformOrigin: Item.Center
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
            Behavior on scale   { Anim { type: Anim.DefaultSpatial  } }

            MouseArea { anchors.fill: parent; onClicked: {} }

            // ── Search bar pill ─────────────────────────────────────────────
            Rectangle {
                id: searchBar
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.right: parent.right
                height: Theme.launcherSearchHeight

                radius: Theme.cornerLargeRadius
                color: Theme.bgColor
                border.color: searchInput.activeFocus ? Theme.accent : Theme.mutedAccent
                border.width: Theme.generalThickness
                antialiasing: true
                smooth: true
                Behavior on border.color { CAnim {} }

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
                            Anim { type: Anim.DefaultEffects }
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
                    Anim { type: Anim.DefaultSpatial }
                }

                opacity: root.hasResults ? 1 : 0
                Behavior on opacity { Anim { type: Anim.DefaultEffects } }

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

                        width:  appList.width
                        height: Theme.launcherItemHeight
                        transformOrigin: Item.Center

                        // Maximum scale is strictly 1.0 (matching the search bar width).
                        // Sibling items progressively shrink down based on distance from selected index.
                        readonly property real baseScale: Math.max(0.88, 1.0 - del.distance * 0.03)
                        readonly property real targetScale: del.isSelected
                            ? 1.0
                            : (delMa.containsMouse ? Math.min(0.99, del.baseScale + 0.03) : del.baseScale)

                        scale: del.targetScale
                        Behavior on scale {
                            enabled: del.ready
                            Anim { type: Anim.DefaultSpatial }
                        }

                        z: del.isSelected ? 20 : (15 - Math.min(10, del.distance))

                        // Floating Card with matching cornerLargeRadius
                        Rectangle {
                            id: itemCard
                            anchors.fill: parent
                            radius: Theme.cornerLargeRadius
                            color: del.isSelected
                                ? Theme.hoveredBgColor
                                : (delMa.containsMouse ? Theme.mutedBgColor : Theme.bgColor)
                            border.color: del.isSelected ? Theme.accent : Theme.mutedAccent
                            border.width: del.isSelected ? Theme.generalThickness : 1
                            antialiasing: true
                            smooth: true

                            opacity: (del.isSelected || delMa.containsMouse)
                                ? 1.0
                                : Math.max(0.65, 1.0 - del.distance * 0.08)
                            Behavior on opacity {
                                Anim { type: Anim.DefaultEffects }
                            }

                            Behavior on color        { CAnim {} }
                            Behavior on border.color { CAnim {} }
                            Behavior on border.width {
                                NumberAnimation { duration: Theme.fastEffectsDuration }
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin:  18
                                    rightMargin: 18
                                }
                                spacing: 14

                                IconImage {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitSize: Theme.launcherIconSize
                                    source: Quickshell.iconPath(
                                        del.modelData.icon || "application-x-executable",
                                        "application-x-executable"
                                    )
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
                                        text: del.modelData.comment
                                           || del.modelData.genericName
                                           || ""
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.9
                                        font.family: Theme.labelFontFamily
                                        elide: Text.ElideRight
                                        visible: text.length > 0
                                        renderType: Text.CurveRendering
                                        antialiasing: true
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { AppScanner.launch(del.modelData); root.close(); }
                            onEntered: appList.currentIndex = del.index
                            onWheel: (wheel) => {
                                wheel.accepted = false; // Allow ListView to handle scrolling
                            }
                        }
                    }

                    Text {
                        visible: root.filteredApps.length === 0
                            && AppScanner.loaded
                            && searchInput.text.trim().length > 0
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
        if (!AppScanner.loaded) AppScanner.scan();
    }
}

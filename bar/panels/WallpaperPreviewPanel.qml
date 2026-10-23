import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root
    property var panelHost

    // Tab Index Memory & Navigation Rate Limiting
    property var savedTabIndices: ({})
    property double lastStepTime: 0
    property double lastTabStepTime: 0
    readonly property int stepCooldownMs: {
        const type = WallpaperService.currentWallpaper ? WallpaperService.currentWallpaper.type : "";
        if (type === "image")
            return 50;
        if (type === "video")
            return 500;
        return 0;
    } // Minimum delay in ms between navigation steps

    function throttledStep(direction) {
        var now = Date.now();
        if (now - lastStepTime < stepCooldownMs)
            return;
        lastStepTime = now;
        WallpaperService.step(direction);
    }

    function throttledStepTab(direction) {
        var now = Date.now();
        if (now - lastTabStepTime < stepCooldownMs)
            return;
        lastTabStepTime = now;
        stepTab(direction);
    }

    function switchTab(targetTabId) {
        if (!targetTabId || targetTabId === WallpaperService.currentTab)
            return;
        WallpaperService.setTab(targetTabId);
    }

    function stepTab(direction) {
        var tabs = WallpaperService.availableTabs;
        if (!tabs || tabs.length <= 1)
            return;

        var curId = WallpaperService.currentTab;
        var idx = -1;
        for (var i = 0; i < tabs.length; i++) {
            if (tabs[i].id === curId) {
                idx = i;
                break;
            }
        }

        if (idx !== -1) {
            var nextIdx = (idx + direction + tabs.length) % tabs.length;
            switchTab(tabs[nextIdx].id);
        }
    }

    // Panel control
    function open() {
        if (panelHost && panelHost.hideAllPanelExcept)
            panelHost.hideAllPanelExcept("wallpaperPreview");
        visible = true;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["wallpaperPreview"] = root;
        autoCloseTimer.restart();
    }

    function close() {
        visible = false;
        if (panelHost && panelHost.toggledPanels)
            panelHost.toggledPanels["wallpaperPreview"] = false;
        autoCloseTimer.stop();
    }

    function nextWallpaper() {
        WallpaperService.next();
        open();
    }
    function previousWallpaper() {
        WallpaperService.previous();
        open();
    }
    function showWallpaper() {
        open();
    }

    Connections {
        target: WallpaperService
        function onRequestShowPreview() {
            root.open();
        }
        function onRequestHidePreview() {
            root.close();
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

    Timer {
        id: autoCloseTimer
        interval: 5000
        repeat: false
        onTriggered: root.close()
    }

    function resetTimer() {
        autoCloseTimer.restart();
    }

    // Dismiss on background click
    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: root.visible

        Keys.onPressed: event => {
            resetTimer();
            switch (event.key) {
            case Qt.Key_Escape:
                root.close();
                event.accepted = true;
                break;
            case Qt.Key_Left:
            case Qt.Key_Backtab:
                root.throttledStep(-1);
                event.accepted = true;
                break;
            case Qt.Key_Right:
            case Qt.Key_Tab:
                root.throttledStep(1);
                event.accepted = true;
                break;
            case Qt.Key_Up:
                root.throttledStepTab(-1);
                event.accepted = true;
                break;
            case Qt.Key_Down:
                root.throttledStepTab(1);
                event.accepted = true;
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.close();
                event.accepted = true;
                break;
            }
        }

        // Centered Card
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(focusScope.width - 64, 1160)

            // Header + tabs + carousel + margins
            height: headerRow.implicitHeight + tabRow.implicitHeight + carouselHeight + 18 * 4 + 10 * 2

            readonly property int carouselHeight: 180

            color: Theme.bgColor
            border.color: Theme.mutedAccent
            border.width: Theme.generalThickness
            radius: Theme.cornerLargeRadius

            opacity: root.visible ? 1 : 0
            scale: root.visible ? 1 : 0.92
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
                onClicked: resetTimer()
            }

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: 18
                }
                spacing: 10

                // Header
                RowLayout {
                    id: headerRow
                    Layout.fillWidth: true
                    spacing: 10

                    IconImage {
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: 20
                        source: Quickshell.iconPath("preferences-desktop-wallpaper", "image-x-generic")
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        text: WallpaperService.currentWallpaper ? WallpaperService.currentWallpaper.name : "Wallpapers"
                        font.pointSize: Theme.labelFontSize * 1.2
                        font.family: Theme.labelFontFamily
                        font.bold: true
                        color: Theme.fgColor
                        elide: Text.ElideRight
                    }

                    // Type tag pill
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: 22
                        implicitWidth: tagTxt.implicitWidth + 14
                        radius: Theme.cornerRadius
                        color: {
                            const w = WallpaperService.currentWallpaper;
                            const t = ((w && (w.type || w.tag)) || "").toString().toLowerCase();
                            if (t === "video")
                                return "#CC8C00BA";
                            if (t === "gradient")
                                return "#CC3B82F6";
                            if (t === "color" || t === "solid")
                                return "#CCF59E0B";
                            return Theme.accent;
                        }
                        Behavior on color {
                            CAnim {}
                        }
                        Behavior on implicitWidth {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        Text {
                            id: tagTxt
                            anchors.centerIn: parent
                            text: {
                                const w = WallpaperService.currentWallpaper;
                                if (!w)
                                    return "IMAGE";
                                const t = ((w.type || w.tag) || "").toString().toLowerCase();
                                if (t === "video")
                                    return "VIDEO";
                                if (t === "gradient")
                                    return "GRADIENT";
                                if (t === "color" || t === "solid")
                                    return "SOLID";
                                return "IMAGE";
                            }
                            font.pointSize: Theme.labelFontSize * 0.8
                            font.family: Theme.labelFontFamily
                            font.bold: true
                            color: "#FFF"
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: WallpaperService.currentTabItems ? ((WallpaperService.currentTabIndex + 1) + " / " + WallpaperService.currentTabItems.length) : ""
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        color: Theme.mutedFgColor
                    }

                    ClickButton {
                        symbol: "window-close"
                        size: 24
                        onPress: root.close()
                    }
                }

                // Tab pills
                RowLayout {
                    id: tabRow
                    Layout.fillWidth: true
                    spacing: 8
                    visible: WallpaperService.availableTabs && WallpaperService.availableTabs.length > 1
                    Repeater {
                        model: WallpaperService.availableTabs

                        delegate: Rectangle {
                            id: tPill
                            required property var modelData
                            required property int index

                            readonly property bool sel: WallpaperService.currentTab === tPill.modelData.id

                            implicitHeight: 26
                            implicitWidth: tInner.implicitWidth + 20
                            radius: Theme.cornerRadius
                            color: sel ? Theme.accent : (tMa.containsMouse ? Theme.hoveredBgColor : Theme.mutedBgColor)
                            border.color: sel ? Theme.accent : Theme.mutedAccent
                            border.width: 1

                            Behavior on color {
                                CAnim {}
                            }
                            Behavior on border.color {
                                CAnim {}
                            }

                            MouseArea {
                                id: tMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    switchTab(tPill.modelData.id);
                                    resetTimer();
                                }
                            }

                            Row {
                                id: tInner
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: tPill.modelData.name
                                    font.pointSize: Theme.labelFontSize * 0.9
                                    font.family: Theme.labelFontFamily
                                    font.bold: tPill.sel
                                    color: tPill.sel ? Theme.fgColor : Theme.mutedFgColor
                                }
                                Text {
                                    text: "(" + tPill.modelData.count + ")"
                                    font.pointSize: Theme.labelFontSize * 0.78
                                    font.family: Theme.labelFontFamily
                                    color: tPill.sel ? "#CCffffff" : Theme.mutedAccent
                                }
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }

                // Carousel Container
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: card.carouselHeight

                    // Edge Mask clipping source matching carouselLayer dimensions
                    Rectangle {
                        id: edgeMask
                        anchors.fill: carouselLayer
                        visible: false
                        layer.enabled: true

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: "black"
                            }
                            GradientStop {
                                position: 0.25
                                color: "transparent"
                            }
                            GradientStop {
                                position: 0.75
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1.0
                                color: "black"
                            }
                        }
                    }

                    // Layer with expanded vertical margins (-40px top/bottom)
                    Item {
                        id: carouselLayer
                        anchors {
                            fill: parent
                            topMargin: -40
                            bottomMargin: -40
                        }
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: edgeMask
                            maskThresholdMin: 0.0
                            maskSpreadAtMin: 0.5
                            maskThresholdMax: 0.5
                            maskSpreadAtMax: 0.5
                        }

                        PathView {
                            id: pathView
                            anchors {
                                fill: parent
                                topMargin: 40
                                bottomMargin: 40
                            }

                            model: WallpaperService.currentTabItems
                            currentIndex: WallpaperService.currentTabIndex

                            pathItemCount: Math.max(1, Math.min(count, 7))

                            preferredHighlightBegin: 0.5
                            preferredHighlightEnd: 0.5
                            highlightRangeMode: PathView.StrictlyEnforceRange
                            snapMode: PathView.SnapToItem

                            interactive: false

                            // PathView can reset its own currentIndex while the
                            // model is populated on startup, which breaks the
                            // declarative binding. Re-apply the service index
                            // after the model has settled and whenever it changes.
                            function syncCurrentIndex() {
                                const idx = WallpaperService.currentTabIndex;
                                if (idx >= 0 && idx < count && currentIndex !== idx)
                                    currentIndex = idx;
                            }

                            Component.onCompleted: Qt.callLater(syncCurrentIndex)
                            onCountChanged: Qt.callLater(syncCurrentIndex)

                            Connections {
                                target: WallpaperService

                                function onCurrentTabIndexChanged() {
                                    Qt.callLater(pathView.syncCurrentIndex);
                                }
                                function onCurrentTabItemsChanged() {
                                    Qt.callLater(pathView.syncCurrentIndex);
                                }
                            }

                            path: Path {
                                startX: -136
                                startY: pathView.height / 2
                                PathLine {
                                    x: pathView.width + 136
                                    y: pathView.height / 2
                                }
                            }

                            // Delegate
                            delegate: Item {
                                id: del
                                visible: true
                                required property var modelData
                                required property int index

                                readonly property bool isCur: PathView.isCurrentItem
                                // Calculate distance from currently focused carousel index
                                readonly property int indexDiff: Math.abs(PathView.view.currentIndex - index)
                                // Only load texture if delegate is within active preview window (+/- 3 items)
                                readonly property bool inViewRange: (indexDiff <= 3 || indexDiff >= (PathView.view.count - 3)) && root.visible
                                width: 220
                                height: 124

                                scale: del.isCur ? 1.14 : (delMa.containsMouse ? 1.03 : 0.88)
                                z: del.isCur ? 10 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.spatialDuration
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                MouseArea {
                                    id: delMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        WallpaperService.select(index);
                                        resetTimer();
                                    }
                                }

                                RectangularShadow {
                                    z: -1
                                    anchors.fill: clip16x9
                                    color: Theme.accent
                                    radius: Theme.cornerRadius
                                    spread: del.isCur ? 10 : 0
                                    blur: del.isCur ? 24 : 0
                                    opacity: del.isCur ? 1.0 : 0.0

                                    Behavior on spread {
                                        NumberAnimation {
                                            duration: 400
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    Behavior on blur {
                                        NumberAnimation {
                                            duration: 400
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 400
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }

                                ClippingRectangle {
                                    id: clip16x9
                                    anchors.fill: parent
                                    radius: Theme.cornerRadius
                                    border.width: del.isCur ? 4 : 2
                                    border.color: del.isCur ? Theme.accent : (delMa.containsMouse ? Theme.fgColor : Theme.mutedAccent)
                                    color: Theme.mutedBgColor

                                    Behavior on border.color {
                                        CAnim {}
                                    }

                                    // Image or Video Thumbnail
                                    Image {
                                        id: thumbImage
                                        anchors.fill: parent
                                        fillMode: Image.PreserveAspectCrop

                                        opacity: status === Image.Ready ? 1.0 : 0.0
                                        visible: opacity > 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: Theme.animationDuration
                                                easing.type: Easing.InOutQuad
                                            }
                                        }

                                        source: {
                                            if (!root.visible || !del.inViewRange)
                                                return "";
                                            if (!modelData)
                                                return "";
                                            if (modelData.type === "image")
                                                return modelData.path || "";
                                            // C++ video entries expose no thumbnail/preview:
                                            // fall through to the video fallback card below.
                                            return "";
                                        }
                                        sourceSize: Qt.size(del.width, del.height)
                                        asynchronous: true
                                        mipmap: true
                                        smooth: true
                                        cache: true
                                    }

                                    // Fallback Card (when Video has no valid thumbnail image)
                                    Item {
                                        anchors.fill: parent
                                        visible: modelData && modelData.type === "video" && thumbImage.status !== Image.Ready

                                        Rectangle {
                                            anchors.fill: parent
                                            color: Theme.mutedBgColor

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 6

                                                IconImage {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    implicitSize: 32
                                                    source: Quickshell.iconPath("video-x-generic", "media-playback-start")
                                                }

                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.maximumWidth: 180
                                                    text: modelData.name || "Video Wallpaper"
                                                    font.pointSize: Theme.labelFontSize * 0.8
                                                    font.family: Theme.labelFontFamily
                                                    color: Theme.mutedFgColor
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }
                                    }

                                    // Gradient
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: (modelData ? modelData.type : "") === "gradient"
                                        gradient: Gradient {
                                            orientation: Gradient.Vertical
                                            GradientStop {
                                                position: 0.0
                                                color: (modelData && modelData.colors && modelData.colors.length > 0) ? modelData.colors[0] : "#000"
                                            }
                                            GradientStop {
                                                position: 1.0
                                                color: (modelData && modelData.colors && modelData.colors.length > 1) ? modelData.colors[1] : "#FFF"
                                            }
                                        }
                                    }

                                    // Solid Color
                                    Rectangle {
                                        anchors.fill: parent
                                        visible: (modelData ? modelData.type : "") === "color"
                                        color: (modelData && modelData.color) ? modelData.color : "#0A0A0D"
                                    }

                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

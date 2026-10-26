import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import QtQuick.Controls
import PeakShell
import PeakShell.Services
import "root:/"
import "root:/components"
import "root:/services"
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Networking

Rectangle {
    // Properties
    id: root
    required property var panelHost
    required property var sysItems
    readonly property string icon: Distro.distroIcon
    readonly property string username: Quickshell.env("USER") || "User"
    property string label: "I use Arch btw"
    property bool lowPowerNotified: false
    property real batteryPercent: UPower.displayDevice ? UPower.displayDevice.percentage : 1
    onBatteryPercentChanged: {
        const percent = Math.round(batteryPercent * 100);
        if (UPower.onBattery && percent <= Theme.lowPowerThreshold) {
            if (!lowPowerNotified) {
                Utils.notify("Low Power", "Please charge your arch gng!", "battery-caution");
                lowPowerNotified = true;
            }
        } else {
            lowPowerNotified = false;
        }
    }
    ServiceRef {
        service: NetworkUsage
    }

    // Functions
    function togglePanel() {
        dashLoader.active = true;
        const dash = dashLoader.item;
        panelHost.hideAllPanelExcept("arch");
        dash.visible = !dash.visible;
        hoverDebounce.isDelaying = true;
        hoverDebounce.restart();
        if (dash.visible)
            panelHost.toggledPanels["arch"] = dash;
        else
            panelHost.toggledPanels["arch"] = false;
    }

    // Transitions
    width: container.width + 32
    Behavior on width {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    Behavior on color {
        CAnim {}
    }
    // Styling
    color: {
        if (mouseArea.containsMouse)
            return Theme.hoveredBgColor;
        return Theme.bgColor;
    }
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    // Controls animation on color change + Click
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onEntered: {
            hoverDebounce.isDelaying = true;
            hoverDebounce.restart();
            root.label = "I use Arch btw";
        }
        onClicked: root.togglePanel()
    }
    Timer {
        id: hoverDebounce
        property bool isDelaying: false
        interval: Theme.hoverDuration
        repeat: false
        running: !mouseArea.containsMouse && isDelaying

        onTriggered: {
            isDelaying = false;
        }
    }
    // Icon / Label Text
    Row {
        id: container
        anchors.centerIn: parent
        spacing: 5
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Theme.iconFontSize
            source: Quickshell.iconPath(root.icon, "distributor-logo")
        }
        Text {
            visible: hoverDebounce.isDelaying || mouseArea.containsMouse || UPower.onBattery
            anchors.verticalCenter: parent.verticalCenter
            text: UPower.onBattery ? "Discharging..." : root.label
            font.pointSize: Theme.labelFontSize
            font.family: Theme.labelFontFamily
            color: Theme.fgColor
            elide: Text.ElideRight
            opacity: visible ? 1 : 0
            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
    // Popup Part (lazy: instantiated in background, forced on first open)
    LazyLoader {
        id: dashLoader
        loading: true
        PanelWindow {
            id: dashboard
            //screen: root.panelHost ? root.panelHost.screen : null
            visible: false
            focusable: true
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            //exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // Dismiss on clicking outside
            MouseArea {
                anchors.fill: parent
                onClicked: dashboard.visible = false
            }
            // The Esc => close
            FocusScope {
                anchors.fill: parent
                focus: dashboard.visible
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        dashboard.visible = false;
                        event.accepted = true;
                    }
                }
            }
            // Actual Dashboard
            Item {
                z: 1
                width: Theme.dashboardWidth
                height: mainColumn.height
                x: Theme.barHorizontalPad
                visible: dashboard.visible

                opacity: dashboard.visible ? 1 : 0
                scale: dashboard.visible ? 1 : 0.94
                transformOrigin: Item.TopLeft

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

                // Absorb clicks so they don't reach the dismiss area
                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                ColumnLayout {
                    id: mainColumn
                    spacing: 5

                    // Dashboard Title
                    Rectangle {
                        Layout.preferredHeight: 50
                        Layout.preferredWidth: Theme.dashboardWidth
                        Layout.alignment: Qt.AlignCenter
                        color: Theme.bgColor
                        border.color: Theme.mutedAccent
                        border.width: Theme.generalThickness
                        radius: Theme.cornerLargeRadius

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.cornerRadius
                            anchors.rightMargin: Theme.cornerRadius
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: Theme.iconFontSize
                                source: Quickshell.iconPath("deadbeef-panel")
                            }
                            Text {
                                text: `<b>Dashboard</b>`
                                anchors.verticalCenter: parent.verticalCenter
                                x: Theme.cornerLargeRadius
                                font.pointSize: Theme.labelFontSize * 1.4
                                font.family: Theme.labelFontFamily
                                color: Theme.fgColor
                            }
                            ClickButton {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                symbol: "systemsettings-alt"
                                size: 36
                                onPress: () => {
                                    root.togglePanel();
                                    panelHost.openSettings();
                                }
                            }
                        }
                    }
                    // Quick Controls
                    Rectangle {
                        Layout.preferredHeight: 225
                        Layout.preferredWidth: Theme.dashboardWidth
                        Layout.alignment: Qt.AlignCenter
                        color: Theme.bgColor
                        border.color: Theme.mutedAccent
                        border.width: Theme.generalThickness
                        radius: Theme.cornerLargeRadius

                        GridLayout {
                            anchors.fill: parent
                            columns: 3
                            rows: 2
                            uniformCellWidths: true
                            uniformCellHeights: true
                            // Add implementation later
                            ToggleButton {
                                symbol: INetwork.networkStrengthIcon
                                isChecked: Networking.wifiEnabled
                                label: INetwork.connectionMessage
                                onPress: INetwork.setWifi(this.isChecked)
                            }
                            ToggleButton {
                                symbol: BluetoothResolve.icon
                                isChecked: BluetoothResolve.bluetoothEnabled
                                label: BluetoothResolve.status
                                onPress: BluetoothResolve.setBluetooth(this.isChecked)
                            }

                            ToggleButton {
                                symbol: "system-search"
                                isChecked: false
                                label: "Search"
                                onPress: () => {
                                    this.isChecked = false;
                                    root.togglePanel();
                                    panelHost.openLauncher();
                                }
                            }

                            ToggleButton {
                                symbol: Notifications.barIcon
                                isChecked: !Notifications.isDndOn
                                label: Notifications.message
                                onPress: Notifications.toggleDnd()
                            }

                            ToggleButton {
                                symbol: "org.kde.gwenview"
                                isChecked: false
                                label: "Idle Inhibit"
                            }

                            ToggleButton {
                                symbol: "battery-profile-powersave"
                                isChecked: PowerProfile.toString(PowerProfiles.profile) === "PowerSaver"
                                label: "Power Saver"
                                onPress: {
                                    if (!this.isChecked) {
                                        Utils.execute("powerprofilesctl", ["set", "balanced"]);
                                    } else
                                        Utils.execute("powerprofilesctl", ["set", "power-saver"]);
                                }
                            }
                        }
                    }
                    // Volume
                    Rectangle {
                        Layout.preferredHeight: 125
                        Layout.preferredWidth: Theme.dashboardWidth
                        Layout.alignment: Qt.AlignCenter
                        color: Theme.bgColor
                        border.color: Theme.mutedAccent
                        border.width: Theme.generalThickness
                        radius: Theme.cornerLargeRadius
                        // Prevent clicks inside card from propagating to background dismiss
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {}
                        }
                        // Scroll / trackpad gesture navigation
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                            onWheel: event => {
                                var node = Pipewire.defaultAudioSink;
                                if (!node)
                                    return;
                                var volume = node.audio.volume;
                                if (event.angleDelta.y > 0) {
                                    // Scroll up → Volume up
                                    volume = Math.min(volume + 0.05, 1);
                                } else if (event.angleDelta.y < 0) {
                                    // Scroll down → Volume down
                                    volume = Math.max(volume - 0.05, 0);
                                }
                                node.audio.volume = volume;
                                // Show the OSD even when the value was already
                                // clamped at 0 or 1 and therefore did not change.
                                Osd.showVolumeLevel("sink", volume, node.audio.muted);
                                event.accepted = true;
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.topMargin: Theme.cornerRadius
                            anchors.bottomMargin: Theme.cornerRadius
                            anchors.leftMargin: Theme.cornerLargeRadius
                            anchors.rightMargin: Theme.cornerLargeRadius
                            spacing: 8
                            Row {
                                spacing: 8
                                IconImage {
                                    implicitSize: Theme.iconFontSize
                                    source: Quickshell.iconPath("audio-speakers")
                                }
                                Text {
                                    text: "VOLUME"
                                    color: Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize * 1.2
                                    font.family: Theme.labelFontFamily
                                }
                            }
                            RowLayout {
                                spacing: 8
                                ClickButton {
                                    symbol: PipewireResolve.outputIcon
                                    size: 36
                                    bgColor: "transparent"
                                    onPress: () => {
                                        if (Pipewire.defaultAudioSink)
                                            Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                                    }
                                }
                                Slider {
                                    id: volumeSlider
                                    focusPolicy: Qt.NoFocus
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 1 // its from 0 -> 1
                                    value: visible ? Pipewire.defaultAudioSink.audio.volume : 0
                                    Behavior on value {
                                        Anim {
                                            type: Anim.SlowSpatial
                                        }
                                    }

                                    background: Rectangle {
                                        x: volumeSlider.leftPadding
                                        //: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                        implicitHeight: 6
                                        width: volumeSlider.availableWidth
                                        height: implicitHeight
                                        radius: 3
                                        color: Theme.mutedBgColor // Inactive track color

                                        // Active track color
                                        Rectangle {
                                            width: volumeSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: Theme.accent // Active track color
                                            radius: 3
                                        }
                                    }
                                    handle: Rectangle {
                                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 12
                                        implicitHeight: 12
                                        radius: 12
                                        scale: volumeSlider.pressed ? 1.5 : 1.0
                                        Behavior on scale {
                                            Anim {
                                                type: Anim.DefaultSpatial
                                            }
                                        }
                                        color: Theme.accent
                                    }
                                    onMoved: {
                                        const node = Pipewire.defaultAudioSink;
                                        if (!node || !node.audio)
                                            return;
                                        node.audio.volume = volumeSlider.value;
                                        Osd.showVolumeLevel("sink", volumeSlider.value, node.audio.muted);
                                    }
                                }
                                Text {
                                    text: Math.round(volumeSlider.value * 100) + "%"
                                    color: Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize
                                    font.family: Theme.labelFontFamily
                                }
                            }
                            LabelButton {
                                maxWidth: parent.width * 0.8
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                label: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.description : "Unknown" // <- The proper name
                                onPress: {
                                    dashboard.visible = false;
                                    sysItems.openSoundPanel();
                                }
                            }
                        }
                    }
                    // Media
                    Rectangle {
                        id: mediaContainer
                        Layout.preferredHeight: 175
                        Layout.preferredWidth: Theme.dashboardWidth
                        Layout.alignment: Qt.AlignCenter
                        color: Theme.bgColor
                        border.color: Theme.mutedAccent
                        border.width: Theme.generalThickness
                        radius: Theme.cornerLargeRadius
                        onPlayerChanged: {
                            if (mediaContainer.player)
                                mediaContainer.player.positionChanged();
                        }
                        onVisibleChanged: {
                            if (mediaContainer.player)
                                mediaContainer.player.positionChanged();
                        }
                        readonly property var player: MprisController.activePlayer
                        Timer {
                            running: mediaContainer.player && mediaContainer.player.playbackState === MprisPlaybackState.Playing && parent.visible
                            interval: Theme.mediaPlayerUpdateDuration
                            repeat: true

                            onTriggered: {
                                mediaContainer.player.positionChanged();
                            }
                        }
                        Connections {
                            target: mediaContainer.player

                            function onPostTrackChanged() {
                                mediaContainer.player.positionChanged();
                            }
                        }
                        visible: {
                            return player;
                        }
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.topMargin: Theme.cornerRadius
                            anchors.bottomMargin: Theme.cornerLargeRadius
                            anchors.leftMargin: Theme.cornerLargeRadius
                            anchors.rightMargin: Theme.cornerLargeRadius
                            spacing: 8
                            Row {
                                spacing: 8
                                IconImage {
                                    implicitSize: Theme.iconFontSize
                                    source: Quickshell.iconPath("com.github.neithern.g4music")
                                }
                                Text {
                                    //text: "NOW PLAYING"
                                    text: "NOW PLAYING"
                                    color: Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize * 1.2
                                    font.family: Theme.labelFontFamily
                                }
                            }
                            RowLayout {
                                spacing: 14
                                MediaArt {
                                    height: Theme.thumbnailSize
                                    width: Theme.thumbnailSize
                                    radius: Theme.cornerRadius
                                    source: mediaContainer.player ? mediaContainer.player.trackArtUrl : ""
                                    active: dashboard.visible
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    Text {
                                        text: mediaContainer.player ? mediaContainer.player.trackTitle : "Unknown"
                                        color: Theme.fgColor
                                        width: parent.width
                                        font.pointSize: Theme.labelFontSize
                                        elide: Text.ElideRight
                                        font.family: Theme.labelFontFamily
                                    }
                                    Text {
                                        text: mediaContainer.player ? mediaContainer.player.trackArtist : "Unknown"
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize
                                        elide: Text.ElideRight
                                        font.family: Theme.labelFontFamily
                                    }
                                }

                                Row {
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 8
                                    ClickButton {
                                        symbol: "media-seek-backward"
                                        size: 36
                                        onPress: () => {
                                            MprisController.previous();
                                        }
                                    }
                                    ToggleButton {
                                        size: 36
                                        symbol: this.isChecked ? "media-playback-pause" : "media-playback-start"
                                        isChecked: mediaContainer.player ? mediaContainer.player.isPlaying : false
                                        label: ""
                                        onPress: () => {
                                            MprisController.togglePlaying();
                                        }
                                    }
                                    ClickButton {
                                        symbol: "media-seek-forward"
                                        size: 36
                                        onPress: () => {
                                            MprisController.next();
                                        }
                                    }
                                }
                            }
                            // Slider and Duration
                            ColumnLayout {
                                Layout.alignment: Qt.AlignTop
                                spacing: 6
                                Slider {
                                    id: playerSlider
                                    focusPolicy: Qt.NoFocus
                                    property real releaseValue: 0

                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    from: 0
                                    to: mediaContainer.player ? mediaContainer.player.length : 1

                                    value: {
                                        if (visible)
                                            return playerSlider.pressed ? playerSlider.value : (mediaContainer.player ? mediaContainer.player.position : 0);
                                        else
                                            return 0;
                                    }
                                    Behavior on value {
                                        NumberAnimation {
                                            duration: Theme.mediaPlayerUpdateDuration
                                            easing.type: Easing.OutExpo
                                        }
                                    }
                                    background: Rectangle {
                                        x: playerSlider.leftPadding
                                        y: playerSlider.topPadding + playerSlider.availableHeight / 2 - height / 2
                                        implicitHeight: 6
                                        width: playerSlider.availableWidth
                                        height: implicitHeight
                                        radius: 3
                                        color: Theme.mutedBgColor // Inactive track color

                                        // Active track color
                                        Rectangle {
                                            width: playerSlider.visualPosition * parent.width
                                            height: parent.height
                                            color: Theme.accent // Active track color
                                            radius: 3
                                        }
                                    }
                                    handle: Rectangle {
                                        x: playerSlider.leftPadding + playerSlider.visualPosition * (playerSlider.availableWidth - width)
                                        y: playerSlider.topPadding + playerSlider.availableHeight / 2 - height / 2
                                        implicitWidth: 12
                                        implicitHeight: 12
                                        radius: 12
                                        // scale: playerSlider.pressed ? 1.5 : 1.0
                                        // Behavior on scale {
                                        //     NumberAnimation {
                                        //         duration: Theme.animationDuration
                                        //         easing.type: Easing.OutExpo
                                        //     }
                                        // }
                                        color: "transparent"
                                    }
                                    onMoved: {
                                        seekDebounce.restart();
                                        playerSlider.releaseValue = playerSlider.value;
                                    }
                                    Timer {
                                        id: seekDebounce
                                        interval: 100
                                        repeat: false

                                        onTriggered: {
                                            console.log("Changed to: " + playerSlider.releaseValue);
                                            mediaContainer.player.position = playerSlider.releaseValue;
                                        }
                                    }
                                }
                                // Bottom Timer
                                Item {
                                    id: textPositionContainer
                                    function formatTime(seconds) {
                                        let mins = Math.floor(seconds / 60);
                                        let secs = Math.floor(seconds % 60);

                                        return mins.toString().padStart(1, "0") + ":" + secs.toString().padStart(2, "0");
                                    }
                                    Layout.fillWidth: true
                                    Text {
                                        anchors.left: parent.left
                                        text: parent.formatTime(mediaContainer.player ? mediaContainer.player.position : 0)
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.9
                                        font.family: Theme.labelFontFamily
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        text: parent.formatTime(mediaContainer.player ? mediaContainer.player.length : 0)
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.9
                                        font.family: Theme.labelFontFamily
                                    }
                                }
                            }
                        }
                    }
                    // Battery & Network
                    RowLayout {
                        Layout.preferredHeight: 120
                        Layout.preferredWidth: Theme.dashboardWidth
                        spacing: 8
                        // Battery
                        Rectangle {
                            // Battery readout and power-mode picker: laptop only.
                            visible: Platform.isLaptop
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignCenter
                            color: Theme.bgColor
                            border.color: Theme.mutedAccent
                            border.width: Theme.generalThickness
                            radius: Theme.cornerLargeRadius
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.topMargin: Theme.cornerRadius
                                anchors.bottomMargin: Theme.cornerRadius
                                anchors.leftMargin: Theme.cornerRadius * 1.5
                                anchors.rightMargin: Theme.cornerRadius * 1.5
                                // Battery Icon & Percentage
                                Row {
                                    spacing: 5
                                    Layout.alignment: Qt.AlignVCenter
                                    IconImage {
                                        implicitSize: Theme.iconFontSize
                                        source: Quickshell.iconPath("preferences-power-and-battery")
                                    }
                                    Text {
                                        text: "BATTERY"
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 1.2
                                        font.family: Theme.labelFontFamily
                                    }
                                }
                                RowLayout {
                                    spacing: 5
                                    Layout.alignment: Qt.AlignVCenter
                                    IconImage {
                                        Layout.alignment: Qt.AlignVCenter
                                        implicitSize: Theme.iconFontSize
                                        source: Quickshell.iconPath(getIcon())

                                        function getIcon() {
                                            const percentage = Math.round(root.batteryPercent * 100);
                                            const p = Math.max(0, Math.min(100, percentage));

                                            const step = Math.floor(p / 10) * 10;
                                            const formatted = String(step).padStart(3, '0');

                                            let icon = `battery-${formatted}`;

                                            if (!UPower.onBattery) {
                                                icon += "-charging";
                                            }

                                            return icon;
                                        }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignVCenter
                                        text: Math.round(root.batteryPercent * 100) + "%"
                                        color: Theme.fgColor
                                        font.pointSize: Theme.labelFontSize
                                        font.family: Theme.labelFontFamily
                                    }
                                }
                                ProgressBar {
                                    id: powerLevel
                                    implicitHeight: 6
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    from: 0
                                    to: 1
                                    value: visible ? root.batteryPercent : 0
                                    Behavior on value {
                                        Anim {
                                            type: Anim.SlowSpatial
                                        }
                                    }
                                    background: Item {}
                                    contentItem: Rectangle {
                                        implicitHeight: 6
                                        radius: 3
                                        color: Theme.mutedBgColor
                                        Rectangle {
                                            width: powerLevel.visualPosition * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: Theme.battery
                                        }
                                    }
                                }
                                Rectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    color: powerModeMouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
                                    height: powerModeRow.height
                                    radius: Theme.cornerRadius
                                    Layout.fillWidth: true
                                    ToolTip.visible: false
                                    ToolTip.text: "Scroll to change power modes!"
                                    Behavior on color {
                                        CAnim {}
                                    }
                                    MouseArea {
                                        id: powerModeMouseArea
                                        hoverEnabled: true
                                        anchors.fill: parent
                                        onWheel: wheel => {
                                            const mode = PowerProfile.toString(PowerProfiles.profile);
                                            if (wheel.angleDelta.y > 0) {
                                                if (mode === "PowerSaver")
                                                    Utils.execute("powerprofilesctl", ["set", "balanced"]);
                                                if (mode === "Balanced")
                                                    Utils.execute("powerprofilesctl", ["set", "performance"]);
                                            } else if (wheel.angleDelta.y < 0) {
                                                if (mode === "Balanced")
                                                    Utils.execute("powerprofilesctl", ["set", "power-saver"]);
                                                if (mode === "Performance")
                                                    Utils.execute("powerprofilesctl", ["set", "balanced"]);
                                            }
                                        }
                                    }

                                    RowLayout {
                                        id: powerModeRow
                                        spacing: 5
                                        IconImage {
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitSize: Theme.iconFontSize
                                            source: Quickshell.iconPath(getIcon())

                                            function getIcon() {
                                                const mode = PowerProfile.toString(PowerProfiles.profile);
                                                if (mode === "PowerSaver")
                                                    return "battery-profile-powersave";
                                                if (mode === "Balanced")
                                                    return "battery-profile-balanced";
                                                if (mode === "Performance")
                                                    return "battery-profile-performance";
                                            }
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: toCleanName()
                                            color: Theme.fgColor
                                            font.pointSize: Theme.labelFontSize
                                            font.family: Theme.labelFontFamily
                                            function toCleanName() {
                                                const mode = PowerProfile.toString(PowerProfiles.profile);
                                                if (mode === "PowerSaver")
                                                    return "Power Saver";
                                                else
                                                    return mode;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // Network
                        Rectangle {
                            id: networkContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignCenter
                            color: Theme.bgColor
                            border.color: Theme.mutedAccent
                            border.width: Theme.generalThickness
                            radius: Theme.cornerLargeRadius

                            readonly property double downSpeed: NetworkUsage.downloadSpeed
                            readonly property double upSpeed: NetworkUsage.uploadSpeed
                            property bool isBytes: true
                            MouseArea {
                                acceptedButtons: Qt.LeftButton
                                onClicked: parent.isBytes = !parent.isBytes
                            }
                            function getSpeed(bytes) {
                                if (networkContainer.isBytes) {
                                    if (bytes >= 1048576)
                                        return (bytes / 1048576).toFixed(1);
                                    if (bytes >= 1024)
                                        return (bytes / 1024).toFixed(1);
                                    return bytes.toFixed(1);
                                } else {
                                    if (bytes >= 1048576)
                                        return (bytes / 1048576 * 8).toFixed(1);
                                    if (bytes >= 1024)
                                        return (bytes / 1024 * 8).toFixed(1);
                                    return bytes.toFixed(1);
                                }
                            }
                            function getUnits(bytes) {
                                if (networkContainer.isBytes) {
                                    if (bytes >= 1048576)
                                        return "MB/s";
                                    if (bytes >= 1024)
                                        return "KB/s";
                                    return "B/s";
                                } else {
                                    if (bytes >= 1048576)
                                        return "Mbps";
                                    if (bytes >= 1024)
                                        return "Kbps";
                                    return "bps";
                                }
                            }

                            ColumnLayout {
                                spacing: 8
                                anchors.fill: parent
                                anchors.topMargin: Theme.cornerRadius
                                anchors.bottomMargin: Theme.cornerRadius
                                anchors.leftMargin: Theme.cornerRadius * 1.5
                                anchors.rightMargin: Theme.cornerRadius * 1.5
                                Row {
                                    spacing: 5
                                    Layout.alignment: Qt.AlignVCenter
                                    IconImage {
                                        implicitSize: Theme.iconFontSize
                                        source: Quickshell.iconPath("network-wireless")
                                    }
                                    Text {
                                        text: "NETWORK"
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 1.2
                                        font.family: Theme.labelFontFamily
                                    }
                                }
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    // Upload
                                    Column {
                                        Layout.alignment: Qt.AlignCenter
                                        Layout.fillWidth: true
                                        IconImage {
                                            implicitSize: Theme.iconFontSize
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            source: Quickshell.iconPath("arrow-up")
                                        }
                                        Text {
                                            text: networkContainer.getSpeed(networkContainer.upSpeed)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: Theme.fgColor
                                            font.pointSize: Theme.labelFontSize
                                            font.family: Theme.labelFontFamily
                                        }
                                        Text {
                                            text: networkContainer.getUnits(networkContainer.downSpeed)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            color: Theme.mutedFgColor
                                            font.pointSize: Theme.labelFontSize
                                            horizontalAlignment: Text.AlignHCenter
                                            font.family: Theme.labelFontFamily
                                        }
                                    }

                                    // Download
                                    Column {
                                        Layout.alignment: Qt.AlignCenter
                                        Layout.fillWidth: true
                                        IconImage {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            Layout.alignment: Qt.AlignCenter
                                            implicitSize: Theme.iconFontSize
                                            source: Quickshell.iconPath("arrow-down")
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: networkContainer.getSpeed(networkContainer.downSpeed)
                                            color: Theme.fgColor
                                            font.pointSize: Theme.labelFontSize
                                            font.family: Theme.labelFontFamily
                                        }
                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: networkContainer.getUnits(networkContainer.downSpeed)
                                            color: Theme.mutedFgColor
                                            font.pointSize: Theme.labelFontSize
                                            font.family: Theme.labelFontFamily
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // Footer / Username and Shutdown options
                    Rectangle {
                        Layout.preferredHeight: 60
                        Layout.preferredWidth: Theme.dashboardWidth
                        Layout.alignment: Qt.AlignCenter
                        color: Theme.bgColor
                        border.color: Theme.mutedAccent
                        border.width: Theme.generalThickness
                        radius: Theme.cornerLargeRadius
                        RowLayout {
                            anchors.fill: parent
                            anchors.topMargin: Theme.cornerRadius
                            anchors.bottomMargin: Theme.cornerRadius
                            anchors.leftMargin: Theme.cornerRadius * 1.5
                            anchors.rightMargin: Theme.cornerRadius * 1.5
                            spacing: 4

                            UserIcon {
                                Layout.alignment: Qt.AlignVCenter
                                size: 36
                                username: root.username
                            }
                            Item {
                                width: 4
                                height: 1
                            }
                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                text: root.username
                                color: Theme.fgColor
                                font.pointSize: Theme.labelFontSize * 1.1
                                font.family: Theme.labelFontFamily
                            }
                            // Logout
                            ClickButton {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillHeight: true
                                symbol: "system-log-out"
                                size: 36
                                cornerRadius: Theme.cornerRadius
                                onPress: {
                                    lockScreen.lock();
                                    root.togglePanel();
                                }
                            }
                            // Sleep
                            ClickButton {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillHeight: true
                                symbol: "emblem-remove"
                                size: 36
                                cornerRadius: Theme.cornerRadius
                                onPress: () => {
                                    lockScreen.lock();
                                    Power.execute("sleep");
                                    root.togglePanel();
                                }
                            }
                            // Reboot
                            ClickButton {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillHeight: true
                                symbol: "system-reboot"
                                size: 36
                                cornerRadius: Theme.cornerRadius
                                onPress: {
                                    Power.execute("reboot");
                                    root.togglePanel();
                                }
                            }
                            // Shutdown
                            ClickButton {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillHeight: true
                                symbol: "system-shutdown"
                                size: 36
                                cornerRadius: Theme.cornerRadius
                                onPress: {
                                    console.log("Executing poweroff");
                                    Power.execute("shutdown");
                                    root.togglePanel();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

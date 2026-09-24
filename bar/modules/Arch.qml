import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import QtQuick.Controls
import Quickshell.Io
import "root:/"
import "root:/components"
import "root:/services"
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Networking

Rectangle{
    // Properties
    id: root
    required property var panelHost
    required property var sysItems
    property string icon: "archlinux"
    property string label: "I use Arch btw"
    property bool lowPowerNotified: false
    property real batteryPercent: UPower.displayDevice ? UPower.displayDevice.percentage : 1
    onBatteryPercentChanged: {
        const percent = Math.round(batteryPercent * 100)
        if (UPower.onBattery && percent <= Theme.lowPowerThreshold) {
            if (!lowPowerNotified) {
                lowPower.startDetached()
                lowPowerNotified = true
            }
        } else {
            lowPowerNotified = false
        }
    }
    // Functions
    function togglePanel(){
        panelHost.hideAllPanelExcept("arch")
        dashboard.visible = !dashboard.visible;
        hoverDebounce.isDelaying = true;
        hoverDebounce.restart();
        if (dashboard.visible) panelHost.toggledPanels["arch"] = dashboard;
        else panelHost.toggledPanels["arch"] = false;
    }
    // Processes
    Process {
        id: runSettings
        command: ["hyprmod"]
    }
    Process {
        id: toggleMute
        command: ["sh","-c", "swayosd-client --output-volume mute-toggle"]
    }

    Process {
        id: mediaGoPrevious
        command: ["sh", "-c", "swayosd-client --playerctl previous"]
    }
    Process {
        id: mediaGoForward
        command: ["sh", "-c", "swayosd-client --playerctl next"]
    }
    Process {
        id: mediaPlayPause
        command: ["sh", "-c", "swayosd-client --playerctl play-pause"]
    }
    Process {
        id: setPowerSave
        command: ["sh", "-c", "powerprofilesctl set power-saver"]
    }
    Process {
        id: setPowerBalanced
        command: ["sh", "-c", "powerprofilesctl set balanced"]
    }
    Process {
        id: setPowerPerformance
        command: ["sh", "-c", "powerprofilesctl set performance"]
    }
    Process {
        id: netStats
        command: ["sh", "-c",
                  "cat /sys/class/net/wlan0/statistics/rx_bytes; " +
                  "cat /sys/class/net/wlan0/statistics/tx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: networkContainer.set(this.text.trim().split("\n"));
          }
    }
    Process {
        id: procLogout
        command: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"]
    }
    Process {
        id: procSleep
        command: ["sh", "-c", "systemctl suspend"]
    }

    Process {
        id: procReboot
        command: ["sh", "-c", "hyprshutdown -t 'Restarting...' --post-cmd 'reboot'"]
    }
    Process {
        id: procShutdown
        command: ["sh", "-c", "hyprshutdown -t 'Shutting down...' --post-cmd 'shutdown -P 0'"]
    }
    Process {
        id: execKitty
        command: ["kitty"]
    }
    Process {
        id: lowPower
        command: ["sh", "-c", "notify-send 'Low Power' 'Please charge your arch gng!' -i battery-caution"]
    }

    // Transitions
    width: container.width + 32
    Behavior on width {
        Anim { type: Anim.DefaultSpatial }
    }
    Behavior on color {
        CAnim {}
    }
    // Styling
    color: {
        if (mouseArea.containsMouse)
            return Theme.hoveredBgColor
        return Theme.bgColor
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
        onEntered: { hoverDebounce.isDelaying = true; hoverDebounce.restart(); root.label = "I use Arch btw"; }
        onClicked: root.togglePanel()
    }
    Timer {
        id: hoverDebounce
        property bool isDelaying: false
        interval: Theme.hoverDuration
        repeat: false
        running: !mouseArea.containsMouse && isDelaying

        onTriggered: { isDelaying = false; }
    }
    // Icon / Label Text
    Row {
        id: container
        anchors.centerIn: parent
        spacing: 5
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Theme.iconFontSize
            source: Quickshell.iconPath(icon)
        }
        Text {
            visible: hoverDebounce.isDelaying || mouseArea.containsMouse || UPower.onBattery
            anchors.verticalCenter: parent.verticalCenter
            text: UPower.onBattery ? "Discharging..." : root.label
            font.pointSize: Theme.labelFontSize 
            font.family: Theme.labelFontFamily 
            color: Theme.fgColor
            opacity: visible ? 1 : 0
            Behavior on opacity { Anim { type: Anim.DefaultEffects } }
        }
    }
    // Popup Part    
    PanelWindow {
        id: dashboard
        visible: false
        focusable: true
        color: "transparent"
        implicitWidth: Theme.dashboardWidth + Theme.barHorizontalPad
        implicitHeight: mainColumn.height
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        //exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: false
            left: true
            right: false
        }
        // The mouse out of bound
        // Rectangle {
        //     color: "Transparent"
        //     anchors.fill: parent
        //     TapHandler {
        //         onTapped: dashboard.visible = false
        //     }
        // }
        // The Esc => close
        FocusScope {
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    dashboard.visible = false
                    event.accepted = true
                }
            }
        }
        // Actual Dashboard
        Item {
            z: 1
            height: Theme.dashboardHeight
            width: Theme.dashboardWidth
            x: Theme.barHorizontalPad
            //y: bar.height + Theme.dropdownOffset

            ColumnLayout{
                id: mainColumn
                visible: dashboard.visible
                spacing: visible ? 5 : 30
                Behavior on spacing {
                    Anim { type: Anim.DefaultSpatial }
                }

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
                        ClickButton{
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            symbol: "systemsettings-alt"
                            size: 36
                            onPress: () => {
                                console.log("Executing Settings")
                                runSettings.startDetached();
                                root.togglePanel();
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
                            onPress: INetwork.setWifi(this.isChecked);
                        }
                        ToggleButton {
                            symbol: BluetoothResolve.icon
                            isChecked: BluetoothResolve.bluetoothEnabled
                            label: BluetoothResolve.status
                            onPress: BluetoothResolve.setBluetooth(this.isChecked)
                        }

                        ToggleButton {
                            symbol: "airplane-mode"
                            isChecked: false
                            label: "Airplane Mode"
                        }

                        ToggleButton {
                            symbol: Swaync.icon
                            isChecked: !Swaync.isDndOn
                            label: Swaync.message
                            onPress: Swaync.toggleDnd()
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
                                    setPowerBalanced.startDetached()
                                }
                                else setPowerSave.startDetached();
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
                                    console.log("Executing Mute-Unmute")
                                    toggleMute.startDetached();

                                }
                            }
                            Slider {
                                focusPolicy: Qt.NoFocus
                                id: volumeSlider
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                from: 0
                                to: 1 // its from 0 -> 1
                                value: visible ? Pipewire.defaultAudioSink.audio.volume : 0
                                Behavior on value {
                                    Anim { type: Anim.FastSpatial }
                                }

                                background: Rectangle {
                                    x: volumeSlider.leftPadding
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
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
                                        Anim { type: Anim.DefaultSpatial }
                                    }
                                    color: Theme.accent
                                }
                                onMoved : {
                                    Pipewire.defaultAudioSink.audio.volume = volumeSlider.value
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
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            label: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.description : "Unknown" // <- The proper name
                            onPress: {
                                dashboard.visible = false
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
                    onPlayerChanged: { if (mediaContainer.player) mediaContainer.player.positionChanged(); }
                    onVisibleChanged: { if (mediaContainer.player) mediaContainer.player.positionChanged(); }
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
                    visible: player
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
                            ClippingRectangle {
                                
                                height: Theme.thumbnailSize
                                width: Theme.thumbnailSize
                                radius: Theme.cornerRadius
                                Image {
                                    width: parent.width
                                    height: parent.height
                                    anchors.centerIn: parent
                                    source: mediaContainer.player ? mediaContainer.player.trackArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }
                            
                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    text: mediaContainer.player ? mediaContainer.player.trackTitle : "Unknown"
                                    color: Theme.fgColor
                                    font.pointSize: Theme.labelFontSize 
                                    font.family: Theme.labelFontFamily
                                }
                                Text {
                                    text: mediaContainer.player ? mediaContainer.player.trackArtist : "Unknown"
                                    color: Theme.mutedFgColor
                                    font.pointSize: Theme.labelFontSize
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
                                        console.log("Executing Previous Media")
                                        mediaGoPrevious.startDetached();
                                    }
                                }
                                ToggleButton {
                                    size: 36
                                    symbol: isChecked ? "media-playback-pause" : "media-playback-start"
                                    isChecked: mediaContainer.player ? mediaContainer.player.isPlaying : false
                                    label: ""
                                    onPress: () => {
                                        console.log("Executing Play-Pause, Current Status: " + mediaContainer.player.isPlaying)
                                        mediaPlayPause.startDetached();
                                    }
                                }
                                ClickButton {
                                    symbol: "media-seek-forward"
                                    size: 36
                                    onPress: () => {
                                        console.log("Executing Next Media")
                                        mediaGoForward.startDetached();
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
                                
                                value: playerSlider.pressed ? playerSlider.value : (mediaContainer.player ? mediaContainer.player.position : 0)
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
                                    seekDebounce.restart()
                                    playerSlider.releaseValue = playerSlider.value;
                                }
                                Timer {
                                    id: seekDebounce
                                    interval: 100
                                    repeat: false
                                    
                                    onTriggered: {
                                        console.log("Changed to: " + playerSlider.releaseValue)
                                        mediaContainer.player.position = playerSlider.releaseValue
                                    }
                                }
                            }
                            // Bottom Timer
                            Item {
                                id: textPositionContainer
                                function formatTime(seconds) {
                                    let mins = Math.floor(seconds / 60);
                                    let secs = Math.floor(seconds % 60);

                                    return mins.toString().padStart(1, "0") + ":" +
                                        secs.toString().padStart(2, "0");
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
                                        const percentage = Math.round(UPower.displayDevice.percentage * 100);
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
                                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"
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
                                value: UPower.displayDevice.percentage

                                background: Item { }
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
                                    onWheel: (wheel) => {
                                        const mode = PowerProfile.toString(PowerProfiles.profile);
                                        if (wheel.angleDelta.y > 0) {
                                            if (mode === "PowerSaver") setPowerBalanced.startDetached();
                                            if (mode === "Balanced") setPowerPerformance.startDetached();
                                        }
                                        else if (wheel.angleDelta.y < 0){
                                            if (mode === "Balanced") setPowerSave.startDetached();
                                            if (mode === "Performance") setPowerBalanced.startDetached();

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
                                            if (mode === "PowerSaver") return "battery-profile-powersave";
                                            if (mode === "Balanced") return "battery-profile-balanced";
                                            if (mode === "Performance") return "battery-profile-performance"
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
                                            if (mode === "PowerSaver") return "Power Saver";
                                            else return mode;
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
                        property double downSpeed: 0
                        property double upSpeed: 0
                        property int lastRx: 0
                        property int lastTx: 0
                        Timer {
                            interval: Theme.networkUpdateInterval
                            running: parent.visible
                            repeat: true
                            triggeredOnStart: true

                            onTriggered: netStats.running = true
                        }
                        function set(lines) {
                            const rx = Number(lines[0]);
                            const tx = Number(lines[1]);

                            if (networkContainer.lastRx !== 0) {
                                networkContainer.downSpeed = (rx - networkContainer.lastRx) / 1024; // KB/s
                                networkContainer.upSpeed = (tx - networkContainer.lastTx) / 1024;
                            }

                            networkContainer.lastRx = rx;
                            networkContainer.lastTx = tx;
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
                                        text: networkContainer.upSpeed.toFixed(1)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: Theme.fgColor
                                        font.pointSize: Theme.labelFontSize
                                        font.family: Theme.labelFontFamily
                                    }
                                    Text {
                                        text: "KB/s"
                                        color: Theme.mutedFgColor
                                        anchors.horizontalCenter: parent.horizontalCenter
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
                                        text: networkContainer.downSpeed > 1024 ? (networkContainer.downSpeed / 1024).toFixed(1) : networkContainer.downSpeed.toFixed(1)
                                        color: Theme.fgColor
                                        font.pointSize: Theme.labelFontSize
                                        font.family: Theme.labelFontFamily
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: networkContainer.downSpeed > 1024 ? "MB/s" : "KB/s"
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

                        ClickButton {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillHeight: true
                            symbol: "config-users"
                            size: 36
                            cornerRadius: Theme.cornerRadius
                            onPress: () => {
                                execKitty.startDetached();
                                root.togglePanel();
                            }
                        }
                        Item { width: 4; height: 1}
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            text: "ii1qe"
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
                                console.log("Executing hyprland logout")
                                procLogout.startDetached();
                                root.togglePanel();
                                Qt.quit()
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
                                console.log("Executing System Suspend")
                                procSleep.startDetached();
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
                                console.log("Executing Reboot")
                                procReboot.startDetached();
                                root.togglePanel();
                                Qt.quit()
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
                                console.log("Executing poweroff")
                                procShutdown.startDetached();
                                root.togglePanel();
                                Qt.quit()
                            }
                        }
                    }
                }
            }
        }
    }
}

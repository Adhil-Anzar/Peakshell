import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "root:/"
import "root:/components"
import "root:/services"

// Now playing dropdown panel: album art, transport controls and a seek slider.
PanelWindow {
    id: mediaPanel
    property real barOffset: 0
    property var panelHost

    readonly property var player: MprisController.activePlayer
    readonly property real artSize: Theme.mediaPanelWidth - Theme.cornerLargeRadius * 2

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0;
        let mins = Math.floor(seconds / 60);
        let secs = Math.floor(seconds % 60);
        return mins.toString().padStart(1, "0") + ":" + secs.toString().padStart(2, "0");
    }

    visible: false
    focusable: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Dismiss on clicking outside
    MouseArea {
        anchors.fill: parent
        onClicked: mediaPanel.visible = false
    }

    // Esc closes the panel
    FocusScope {
        anchors.fill: parent
        focus: mediaPanel.visible
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                mediaPanel.visible = false;
                event.accepted = true;
            }
        }
    }

    // Poll the player position while it is playing
    Timer {
        running: mediaPanel.visible && mediaPanel.player && mediaPanel.player.playbackState === MprisPlaybackState.Playing
        interval: Theme.mediaPlayerUpdateDuration
        repeat: true

        onTriggered: {
            if (mediaPanel.player)
                mediaPanel.player.positionChanged();
        }
    }
    Connections {
        target: mediaPanel.player

        function onPostTrackChanged() {
            if (mediaPanel.player)
                mediaPanel.player.positionChanged();
        }
    }
    onPlayerChanged: {
        if (player)
            player.positionChanged();
    }
    onVisibleChanged: {
        if (visible && player)
            player.positionChanged();
    }

    Item {
        x: mediaPanel.barOffset + Theme.barHorizontalPad
        y: 0
        width: Theme.mediaPanelWidth
        height: mediaColumn.height
        visible: mediaPanel.visible

        opacity: mediaPanel.visible ? 1 : 0
        scale: mediaPanel.visible ? 1 : 0.94
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
            id: mediaColumn
            width: Theme.mediaPanelWidth
            spacing: 5

            Rectangle {
                id: mediaCard
                Layout.preferredWidth: Theme.mediaPanelWidth
                Layout.preferredHeight: mediaCardContent.implicitHeight + Theme.cornerLargeRadius * 2
                color: Theme.bgColor
                border.color: Theme.mutedAccent
                border.width: Theme.generalThickness
                radius: Theme.cornerLargeRadius

                ColumnLayout {
                    id: mediaCardContent
                    x: Theme.cornerLargeRadius
                    y: Theme.cornerLargeRadius
                    width: mediaCard.width - Theme.cornerLargeRadius * 2
                    spacing: 10

                    // Title
                    Row {
                        spacing: 8
                        IconImage {
                            implicitSize: Theme.iconFontSize
                            source: Quickshell.iconPath("com.github.neithern.g4music", "multimedia-player")
                        }
                        Text {
                            text: "NOW PLAYING"
                            color: Theme.mutedFgColor
                            font.pointSize: Theme.labelFontSize * 1.2
                            font.family: Theme.labelFontFamily
                        }
                    }

                    // Currently playing album art
                    MediaArt {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: mediaPanel.artSize
                        Layout.preferredHeight: mediaPanel.artSize
                        radius: Theme.cornerLargeRadius
                        source: mediaPanel.player ? mediaPanel.player.trackArtUrl : ""
                        active: mediaPanel.visible
                    }

                    // Track info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: mediaPanel.player ? mediaPanel.player.trackTitle : "Nothing playing"
                            color: Theme.fgColor
                            font.pointSize: Theme.labelFontSize * 1.3
                            font.family: Theme.labelFontFamily
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Text {
                            Layout.fillWidth: true
                            text: mediaPanel.player ? mediaPanel.player.trackArtist : ""
                            color: Theme.mutedFgColor
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Transport controls
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 14

                        ClickButton {
                            symbol: "media-seek-backward"
                            size: 40
                            onPress: MprisController.previous()
                        }
                        ClickButton {
                            symbol: mediaPanel.player && mediaPanel.player.isPlaying ? "media-playback-pause" : "media-playback-start"
                            size: 44
                            bgColor: mediaPanel.player && mediaPanel.player.isPlaying ? Theme.accent : Theme.mutedBgColor
                            onPress: MprisController.togglePlaying()
                        }
                        ClickButton {
                            symbol: "media-seek-forward"
                            size: 40
                            onPress: MprisController.next()
                        }
                    }

                    // Seek slider and timings
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Slider {
                            id: playerSlider
                            focusPolicy: Qt.NoFocus
                            property real releaseValue: 0

                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            from: 0
                            to: mediaPanel.player && mediaPanel.player.length > 0 ? mediaPanel.player.length : 1

                            value: {
                                if (playerSlider.pressed)
                                    return playerSlider.value;
                                if (!mediaPanel.player)
                                    return 0;
                                return Math.max(0, Math.min(mediaPanel.player.position, playerSlider.to));
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
                                color: Theme.mutedBgColor

                                // Active track color
                                Rectangle {
                                    width: playerSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: Theme.accent
                                    radius: 3
                                }
                            }
                            handle: Rectangle {
                                x: playerSlider.leftPadding + playerSlider.visualPosition * (playerSlider.availableWidth - width)
                                y: playerSlider.topPadding + playerSlider.availableHeight / 2 - height / 2
                                implicitWidth: 12
                                implicitHeight: 12
                                radius: 12
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
                                    if (mediaPanel.player)
                                        mediaPanel.player.position = playerSlider.releaseValue;
                                }
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                            Text {
                                anchors.left: parent.left
                                text: mediaPanel.formatTime(mediaPanel.player ? mediaPanel.player.position : 0)
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.9
                                font.family: Theme.labelFontFamily
                            }
                            Text {
                                anchors.right: parent.right
                                text: mediaPanel.formatTime(mediaPanel.player ? mediaPanel.player.length : 0)
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.9
                                font.family: Theme.labelFontFamily
                            }
                        }
                    }
                }
            }
        }
    }
}

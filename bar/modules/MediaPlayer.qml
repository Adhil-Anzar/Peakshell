import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"
import "root:/bar/panels"

// Bar module that opens the now-playing panel.
Rectangle {
    id: root
    required property var panelHost

    readonly property var player: MprisController.activePlayer
    readonly property string trackTitle: player && player.trackTitle ? player.trackTitle : ""
    readonly property string trackArtist: player && player.trackArtist ? player.trackArtist : ""

    function getSpacingDistance() {
        return panelHost ? container.mapToItem(panelHost.contentItem, 0, 0).x : container.mapToGlobal(0, 0).x;
    }

    // Expand the module so the (new) track name is visible.
    function revealTitle() {
        hoverDebounce.isDelaying = true;
        hoverDebounce.restart();
    }

    function togglePanel() {
        mediaLoader.active = true;
        const panel = mediaLoader.item;
        panel.barOffset = getSpacingDistance();
        panelHost.hideAllPanelExcept("media");
        panel.visible = !panel.visible;
        revealTitle();
        if (panel.visible)
            panelHost.toggledPanels["media"] = panel;
        else
            panelHost.toggledPanels["media"] = false;
    }

    width: container.width + 32
    Behavior on width {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    Behavior on color {
        CAnim {}
    }
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : Theme.bgColor
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onEntered: {
            hoverDebounce.isDelaying = true;
            hoverDebounce.restart();
        }
        onClicked: root.togglePanel()
    }

    // Whenever the track changes, briefly show the song name
    // as if the module were hovered.
    Connections {
        target: MprisController

        function onTrackChanged() {
            root.revealTitle();
        }
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

    Row {
        id: container
        anchors.centerIn: parent
        spacing: 5
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Theme.iconFontSize
            source: Quickshell.iconPath("multimedia-player", "audio-x-generic")
        }
        Text {
            visible: hoverDebounce.isDelaying || mouseArea.containsMouse
            anchors.verticalCenter: parent.verticalCenter
            text: root.trackTitle !== "" ? root.trackTitle : "Nothing playing"
            width: Math.min(implicitWidth, 220)
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

    // Popup part (lazy: instantiated in background, positioned on open)
    LazyLoader {
        id: mediaLoader
        loading: true
        MediaPanel {
            panelHost: root.panelHost
        }
    }
}

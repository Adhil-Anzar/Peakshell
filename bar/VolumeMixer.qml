import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Io
import "root:/"

Rectangle {
    id: root
    Process {
        id: appName
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.sourceProcessName = this.text.trim()
                root.symbol = this.text.trim().toLowerCase()
            }
        }
    }
    property bool isSourceApplication: true;
    property string symbol: {
        if (!isSourceApplication) return PipewireResolve.getIconByNode(node)
        if (!node) return "audio-volume-high";
        var icon = node.properties["pipewire.access.portal.app_id"];
        if (icon) return icon

        icon = node.properties["application.icon-name"];
        if (icon) return icon

        const id = node.properties["client.id"];
        if (!id) return "audio-volume-high"
        //console.log("Fetching for " + id);
        appName.command = ["sh", "-c", `pw-cli info ${id} | awk -F'"' '/application.name/ {print $2}'`]
        appName.running = true;
        return "audio-volume-high"
    }
    property string sourceProcessName;
    property string label: {
        // application.name -> description -> name
        if (sourceProcessName) {  // Manual Icon is enabled
            const media = node.properties["media.name"];
            const lbl = media !== undefined ? `${sourceProcessName} - ${media}` : sourceProcessName;
            return lbl;
        }
        else {
            if (!node) return "Unknown"
            const app = node.properties["application.process.binary"] ?? (node.properties["application.name"] ?? (node.description !== "" ? node.description : node.name));
            const media = node.properties["media.name"];
            const lbl = media !== undefined ? `${app} - ${media}` : app;
            return lbl;
        }
    }
    property real iconSize: 36;

    required property PwNode node;

    // bind the node so we can read its properties
    PwObjectTracker { objects: [ node ] }
    PwNodePeakMonitor { id: peakMonitor; node: node; enabled: true;  }

    signal pressMute();
    color: Theme.bgColor
    border.color: Theme.mutedAccent
    border.width: Theme.generalThickness
    radius: Theme.cornerLargeRadius
    Rectangle {
        color: "#77FF0000"
        opacity: peakMonitor.peak;

        radius: Theme.cornerLargeRadius
        anchors.fill: parent
        Behavior on opacity {
            NumberAnimation { duration: Theme.animationDuration }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.cornerRadius
        anchors.bottomMargin: Theme.cornerRadius
        anchors.leftMargin: Theme.cornerLargeRadius
        anchors.rightMargin: Theme.cornerLargeRadius
        spacing: 4
        Row {
            spacing: 8
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: Theme.iconFontSize
                source: Quickshell.iconPath(symbol,"applications-other")
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.label
                width: Theme.soundPanelWidth - (Theme.cornerLargeRadius * 4)
                color: Theme.mutedFgColor
                font.pointSize: Theme.labelFontSize
                font.family: Theme.labelFontFamily
                font.capitalization: Font.Capitalize
                elide: Text.ElideRight
            }
        }
        RowLayout {
            spacing: 8
            ClickButton {
                symbol: PipewireResolve.getIconByNode(root.node)
                size: root.iconSize
                bgColor: "transparent"
                onPress: () => {
                    console.log("Executing Mute-Unmute for item " + root.label)
                    node.audio.muted = !node.audio.muted

                }
            }
            Slider {
                id: volumeSlider
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                focus: false
                from: 0
                to: 1 // its from 0 -> 1
                value: visible && node ? node.audio.volume : 0
                Behavior on value {
                    NumberAnimation {
                        duration: Theme.animationDuration
                        easing.type: Easing.OutExpo
                    }
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
                        NumberAnimation {
                            duration: Theme.animationDuration
                            easing.type: Easing.OutExpo
                        }
                    }
                    color: Theme.accent
                }
                onMoved : {
                    node.audio.volume = volumeSlider.value
                }
            }
            Text {
                text: Math.round(volumeSlider.value * 100) + "%"
                color: Theme.mutedFgColor
                font.pointSize: Theme.labelFontSize
                font.family: Theme.labelFontFamily

            }
        }
    }

}

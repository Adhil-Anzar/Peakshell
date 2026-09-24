import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick.Effects
import "root:/"
import "root:/services"


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
    property var popup: mainPopup;
    // bind the node so we can read its properties
    PwObjectTracker { objects: [ node ] }
    PwNodePeakMonitor {
        id: peakMonitor;
        node: root.node;
        // if the thing aint sink its gonna die
        enabled: root.node ? root.node.audio && root.node.isSink && root.visible : false
    }

    signal pressMute();
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
        spacing: 4
        RowLayout {
            spacing: 8
            IconImage {
                Layout.alignment: Qt.AlignVCenter
                implicitSize: Theme.iconFontSize
                source: Quickshell.iconPath(symbol,"applications-other")

            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.label
                width: Theme.soundPanelWidth - (Theme.cornerLargeRadius * 4)
                color: Theme.mutedFgColor
                font.pointSize: Theme.labelFontSize
                font.family: Theme.labelFontFamily
                visible: isSourceApplication
                font.capitalization: Font.Capitalize
                elide: Text.ElideRight
            }
            ComboBox {
                id: comboBox
                Layout.fillWidth: true
                implicitWidth: currentTextObject.implicitWidth + Theme.cornerLargeRadius
                focusPolicy: Qt.NoFocus
                currentIndex: node ? (node.isSink ? PipewireResolve.currentIndexOutputDevice : PipewireResolve.currentIndexInputDevice) : 0
                Layout.alignment: Qt.AlignVCenter
                textRole: "description"
                visible: !isSourceApplication
                model: {
                    if (isSourceApplication) return [];
                    if (!node) return [];
                    if (node.isSink)
                        return PipewireResolve.outputDevices
                    return PipewireResolve.inputDevices
                }
                onActivated: {
                    if (node.isSink)
                        Pipewire.preferredDefaultAudioSink = PipewireResolve.outputDevices[comboBox.currentIndex]
                    else
                        Pipewire.preferredDefaultAudioSource = PipewireResolve.inputDevices[comboBox.currentIndex]
                }
                contentItem: Text {
                    id: currentTextObject
                    anchors.centerIn: parent
                    text: parent.currentText
                    color: Theme.mutedFgColor
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                    elide: Text.ElideRight
                }

                indicator: IconImage {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        rightMargin: Theme.cornerRadius / 2
                    }

                    implicitSize: Theme.labelFontSize
                    source: Quickshell.iconPath("arrow-down")
                }

                background: Rectangle {
                    id: comboBoxRect
                    radius: Theme.cornerRadius
                    Behavior on color {
                        ColorAnimation {
                        duration: Theme.animationDuration
                        }
                    }
                    color: comboBoxMouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
                    MouseArea {
                        enabled: parent.enabled
                        id: comboBoxMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: parent.width
                    hoverEnabled: true
                    highlighted: parent.currentIndex === index
                    contentItem: Text {
                        anchors.fill: parent
                        id: comboBoxDescription
                        text: modelData.description
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        anchors.fill: parent
                        color: Qt.darker(Theme.bgColor, 3);
                        border.color: Theme.mutedAccent
                        border.width: Theme.generalThickness
                        radius: Theme.cornerRadius
                    }
                }
                popup: Popup {
                    id: mainPopup
                    y: parent.height
                    x: ( this.width - root.width ) / 2
                    width: Theme.soundPanelWidth - ( Theme.cornerLargeRadius * 2 )
                    height: root.height - parent.y
                    topMargin: 6
                    bottomMargin: 6
                    contentItem: ListView {
                        spacing: 2
                        clip: true
                        implicitHeight: contentHeight
                        model: comboBox.delegateModel
                        currentIndex: comboBox.highlightedIndex
                        highlightMoveDuration: 0
                    }
                    background: Item { }
                }
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
                focusPolicy: Qt.NoFocus
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
                    RectangularShadow {
                        z: parent.z - 1
                        anchors.fill: parent
                        color: Qt.darker(Theme.accent, 2.5)
                        radius: spread / 2
                        spread: 15 * peakMonitor.peak
                        // IF scale down anim is required uncomment
                        // Behavior on spread {
                        //     NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo }
                        // }
                        blur: peakMonitor.peak === 0 ? 0 : 30
                        Behavior on blur {
                            NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo }
                        }
                    }

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

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: soundPanel
    property real barOffset: 0
    property var panelHost

    visible: false
    focusable: true
    color: "transparent"
    implicitWidth: visible ? Theme.soundPanelWidth + Theme.barHorizontalPad + barOffset : 0
    implicitHeight: soundColumnContainer.height
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors {
        top: true
        bottom: false
        left: true
        right: false
    }

    FocusScope {
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                soundPanel.visible = false;
                event.accepted = true;
            }
        }
    }

    Item {
        x: visible ? (soundPanel.barOffset + Theme.barHorizontalPad) : 0
        visible: soundPanel.visible

        ColumnLayout {
            id: soundColumnContainer
            width: Theme.soundPanelWidth
            visible: soundPanel.visible
            spacing: visible ? 5 : 30
            Behavior on spacing {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.OutExpo
                }
            }
            Rectangle {
                Layout.preferredHeight: deviceMode.height + Theme.generalThickness
                Layout.preferredWidth: deviceMode.width + Theme.generalThickness
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                color: Theme.bgColor
                border.color: Theme.mutedAccent
                border.width: Theme.generalThickness
                radius: Theme.cornerRadius

                Rectangle {
                    id: deviceMode
                    property string mode: "output"
                    color: soundModeMouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
                    height: soundModeRow.height + Theme.cornerRadius
                    width: soundModeRow.width + Theme.cornerLargeRadius
                    radius: Theme.cornerRadius
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.animationDuration
                            easing.type: Easing.OutExpo
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animationDuration
                        }
                    }
                    MouseArea {
                        id: soundModeMouseArea
                        hoverEnabled: true
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onWheel: wheel => {
                            if (wheel.angleDelta.y > 0)
                                deviceMode.mode = "output";
                            else if (wheel.angleDelta.y < 0)
                                deviceMode.mode = "input";
                        }
                        onPressed: {
                            deviceMode.mode = deviceMode.mode === "output" ? "input" : "output";
                        }
                    }

                    RowLayout {
                        id: soundModeRow
                        anchors.centerIn: parent
                        spacing: 5
                        IconImage {
                            Layout.alignment: Qt.AlignVCenter
                            implicitSize: Theme.iconFontSize
                            source: Quickshell.iconPath(deviceMode.mode === "output" ? PipewireResolve.outputIcon : PipewireResolve.inputIcon)
                        }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: deviceMode.mode === "output" ? "Output Devices" : "Input Devices"
                            color: Theme.fgColor
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                        }
                    }
                }
            }
            VolumeMixer {
                node: deviceMode.mode === "output" ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
                width: parent.width
                height: Theme.soundItemSize
                isSourceApplication: false
            }
            Repeater {
                Layout.fillHeight: true
                Layout.fillWidth: true
                model: {
                    const nodes = [];
                    for (let i = 0; i < Pipewire.nodes.values.length; ++i) {
                        const node = Pipewire.nodes.values[i];
                        if (deviceMode.mode === "output" ? node.isStream && node.isSink : node.isStream && !node.isSink)
                            nodes.push(node);
                    }
                    return nodes;
                }

                VolumeMixer {
                    required property var modelData
                    node: modelData
                    width: parent.width
                    height: Theme.soundItemSize
                    isSourceApplication: true
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: brightnessPanel
    property real barOffset: 0
    property var panelHost

    visible: false
    focusable: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    onVisibleChanged: {
        if (visible)
            Brightness.refresh();
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Dismiss on clicking outside
    MouseArea {
        anchors.fill: parent
        onClicked: brightnessPanel.visible = false
    }

    FocusScope {
        anchors.fill: parent
        focus: brightnessPanel.visible
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                brightnessPanel.visible = false;
                event.accepted = true;
            }
        }
    }

    Item {
        x: brightnessPanel.barOffset + Theme.barHorizontalPad
        y: 0
        width: Theme.brightnessPanelWidth
        height: brightnessColumn.height
        visible: brightnessPanel.visible

        opacity: brightnessPanel.visible ? 1 : 0
        scale: brightnessPanel.visible ? 1 : 0.94
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
            id: brightnessColumn
            width: Theme.brightnessPanelWidth
            spacing: 5

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: headerRow.implicitHeight + Theme.cornerRadius
                color: Theme.bgColor
                border.color: Theme.mutedAccent
                border.width: Theme.generalThickness
                radius: Theme.cornerRadius

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.leftMargin: Theme.cornerLargeRadius
                    anchors.rightMargin: Theme.cornerLargeRadius
                    spacing: 8

                    IconImage {
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: Theme.iconFontSize
                        source: Quickshell.iconPath("display-brightness-symbolic", "display-brightness")
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            brightness: 1.0
                            colorizationColor: Theme.mutedFgColor
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: "BRIGHTNESS"
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize * 1.2
                        font.family: Theme.labelFontFamily
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: Brightness.supportedMonitors.length + (Brightness.supportedMonitors.length === 1 ? " monitor" : " monitors")
                        color: Theme.mutedFgColor
                        font.pointSize: Theme.labelFontSize * 0.9
                        font.family: Theme.labelFontFamily
                    }
                }
            }

            Repeater {
                model: Brightness.supportedMonitors

                delegate: Rectangle {
                    id: monitorCard
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.brightnessItemSize
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    radius: Theme.cornerRadius

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.cornerRadius
                        anchors.rightMargin: Theme.cornerLargeRadius
                        spacing: 10

                        IconImage {
                            Layout.alignment: Qt.AlignVCenter
                            implicitSize: Theme.iconFontSize
                            source: Quickshell.iconPath(Brightness.iconForLevel(monitorCard.modelData.brightness), "display-brightness")
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                brightness: 1.0
                                colorizationColor: Brightness.levelColor(monitorCard.modelData.brightness)
                                Behavior on colorizationColor {
                                    CAnim {}
                                }
                            }
                        }

                        Column {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: Math.max(96, Theme.brightnessPanelWidth * 0.28)
                            spacing: 2

                            Text {
                                width: parent.width
                                text: monitorCard.modelData.displayName
                                color: Theme.fgColor
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: monitorCard.modelData.detail
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                                elide: Text.ElideRight
                            }
                        }

                        BrightnessSlider {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            value: monitorCard.modelData.brightness
                            onMoved: monitorCard.modelData.setBrightness(value)
                        }

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 36
                            horizontalAlignment: Text.AlignRight
                            text: monitorCard.modelData.ready ? Math.round(monitorCard.modelData.brightness * 100) + "%" : "--"
                            color: Theme.mutedFgColor
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                visible: Brightness.supportedMonitors.length === 0
                color: Theme.bgColor
                border.color: Theme.mutedAccent
                border.width: Theme.generalThickness
                radius: Theme.cornerRadius

                Text {
                    anchors.centerIn: parent
                    text: "No brightness-capable monitors detected"
                    color: Theme.mutedFgColor
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

// The visible half of services/Osd.qml. One window is created per monitor by
// shell.qml, matching SwayOSD's "show on every output unless --monitor is
// given" behaviour.
PanelWindow {
    id: root
    required property ShellScreen screen

    readonly property color fg: Theme.fgColor
    readonly property color bg: Theme.bgColorFilled
    readonly property color accent: Theme.accent
    readonly property color trackColor: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)

    visible: Osd.visible && (Osd.monitor === "" || Osd.monitor === screen.name)
    focusable: false
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: Math.round(screen.height * Theme.osdBottomMargin / 100)
    implicitHeight: pill.height

    // Only the pill itself accepts pointer input. Everything else passes
    // through to the windows below, just like SwayOSD's empty input region.
    mask: Region {
        item: pill
    }

    Rectangle {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.max(10, root.visible ? content.implicitWidth + 28 : 0)
        height: content.implicitHeight + 20
        radius: 18
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.80)
        border.width: 1
        clip: true
        border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)
        Behavior on width {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
        RowLayout {
            id: content
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 10

            IconImage {
                Layout.alignment: Qt.AlignVCenter
                visible: Osd.icon !== ""
                implicitSize: 24
                source: Osd.icon !== "" ? Quickshell.iconPath(Osd.icon, "missing-symbolic") : ""
                opacity: Osd.iconOpacity
                layer.enabled: true
                layer.effect: MultiEffect {
                    colorization: 1.0
                    brightness: 1.0
                    colorizationColor: Osd.iconColor.a > 0 ? Osd.iconColor : root.fg
                }
            }

            Item {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 160
                Layout.preferredHeight: 6
                visible: Osd.hasProgress

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: root.trackColor
                }

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Osd.progress))
                    height: parent.height
                    radius: height / 2
                    color: root.accent
                    opacity: Osd.progressOpacity

                    Behavior on width {
                        NumberAnimation {
                            duration: 80
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Row {
                id: segments
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 160
                Layout.preferredHeight: 6
                visible: Osd.hasSegments
                spacing: 8

                Repeater {
                    model: Osd.segmentCount

                    Rectangle {
                        required property int index
                        width: {
                            const count = Math.max(1, Osd.segmentCount);
                            return Math.max(0, (segments.width - segments.spacing * (count - 1)) / count);
                        }
                        height: segments.height
                        radius: height / 2
                        color: index < Osd.segmentValue ? root.accent : root.trackColor
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: !Osd.hasProgress && !Osd.hasSegments
                Layout.maximumWidth: 350
                visible: Osd.text !== ""
                text: Osd.text
                horizontalAlignment: Osd.icon === "" && !Osd.hasProgress && !Osd.hasSegments ? Text.AlignHCenter : Text.AlignLeft
                color: root.fg
                font.pointSize: Theme.labelFontSize
                font.family: Theme.labelFontFamily
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }
}

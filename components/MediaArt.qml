import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/"

// Rounded album art thumbnail.
// While the artwork is still loading it shows an animated shimmer sweep
// instead of a blank square. Animations only run while `active` is set,
// so a thumbnail that lives inside a closed panel stays idle.
ClippingRectangle {
    id: root

    property url source: ""
    property bool active: true

    readonly property bool loading: image.status === Image.Loading

    implicitWidth: 64
    implicitHeight: 64
    radius: Theme.cornerRadius
    color: Theme.mutedBgColor

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    // Placeholder layering shown until the artwork is ready.
    Item {
        anchors.fill: parent
        visible: image.status !== Image.Ready

        IconImage {
            anchors.centerIn: parent
            implicitSize: Math.round(Math.min(root.width, root.height) * 0.4)
            source: Quickshell.iconPath("media-playback-start")
            opacity: root.loading ? 0 : 0.55
            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Sweeping highlight that makes a loading thumbnail read as animated.
        Rectangle {
            id: shimmer
            width: Math.max(root.width * 0.6, 24)
            height: root.height
            visible: root.loading
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Qt.rgba(1, 1, 1, 0.15)
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
            NumberAnimation on x {
                running: root.active && root.loading
                from: -shimmer.width
                to: root.width
                duration: 1100
                easing.type: Easing.InOutSine
                loops: Animation.Infinite
            }
        }
    }
}

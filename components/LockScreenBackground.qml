import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import "root:/"
import "root:/services"

// Fullscreen wallpaper backdrop for the session lock surface.
//
// Mirrors the SDDM theme's background behaviour: the wallpaper is rendered
// into a layer and a MultiEffect animates blur/brightness/saturation while
// the lock surface changes between the clock and login states.
Item {
    id: root

    property real blurMax: 0
    property real brightness: 0
    property real saturation: 0
    property real overlayOpacity: 0.25

    readonly property var wallpaper: WallpaperService.currentWallpaper
    readonly property string wallpaperType: wallpaper && wallpaper.type ? wallpaper.type : ""
    readonly property string wallpaperPath: wallpaper && wallpaper.path ? wallpaper.path.toString() : ""

    Behavior on blurMax {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on brightness {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on saturation {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }
    Behavior on overlayOpacity {
        NumberAnimation {
            duration: 400
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: visual

        anchors.fill: parent
        // VideoOutput is kept out of the effect layer. Images (the common
        // case) get the animated blur/brightness/saturation treatment.
        layer.enabled: root.wallpaperType === "image"
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: root.blurMax > 0
            blur: 1.0
            blurMax: root.blurMax
            brightness: root.brightness
            saturation: root.saturation
        }

        // Neutral base so the lock surface is never transparent.
        Rectangle {
            anchors.fill: parent
            color: Theme.bgColor
        }

        Image {
            id: wallpaperImage

            anchors.fill: parent
            visible: root.wallpaperType === "image" && status !== Image.Error
            source: root.wallpaperType === "image" ? root.wallpaperPath : ""
            sourceSize: Qt.size(width, height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            mipmap: true
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            visible: root.wallpaperType === "gradient"

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: root.wallpaper && root.wallpaper.colors && root.wallpaper.colors.length > 0 ? root.wallpaper.colors[0] : Theme.bgColor
                }
                GradientStop {
                    position: 1.0
                    color: root.wallpaper && root.wallpaper.colors && root.wallpaper.colors.length > 1 ? root.wallpaper.colors[root.wallpaper.colors.length - 1] : Theme.bgColor
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: root.wallpaperType === "color"
            color: root.wallpaper && root.wallpaper.color ? root.wallpaper.color : Theme.bgColor
        }

        Item {
            anchors.fill: parent
            visible: root.wallpaperType === "video"

            MediaPlayer {
                id: wallpaperVideo

                source: root.wallpaperType === "video" ? root.wallpaperPath : ""
                loops: MediaPlayer.Infinite
                videoOutput: wallpaperVideoOutput
                audioOutput: AudioOutput {
                    muted: true
                }

                onSourceChanged: {
                    if (source.toString() !== "")
                        play();
                }
                Component.onCompleted: {
                    if (source.toString() !== "")
                        play();
                }
                Component.onDestruction: {
                    stop();
                    source = "";
                }
            }

            VideoOutput {
                id: wallpaperVideoOutput

                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
            }
        }
    }

    // Keeps text readable over very bright wallpapers, matching the subtle
    // darkening used by the SDDM theme.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.overlayOpacity
    }
}

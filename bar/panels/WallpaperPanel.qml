import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "black"

    // Holds the currently selected random animation type
    property int transitionStyle: 0

    // Component wrapper allowing StackView to spawn multiple layered instances
    Component {
        id: wallpaperVisual
        Item {
            id: wpWrapper
            property var wp: null

            // Dynamic Loader (Only instantiates the active type)
            Loader {
                id: contentLoader
                anchors.fill: parent
                asynchronous: false
                sourceComponent: {
                    if (!wpWrapper.wp || !wpWrapper.wp.type)
                        return null;
                    switch (wpWrapper.wp.type) {
                    case "image":
                        return imageComp;
                    case "video":
                        return videoComp;
                    case "gradient":
                        return gradientComp;
                    case "pattern":
                        return patternComp;
                    case "color":
                        return colorComp;
                    default:
                        return null;
                    }
                }
            }

            // Static Image Wallpaper
            Component {
                id: imageComp
                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: (wpWrapper.wp && wpWrapper.wp.path) ? wpWrapper.wp.path : ""
                    sourceSize: Qt.size(root.screen ? root.screen.width : 1920, root.screen ? root.screen.height : 1080)
                    asynchronous: true
                    mipmap: true
                    smooth: true
                    cache: true
                }
            }
            // Video Wallpaper
            Component {
                id: videoComp
                Item {
                    anchors.fill: parent

                    MediaPlayer {
                        id: videoPlayer
                        source: (wpWrapper.wp && wpWrapper.wp.path) ? wpWrapper.wp.path : ""
                        loops: MediaPlayer.Infinite
                        videoOutput: videoOutput
                        audioOutput: AudioOutput {
                            volume: WallpaperService.videoVolume
                            muted: WallpaperService.videoMuted
                        }

                        Component.onCompleted: play()
                    }

                    VideoOutput {
                        id: videoOutput
                        anchors.fill: parent
                        fillMode: VideoOutput.PreserveAspectCrop
                    }
                }
            }

            // Gradient Wallpaper
            Component {
                id: gradientComp
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop {
                            position: 0.0
                            color: (wpWrapper.wp && wpWrapper.wp.colors && wpWrapper.wp.colors.length > 0) ? wpWrapper.wp.colors[0] : "#000000"
                        }
                        GradientStop {
                            position: 1.0
                            color: (wpWrapper.wp && wpWrapper.wp.colors && wpWrapper.wp.colors.length > 1) ? wpWrapper.wp.colors[1] : "#222222"
                        }
                    }
                }
            }

            // Pattern Wallpaper
            Component {
                id: patternComp
                Canvas {
                    id: patternCanvas
                    anchors.fill: parent

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const curWp = wpWrapper.wp;
                        if (!curWp)
                            return;

                        ctx.fillStyle = curWp.bgColor || "#111116";
                        ctx.fillRect(0, 0, width, height);

                        ctx.fillStyle = curWp.fgColor || "#333346";
                        ctx.strokeStyle = curWp.fgColor || "#333346";
                        ctx.lineWidth = 1;

                        const style = curWp.patternStyle || "dots";
                        if (style === "dots") {
                            const step = 28;
                            for (let x = step / 2; x < width; x += step) {
                                for (let y = step / 2; y < height; y += step) {
                                    ctx.beginPath();
                                    ctx.arc(x, y, 2, 0, Math.PI * 2);
                                    ctx.fill();
                                }
                            }
                        } else if (style === "grid") {
                            const step = 36;
                            ctx.beginPath();
                            for (let x = 0; x < width; x += step) {
                                ctx.moveTo(x, 0);
                                ctx.lineTo(x, height);
                            }
                            for (let y = 0; y < height; y += step) {
                                ctx.moveTo(0, y);
                                ctx.lineTo(width, y);
                            }
                            ctx.stroke();
                        } else if (style === "diagonal") {
                            const step = 32;
                            ctx.beginPath();
                            for (let x = -height; x < width; x += step) {
                                ctx.moveTo(x, 0);
                                ctx.lineTo(x + height, height);
                            }
                            ctx.stroke();
                        }
                    }

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                }
            }

            // Solid Color Wallpaper
            Component {
                id: colorComp
                Rectangle {
                    anchors.fill: parent
                    color: (wpWrapper.wp && wpWrapper.wp.color) ? wpWrapper.wp.color : "#0A0A0D"
                }
            }
        }
    }
    // StackView ensures a smooth and continuous cross-fading buffer state
    StackView {
        id: bgStack
        anchors.fill: parent
        initialItem: Rectangle {
            color: "black"
        }

        replaceEnter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.animationDuration
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                property: "scale"
                from: root.transitionStyle === 0 ? 1.05 : (root.transitionStyle === 1 ? 0.95 : 1.0)
                to: 1.0
                duration: Theme.animationDuration
                easing.type: Easing.OutQuart
            }
        }
        replaceExit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Theme.animationDuration
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                property: "scale"
                from: 1.0
                to: root.transitionStyle === 0 ? 0.95 : (root.transitionStyle === 1 ? 1.05 : 1.0)
                duration: Theme.animationDuration
                easing.type: Easing.OutQuart
            }
        }
    }

    Connections {
        target: WallpaperService
        function onCurrentWallpaperChanged() {
            if (!WallpaperService.currentWallpaper)
                return;

            root.transitionStyle = Math.floor(Math.random() * 3);
            bgStack.replace(wallpaperVisual, {
                wp: WallpaperService.currentWallpaper
            });
        }
    }

    Component.onCompleted: {
        if (WallpaperService.currentWallpaper) {
            root.transitionStyle = Math.floor(Math.random() * 3);
            bgStack.replace(wallpaperVisual, {
                wp: WallpaperService.currentWallpaper
            });
        }
    }

    // Video Audio Controls (bottom-right visible when video active)
    Rectangle {
        id: audioControl
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        visible: WallpaperService.currentWallpaper && WallpaperService.currentWallpaper.type === "video"

        implicitWidth: audioRow.implicitWidth + 24
        implicitHeight: 40
        radius: Theme.cornerRadius
        color: "transparent"
        //border.color: Theme.mutedAccent
        //border.width: Theme.generalThickness

        Behavior on color {
            CAnim {}
        }

        MouseArea {
            id: mouseHover
            anchors.fill: parent
            hoverEnabled: true
        }

        RowLayout {
            id: audioRow
            anchors.centerIn: parent
            spacing: 8

            ClickButton {
                symbol: WallpaperService.videoMuted ? "audio-volume-muted" : "audio-volume-high"
                size: 24
                onPress: WallpaperService.toggleMute()
                bgColor: "transparent"
                onScroll: delta => {
                    let step = delta > 0 ? 0.01 : -0.01;
                    let newVolume = WallpaperService.videoVolume + step;
                    WallpaperService.videoVolume = Math.max(0.0, Math.min(1.0, newVolume));
                    if (WallpaperService.videoVolume === 0.0) {
                        this.toggleMute();
                    }
                }
            }
        }
    }
}

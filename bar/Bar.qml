import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Io
import "root:/"
import "modules"
import "root:/bar/panels"

Scope {
    id: root
    property var screen: null

    IpcHandler {
        target: "bar"
    }
    PanelWindow {
        id: bar
        screen: root.screen
        WlrLayershell.layer: WlrLayer.Top
        property var toggledPanels: ({})
        function hideAllPanelExcept(exception) {
            for (const k in toggledPanels) {
                if (toggledPanels[k] && k !== exception)
                    toggledPanels[k].visible = false;
            }
        }

        implicitHeight: Theme.barHeight + Theme.barVerticalPad
        visible: true
        color: Theme.panelBg
        anchors {
            top: true
            bottom: false
            left: true
            right: true
        }
        margins {
            left: Theme.barHorizontalPad
            right: Theme.barHorizontalPad
            top: Theme.barVerticalPad
            bottom: 0
        }
        IpcHandler {
            target: "ii1qe"
            function arch() {
                arch.togglePanel();
            }
            function wifi() {
                sys.toggleWifiPanel();
            }
            function sound() {
                sys.toggleSoundPanel();
            }
            function bluetooth() {
                sys.toggleBluetoothPanel();
            }
            function shutdown() {
                shutdownLoader.active = true;
                shutdownLoader.item.togglePanel();
            }
            function calendar() {
                clock.togglePanel();
            }
            function workspace() {
                workspaces.togglePanel();
            }
            function nextWallpaper() {
                wallpaperPreviewLoader.active = true;
                wallpaperPreviewLoader.item.nextWallpaper();
            }
            function previousWallpaper() {
                wallpaperPreviewLoader.active = true;
                wallpaperPreviewLoader.item.previousWallpaper();
            }
            function showWallpaper() {
                wallpaperPreviewLoader.active = true;
                wallpaperPreviewLoader.item.showWallpaper();
            }
            function launcher() {
                launcherLoader.active = true;
                launcherLoader.item.toggle();
            }
            function overlay() {
                sysOverlayLoader.active = true;
                sysOverlayLoader.item.toggle();
            }
        }
        LazyLoader {
            id: shutdownLoader
            loading: true
            ShutdownScreen {
                panelHost: bar
            }
        }
        LazyLoader {
            id: wallpaperPreviewLoader
            loading: true
            WallpaperPreviewPanel {
                panelHost: bar
            }
        }
        LazyLoader {
            id: launcherLoader
            loading: true
            LauncherPanel {
                panelHost: bar
            }
        }
        LazyLoader {
            id: sysOverlayLoader
            loading: true
            SystemMonitorOverlay {
                screen: root.screen
            }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Row {
                    id: leftModules
                    spacing: 8
                    Arch {
                        id: arch
                        panelHost: bar
                        sysItems: sys
                    }
                    SysItems {
                        id: sys
                        panelHost: bar
                    }
                    Tray {
                        panelHost: bar
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Row {
                    id: centerModules
                    anchors.centerIn: parent
                    spacing: 8
                    Workspaces {
                        id: workspaces
                        panelHost: bar
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Row {
                    id: rightModules
                    anchors.right: parent.right
                    spacing: 8
                    CriticalWarning {
                        id: criticalWarning
                        panelHost: bar
                    }
                    Clock {
                        id: clock
                        panelHost: bar
                    }
                }
            }
        }
    }
}

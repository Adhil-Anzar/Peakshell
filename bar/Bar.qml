import Quickshell
import QtQuick
import QtQuick.Layouts
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
                shutdown.togglePanel();
            }
            function calendar() {
                clock.togglePanel();
            }
            function workspace() {
                workspaces.togglePanel();
            }
            function nextWallpaper() {
                wallpaperPreview.nextWallpaper();
            }
            function previousWallpaper() {
                wallpaperPreview.previousWallpaper();
            }
            function showWallpaper() {
                wallpaperPreview.showWallpaper();
            }
        }
        ShutdownScreen {
            id: shutdown
            panelHost: bar
        }
        WallpaperPreviewPanel {
            id: wallpaperPreview
            panelHost: bar
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

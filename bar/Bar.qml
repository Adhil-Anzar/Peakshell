import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Io
import "root:/"
import "root:/services"
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
        function openSettings() {
            settingsLoader.active = true;
            settingsLoader.item.toggle();
        }
        function openLauncher() {
            launcherLoader.active = true;
            launcherLoader.item.toggle();
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
            function notifications() {
                sys.toggleNotificationPanel();
            }
            function media() {
                media.togglePanel();
            }
            function powermenu() {
                shutdownLoader.active = true;
                shutdownLoader.item.togglePanel();
            }
            // Directly run one of the power actions (logout, switch, reboot,
            // sleep, hibernate, shutdown) without opening the power menu.
            function power(action: string) {
                if (action === "sleep" || action === "logout")
                    lockScreen.lock();
                Power.execute(action);
            }
            function calendar() {
                clock.togglePanel();
            }
            function timer() {
                clock.toggleTimerPanel();
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
            function clipboard() {
                clipboardLoader.active = true;
                clipboardLoader.item.toggle();
            }
            function overlay() {
                sysOverlayLoader.active = true;
                sysOverlayLoader.item.toggle();
            }
            function settings() {
                bar.openSettings();
            }
        }
        LazyLoader {
            id: settingsLoader
            loading: true
            SettingsPanel {
                panelHost: bar
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
            id: clipboardLoader
            loading: true
            ClipboardPanel {
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
        LazyLoader {
            id: notifPopupLoader
            loading: true
            NotificationPopup {
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
                    MediaPlayer {
                        id: media
                        panelHost: bar
                        visible: Theme.moduleMediaPlayer
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
                        visible: Theme.moduleWorkspaces
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
                        visible: Theme.moduleDateTime
                    }
                }
            }
        }
    }
}

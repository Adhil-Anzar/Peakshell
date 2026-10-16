import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Io
import "root:/"
import PeakShell.Services
import "root:/components"
import "root:/services"

Scope {
    id: root
    property var screen: null
    function toggle() {
        sysMonitorOverlay.visible = !sysMonitorOverlay.visible;
    }
    PanelWindow {
        id: sysMonitorOverlay
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: hasFullscreen ? ExclusionMode.Ignore : ExclusionMode.Auto
        screen: root.screen
        visible: false
        color: "transparent"

        readonly property bool hasFullscreen: {
            if (!screen || !Hypr.focusedMonitor)
                return false;
            const mon = Hypr.focusedMonitor;
            const specialWs = mon.lastIpcObject?.specialWorkspace?.name;
            if (specialWs) {
                const sWs = Hypr.workspaces.values.find(w => w.name === specialWs);
                if (sWs && sWs.toplevels.values.some(t => t.lastIpcObject?.fullscreen > 1))
                    return true;
            }
            const activeWs = mon.activeWorkspace;
            if (activeWs && activeWs.toplevels.values.some(t => t.lastIpcObject?.fullscreen > 1))
                return true;
            return false;
        }

        implicitWidth: overlayLayout.implicitWidth + 24
        implicitHeight: overlayLayout.implicitHeight + 16

        anchors {
            top: true
            left: true
            bottom: false
            right: false
        }

        margins {
            top: Theme.barVerticalPad * 2
            left: Theme.barHorizontalPad
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.bgColor
            border.color: Theme.mutedFgColor
            border.width: Theme.generalThickness / 2
            radius: Theme.cornerRadius
            Behavior on width {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }
            RowLayout {
                id: overlayLayout
                anchors.centerIn: parent
                spacing: 16

                RowLayout {
                    spacing: 6
                    IconImage {
                        implicitSize: 16
                        source: Quickshell.iconPath("indicator-sensors-cpu")
                    }
                    Text {
                        text: "CPU: " + SystemMonitor.cpuLoad + "% (" + SystemMonitor.cpuTemp + "°C)"
                        color: Theme.fgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                    }
                }

                RowLayout {
                    spacing: 6
                    IconImage {
                        implicitSize: 16
                        source: Quickshell.iconPath("indicator-sensors-gpu")
                    }
                    Text {
                        text: "GPU: " + SystemMonitor.gpuLoad + "% (" + SystemMonitor.gpuTemp + "°C)"
                        color: Theme.fgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                    }
                }

                RowLayout {
                    spacing: 6
                    IconImage {
                        implicitSize: 16
                        source: Quickshell.iconPath("indicator-sensors-memory")
                    }
                    Text {
                        text: "RAM: " + SystemMonitor.memUsage + "%"
                        color: Theme.fgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                    }
                }
            }
        }
    }
}

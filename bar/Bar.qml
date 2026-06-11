import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "root:/"
import Quickshell.Wayland
import Quickshell.Services.Pipewire

Scope {
    IpcHandler {
        target: "bar"
    }
    PanelWindow {
        id: bar
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
        SocketServer {
          active: true
          path: "/tmp/quickshell.sock"
          handler: Socket {
            onConnectedChanged: {
              //console.log(connected ? "new connection!" : "connection dropped!")
            }
            parser: SplitParser {
              onRead: (message) => {
                    // Commands echo "<thing>" | socat - UNIX-CONNECT:/tmp/quickshell.sock
                    if (message === "toggleArchPanel") arch.togglePanel();
                    if (message === "toggleWifiPanel") sys.toggleWifiPanel();
                    if (message === "toggleSoundPanel") sys.toggleSoundPanel();
                }
            }
          }
        }
        PwNodeLinkTracker {
            id: outputLinkTracker
            node: Pipewire.defaultAudioSink
        }
        PwNodeLinkTracker {
            id: inputLinkTracker
            node: Pipewire.preferredDefaultAudioSource
        }
        RowLayout {
            anchors.fill: parent
            Row {
                id: leftModules
                spacing: 8

                Arch { id: arch }
                SysItems { id: sys; outputLinkGroups: outputLinkTracker.linkGroups; inputLinkGroups: inputLinkTracker.linkGroups; }
            }
            Row {
                id: centerModules
                spacing: 8
            }
            Row {
                id: rightModules
                spacing: 8
            }


        }

    }
}

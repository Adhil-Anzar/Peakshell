pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property int notificationCount: -1
    property bool isDndOn: false
    function togglePanel(){
        toggleSwaync.startDetached();
    }
    function toggleDnd() {
        toggleDnd.startDetached();
    }

    Process {
        id: toggleSwaync
        command: ["sh", "-c", "swaync-client --toggle-panel"]
    }
    Process {
        id: toggleDnd
        command: ["sh", "-c", "swaync-client --toggle-dnd"]
    }

    Process {
        id: subscribeNotification
        command: ["swaync-client", "--subscribe"]
        running: true
        stdout: StdioCollector {
            waitForEnd: false
            onTextChanged: {
                const lines = text.toString().split('\n')
                const data = JSON.parse(lines[lines.length - 2]) // The second last item is the proper json
                root.notificationCount = data.count;
                root.isDndOn = data.dnd
            }
        }
    }
}

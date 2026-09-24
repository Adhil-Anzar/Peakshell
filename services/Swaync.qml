pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property int notificationCount: 0
    property bool isDndOn: false
    property string icon: {
        if (isDndOn)
            return "notification-disabled"
        if (notificationCount === 0)
            return "notification-inactive"
        return "notification-active"
    }
    property string nullableMessage: notificationCount === 0 ? "" : notificationCount + " Notifications"
    property string message: {
        if (isDndOn)
            return "DND Active"
        if (notificationCount === 0)
            return "Notification"
        return notificationCount + " Notifications"
    }

    function togglePanel() {
        togglePanelProc.startDetached()
    }
    function toggleDnd() {
        toggleDndProc.startDetached()
    }

    Process {
        id: togglePanelProc
        command: ["sh", "-c", "swaync-client --toggle-panel"]
    }
    Process {
        id: toggleDndProc
        command: ["sh", "-c", "swaync-client --toggle-dnd"]
    }
    Process {
        id: subscribeNotification
        command: ["swaync-client", "--subscribe"]
        running: true
        stdout: StdioCollector {
            waitForEnd: false
            onTextChanged: {
                const lines = text.toString().trim().split("\n").filter(line => line.length > 0)
                if (lines.length === 0)
                    return
                try {
                    const data = JSON.parse(lines[lines.length - 1])
                    root.notificationCount = data.count
                    root.isDndOn = data.dnd
                } catch (e) {
                    // Partial line while the subscribe stream is still writing.
                }
            }
        }
    }
}

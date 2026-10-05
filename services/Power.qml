pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var powerActions: [
        {
            id: "logout",
            name: "Logout",
            icon: "system-log-out",
            cmd: ["sh", "-c", "hyprshutdown"]
        },
        {
            id: "reboot",
            name: "Reboot",
            icon: "system-reboot",
            cmd: ["sh", "-c", "'hyprshutdown -t 'Restarting...' --post-cmd 'systemctl reboot' || systemctl reboot'"]
        },
        {
            id: "sleep",
            name: "Sleep",
            icon: "system-suspend",
            cmd: ["systemctl", "suspend"]
        },
        {
            id: "hibernate",
            name: "Hibernate",
            icon: "system-suspend-hibernate",
            cmd: ["sh", "-c", "'hyprshutdown -t 'Hibernating...' --post-cmd 'systemctl hibernate' || systemctl hibernate'"]
        },
        {
            id: "shutdown",
            name: "Shutdown",
            icon: "system-shutdown",
            cmd: ["sh", "-c", "hyprshutdown -t 'Shutting down...' --post-cmd 'systemctl poweroff' || systemctl poweroff"]
        }
    ]

    Process {
        id: execProc
        running: false
    }

    function execute(actionId) {
        const index = powerActions.findIndex(a => a.id === actionId);
        if (index !== -1) {
            executeAction(index);
        }
    }

    function executeAction(index) {
        if (index >= 0 && index < powerActions.length) {
            execProc.running = false;
            execProc.command = powerActions[index].cmd;
            execProc.startDetached();
        }
    }
}

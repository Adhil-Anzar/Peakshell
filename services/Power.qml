pragma Singleton

import QtQuick
import Quickshell
import PeakShell.Services

Singleton {
    id: root

    readonly property var powerActions: [
        {
            id: "logout",
            name: "Logout",
            icon: "system-log-out"
        },
        {
            id: "switch",
            name: "Switch User",
            icon: "system-switch-user"
        },
        {
            id: "reboot",
            name: "Reboot",
            icon: "system-reboot"
        },
        {
            id: "sleep",
            name: "Sleep",
            icon: "system-suspend"
        },
        {
            id: "hibernate",
            name: "Hibernate",
            icon: "system-suspend-hibernate"
        },
        {
            id: "shutdown",
            name: "Shutdown",
            icon: "system-shutdown"
        }
    ]

    function execute(actionId) {
        SessionManager.execute(actionId);
    }

    function executeAction(index) {
        if (index >= 0 && index < powerActions.length) {
            SessionManager.execute(powerActions[index].id);
        }
    }
}

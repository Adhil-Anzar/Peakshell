pragma Singleton

import QtQuick
import Quickshell
import PeakShell

Singleton {
    id: root

    property int notificationCount: 0
    property bool isDndOn: false

    // Static default icon and message that always load reliably
    property string icon: isDndOn ? "notification-disabled" : "notification-active"
    property string nullableMessage: ""
    property string message: isDndOn ? "DND Active" : "Notifications"

    function togglePanel() {
        Utils.execute("swaync-client", ["--toggle-panel"]);
    }

    function toggleDnd() {
        isDndOn = !isDndOn;
        Utils.execute("swaync-client", ["--toggle-dnd"]);
    }
}

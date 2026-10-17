pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import PeakShell

Singleton {
    id: root
    property var items: []
    property ListModel popupModel: ListModel {}
    property int notificationCount: items.length
    property int unreadCount: items.length
    property bool isDndOn: false
    property string icon: isDndOn ? "notification-disabled" : "notification-active"
    // Bar icon: reflects whether anything is waiting, regardless of DND.
    property string barIcon: notificationCount > 0 ? "notification-active" : "notification-inactive"
    property string nullableMessage: notificationCount > 0 ? String(notificationCount) : ""
    property string message: isDndOn ? "DND Active" : (notificationCount > 0 ? notificationCount + " Notifications" : "Notifications")
    property int popupTimeout: Settings.notificationPopupTimeout
    property int criticalTimeout: 8000
    property int maxPopups: Settings.notificationMaxPopups
    property bool popupHovered: false
    property var pendingPopups: []
    property int popupStagger: 150

    function timeStr(t) {
        var ms = (t instanceof Date) ? t.getTime() : t;
        if (typeof ms !== "number" || !isFinite(ms))
            return "now";
        var diff = Date.now() - ms;
        var m = Math.floor(diff / 60000);
        if (m < 1)
            return "now";
        var h = Math.floor(m / 60);
        var d = Math.floor(h / 24);
        if (d > 0)
            return d + "d";
        if (h > 0)
            return h + "h";
        return m + "m";
    }

    function notifText(summary, body) {
        var parts = [];
        if (summary && summary.length > 0)
            parts.push(summary);
        var b = (body || "").replace(/<[^>]*>/g, "").trim();
        if (b.length > 0)
            parts.push(b);
        return parts.join("\n");
    }

    function refresh() {
        items = items.slice();
    }

    function popupIndex(key) {
        for (var i = 0; i < popupModel.count; ++i) {
            if (popupModel.get(i).key === key)
                return i;
        }
        return -1;
    }

    function entryByKey(key) {
        for (var i = 0; i < items.length; ++i) {
            if (items[i].key === key)
                return items[i];
        }
        return null;
    }

    function beginRemovePopup(key) {
        var i = popupIndex(key);
        if (i < 0)
            return;
        popupModel.setProperty(i, "exiting", true);
        exitSweepTimer.restart();
    }

    Timer {
        id: exitSweepTimer
        interval: 240
        repeat: false
        onTriggered: {
            for (var i = popupModel.count - 1; i >= 0; --i) {
                if (popupModel.get(i).exiting)
                    popupModel.remove(i);
            }
        }
    }

    function pushPopup(key) {
        popupModel.insert(0, {
            key: key,
            exiting: false
        });
        while (popupModel.count > maxPopups)
            popupModel.remove(popupModel.count - 1);
    }

    function toggleDnd() {
        isDndOn = !isDndOn;
        if (isDndOn) {
            pendingPopups = [];
            popupModel.clear();
        }
    }

    function dismiss(key) {
        beginRemovePopup(key);
        for (var i = 0; i < items.length; ++i) {
            if (items[i].key === key) {
                var entry = items[i];
                items.splice(i, 1);
                try {
                    entry.notif.dismiss();
                } catch (e) {}
                try {
                    entry.object.destroy();
                } catch (e) {}
                break;
            }
        }
        refresh();
    }

    function hidePopup(key) {
        beginRemovePopup(key);
    }

    function externalRemove(key) {
        beginRemovePopup(key);
        for (var i = 0; i < items.length; ++i) {
            if (items[i].key === key) {
                try {
                    items[i].object.destroy();
                } catch (e) {}
                items.splice(i, 1);
                break;
            }
        }
        refresh();
    }

    function clearGroup(appName) {
        for (var i = items.length - 1; i >= 0; --i) {
            if ((items[i].notif.appName || "Unknown") === appName) {
                beginRemovePopup(items[i].key);
                try {
                    items[i].notif.dismiss();
                } catch (e) {}
                try {
                    items[i].object.destroy();
                } catch (e) {}
                items.splice(i, 1);
            }
        }
        refresh();
    }

    function clearAll() {
        pendingPopups = [];
        popupModel.clear();
        for (var i = 0; i < items.length; ++i) {
            try {
                items[i].notif.dismiss();
            } catch (e) {}
            try {
                items[i].object.destroy();
            } catch (e) {}
        }
        items = [];
        refresh();
    }

    function invokeAction(key, identifier) {
        for (var i = 0; i < items.length; ++i) {
            if (items[i].key === key) {
                var acts = items[i].notif.actions;
                for (var j = 0; j < acts.length; ++j) {
                    if (acts[j].identifier === identifier) {
                        try {
                            acts[j].invoke();
                        } catch (e) {}
                        break;
                    }
                }
                if (!items[i].notif.resident)
                    dismiss(key);
                break;
            }
        }
    }

    Timer {
        id: popupQueueTimer
        interval: root.popupStagger
        repeat: true
        running: false
        onTriggered: {
            if (pendingPopups.length === 0) {
                running = false;
                return;
            }
            var key = pendingPopups.shift();
            var entry = entryByKey(key);
            if (entry !== null) {
                entry.expireAt = Date.now() + entry.timeout;
                pushPopup(key);
            }
        }
    }

    Timer {
        id: expireTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            var now = Date.now();
            for (var i = root.items.length - 1; i >= 0; --i) {
                var k = root.items[i].key;
                if (root.popupIndex(k) < 0)
                    continue;
                if (now >= root.items[i].expireAt) {
                    if (root.popupHovered)
                        root.items[i].expireAt = now + 1000;
                    else
                        root.beginRemovePopup(k);
                }
            }
        }
    }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: notif => {
            notif.tracked = true;
            var timeout = notif.expireTimeout > 0 ? notif.expireTimeout : (notif.urgency === NotificationUrgency.Critical ? root.criticalTimeout : root.popupTimeout);
            var holder = entryComp.createObject(root, {
                notif: notif
            });
            var entry = {
                key: notif.id + "_" + Date.now() + "_" + Math.floor(Math.random() * 100000),
                notif: notif,
                object: holder,
                time: new Date(),
                timeout: timeout,
                expireAt: Date.now() + timeout
            };
            holder.entryKey = entry.key;
            root.items = [entry].concat(root.items);
            if (!root.isDndOn) {
                root.pendingPopups.push(entry.key);
                if (root.pendingPopups.length > 12)
                    root.pendingPopups.shift();
                if (!popupQueueTimer.running)
                    popupQueueTimer.start();
            }
            root.refresh();
        }
    }

    Component {
        id: entryComp
        QtObject {
            property var notif
            property string entryKey: ""
            readonly property Connections conn: Connections {
                target: notif
                function onClosed() {
                    root.externalRemove(entryKey);
                }
            }
        }
    }

    IpcHandler {
        target: "notifications"
        function clear() {
            root.clearAll();
        }
        function toggleDnd() {
            root.toggleDnd();
        }
    }
}

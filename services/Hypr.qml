pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors

    readonly property HyprlandToplevel activeToplevel: Hyprland.activeToplevel
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace ? focusedWorkspace.id : 1

    function dispatch(request) {
        Hyprland.dispatch(request);
    }

    function focusWorkspace(ws) {
        dispatch("workspace " + ws);
    }

    function toggleSpecial(name) {
        dispatch("togglespecialworkspace " + (name ? name : "special"));
    }

    function focusWindow(address) {
        dispatch("focuswindow address:" + address);
    }

    function closeWindow(address) {
        dispatch("closewindow address:" + address);
    }

    function forceKillWindow(pid, address) {
        if (pid) {
            forceKillProc.command = ["kill", "-9", String(pid)];
            forceKillProc.running = true;
        } else if (address) {
            closeWindow(address);
        }
    }

    Process {
        id: forceKillProc
        running: false
    }

    function toplevelsForWs(wsId) {
        return Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.id === wsId);
    }

    function workspaceById(wsId) {
        return Hyprland.workspaces.values.find(w => w.id === wsId) || null;
    }

    function trimWsName(name) {
        return (name && name.startsWith("special:")) ? name.slice("special:".length) : (name || "");
    }

    // ------- Urgency tracking -------
    // Map of workspaceId -> true for workspaces with an urgent window
    property var urgentWorkspaceIds: ({})
    // Last cleared workspace id for the timer
    property int _urgentClearWsId: -1

    Timer {
        id: urgentClearTimer
        interval: 3000
        repeat: false
        onTriggered: {
            const id = root._urgentClearWsId
            if (id !== -1) {
                const copy = Object.assign({}, root.urgentWorkspaceIds)
                delete copy[id]
                root.urgentWorkspaceIds = copy
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n.endsWith("v2"))
                return;

            if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
            }

            // Urgency: an app is asking for attention
            if (n === "urgent") {
                const rawAddr = event.data ? event.data.trim() : "";
                // Hyprland emits the address with 0x prefix in urgent events
                const t = Hyprland.toplevels.values.find(function(top) {
                    if (!top.lastIpcObject) return false;
                    const a = top.lastIpcObject.address || "";
                    return a === rawAddr || a === ("0x" + rawAddr) || ("0x" + a) === rawAddr;
                });
                if (t && t.workspace) {
                    const wsId = t.workspace.id;
                    const copy = Object.assign({}, root.urgentWorkspaceIds);
                    copy[wsId] = true;
                    root.urgentWorkspaceIds = copy;
                    root._urgentClearWsId = wsId;
                    urgentClearTimer.restart();
                }
            }
        }
    }
}


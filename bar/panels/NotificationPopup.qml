import QtQuick
import Quickshell
import Quickshell.Wayland
import PeakShell
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: root

    readonly property string notifPos: Settings.notificationPosition
    readonly property bool atTop: notifPos === "topLeft" || notifPos === "topRight"
    readonly property bool atLeft: notifPos === "topLeft" || notifPos === "bottomLeft"
    readonly property real enterX: atLeft ? -40 : 40

    color: "transparent"
    visible: Notifications.popupModel.count > 0
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    anchors {
        top: root.atTop
        bottom: !root.atTop
        left: root.atLeft
        right: !root.atLeft
    }
    margins {
        top: Theme.barHeight + Theme.barVerticalPad * 2 + Theme.dropdownOffset
        bottom: Theme.barVerticalPad + Theme.dropdownOffset
        left: Theme.barHorizontalPad
        right: Theme.barHorizontalPad
    }
    implicitWidth: Theme.notificationPopupWidth
    implicitHeight: popupCol.implicitHeight

    Column {
        id: popupCol
        anchors.fill: parent
        spacing: 8

        HoverHandler {
            id: listHover
            onHoveredChanged: Notifications.popupHovered = hovered
        }

        Repeater {
            model: Notifications.popupModel
            delegate: Item {
                required property string key
                required property bool exiting
                readonly property var entry: Notifications.entryByKey(key)
                width: popupCol.width
                height: card.implicitHeight
                property bool entered: false
                opacity: (entered && !exiting) ? 1 : 0
                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
                scale: (entered && !exiting) ? 1 : 0.94
                Behavior on scale {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
                transformOrigin: Item.Center
                transform: Translate {
                    x: (entered && !exiting) ? 0 : root.enterX
                    Behavior on x {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }
                Component.onCompleted: entered = true
                NotificationCard {
                    id: card
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    entryKey: key
                    summary: entry !== null ? entry.notif.summary : ""
                    body: entry !== null ? entry.notif.body : ""
                    appName: entry !== null ? entry.notif.appName : ""
                    appIcon: entry !== null ? entry.notif.appIcon : ""
                    image: entry !== null ? entry.notif.image : ""
                    urgency: entry !== null ? entry.notif.urgency : 1
                    time: entry !== null ? entry.time : new Date()
                    actions: entry !== null ? entry.notif.actions : []
                    popupMode: true
                }
            }
        }
    }
}

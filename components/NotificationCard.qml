import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "root:/"
import "root:/components"
import "root:/services"

Rectangle {
    id: root
    signal cardClicked
    property bool clickable: false
    property string entryKey: ""
    property string summary: ""
    property string body: ""
    property string appName: ""
    property string appIcon: ""
    property string image: ""
    property int urgency: 1
    property date time: new Date()
    property var actions: []
    property bool popupMode: false
    property bool isCritical: urgency === NotificationUrgency.Critical
    readonly property string titleText: {
        var s = (root.summary || "").trim();
        if (s.length > 0)
            return root.summary;
        var a = (root.appName || "").trim();
        if (a.length > 0)
            return a;
        var b = (root.body || "").replace(/<[^>]*>/g, "").trim().split("\n")[0] || "";
        if (b.length > 0)
            return b;
        return "Notification";
    }

    function plainText() {
        var parts = [];
        if (root.summary && root.summary.length > 0)
            parts.push(root.summary);
        var b = (root.body || "").replace(/<[^>]*>/g, "").trim();
        if (b.length > 0)
            parts.push(b);
        return parts.join("\n");
    }

    implicitWidth: Theme.notificationPopupWidth
    implicitHeight: mainCol.implicitHeight + 24
    radius: Theme.cornerLargeRadius
    color: notifMouse.containsMouse ? Theme.hoveredBgColor : Theme.bgColor
    border.width: Theme.generalThickness

    property color borderColor: isCritical ? Theme.dangerPulse : Theme.mutedAccent
    border.color: borderColor

    SequentialAnimation {
        running: root.isCritical
        loops: Animation.Infinite
        ColorAnimation {
            target: root
            property: "borderColor"
            from: Theme.dangerPulse
            to: Theme.danger
            duration: 750
            easing.type: Easing.InOutSine
        }
        ColorAnimation {
            target: root
            property: "borderColor"
            from: Theme.danger
            to: Theme.dangerPulse
            duration: 750
            easing.type: Easing.InOutSine
        }
    }

    Behavior on color {
        CAnim {}
    }

    MouseArea {
        id: notifMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.cardClicked()
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            IconImage {
                Layout.alignment: Qt.AlignVCenter
                implicitSize: Theme.notificationIconSize
                source: {
                    if (root.image && root.image.length > 0)
                        return root.image;
                    return Quickshell.iconPath(root.appIcon && root.appIcon.length > 0 ? root.appIcon : "indicator-messages-new", "indicator-messages-new");
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Text {
                    width: parent.width
                    text: root.titleText
                    color: Theme.fgColor
                    font.bold: true
                    font.pointSize: Theme.labelFontSize + 1
                    font.family: Theme.labelFontFamily
                    elide: Text.ElideRight
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                Text {
                    width: parent.width
                    text: (root.appName.length > 0 ? root.appName : "Notification") + " • " + Notifications.timeStr(root.time)
                    color: Theme.mutedFgColor
                    font.pointSize: Theme.labelFontSize * 0.85
                    font.family: Theme.labelFontFamily
                    elide: Text.ElideRight
                }
            }

            ClickButton {
                Layout.alignment: Qt.AlignTop
                symbol: "window-close"
                size: 24
                bgColor: "transparent"
                onPress: {
                    if (root.popupMode)
                        Notifications.hidePopup(root.entryKey);
                    else
                        Notifications.dismiss(root.entryKey);
                }
            }
        }

        Text {
            visible: root.body && root.body.length > 0
            Layout.fillWidth: true
            text: root.body
            color: Theme.mutedFgColor
            font.pointSize: Theme.labelFontSize
            font.family: Theme.labelFontFamily
            wrapMode: Text.Wrap
            maximumLineCount: root.popupMode ? 3 : 8
            elide: Text.ElideRight
            textFormat: Text.RichText
        }

        Row {
            Layout.fillWidth: true
            spacing: 6
            CopyButton {
                copyText: root.plainText()
            }
            Repeater {
                model: root.actions
                delegate: Rectangle {
                    required property var modelData
                    height: actionLabel.implicitHeight + 12
                    width: Math.min(actionLabel.implicitWidth + 20, 160)
                    radius: Theme.cornerRadius
                    color: actMouse.containsMouse ? Theme.accent : Theme.mutedBgColor
                    Behavior on color {
                        CAnim {}
                    }
                    MouseArea {
                        id: actMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifications.invokeAction(root.entryKey, parent.modelData.identifier)
                    }
                    Text {
                        id: actionLabel
                        anchors.centerIn: parent
                        width: parent.width - 20
                        text: parent.modelData.text
                        color: Theme.fgColor
                        font.pointSize: Theme.labelFontSize * 0.9
                        font.family: Theme.labelFontFamily
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}

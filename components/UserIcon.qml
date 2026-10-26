import QtQuick
import "root:/"
import Quickshell.Widgets
import Quickshell

Item {
    id: root
    required property string username
    property real size
    implicitHeight: root.size
    implicitWidth: root.size
    ClippingRectangle {
        anchors.fill: parent
        radius: width / 2
        color: Theme.mutedBgColor

        AnimatedImage {
            id: avatarImage
            anchors.fill: parent
            source: "file:///var/lib/AccountsService/icons/" + root.username
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true

            visible: status === Image.Ready
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: 52
            source: Quickshell.iconPath("user-identity")
            visible: avatarImage.status !== Image.Ready
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: Theme.mutedAccent
        border.width: Theme.generalThickness
    }
}

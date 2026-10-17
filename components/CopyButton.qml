import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/"
import "root:/services"

Rectangle {
    id: root
    property string copyText: ""
    property bool copied: false

    function copy() {
        AppScanner.copyToClipboard(root.copyText);
        root.copied = true;
        copyReset.restart();
    }

    Timer {
        id: copyReset
        interval: 1200
        repeat: false
        onTriggered: root.copied = false
    }

    implicitHeight: copyLabel.implicitHeight + 12
    implicitWidth: copyInner.implicitWidth + 20
    radius: Theme.cornerRadius
    color: copyMouse.containsMouse ? Theme.accent : Theme.mutedBgColor
    Behavior on color {
        CAnim {}
    }
    Behavior on implicitWidth {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    MouseArea {
        id: copyMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.copy()
    }
    Row {
        id: copyInner
        anchors.centerIn: parent
        spacing: 4
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: 16
            source: Quickshell.iconPath("edit-copy")
        }
        Text {
            id: copyLabel
            anchors.verticalCenter: parent.verticalCenter
            text: root.copied ? "copied" : "copy"
            color: Theme.fgColor
            font.pointSize: Theme.labelFontSize * 0.9
            font.family: Theme.labelFontFamily
        }
    }
}

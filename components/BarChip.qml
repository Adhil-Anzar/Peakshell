import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/"

Rectangle {
    id: root
    property string iconName
    property string label
    property int extraButtons: 0
    readonly property bool expanded: hoverDebounce.isDelaying || mouseArea.containsMouse
    signal leftClicked
    signal rightClicked

    function keepExpanded() {
        hoverDebounce.isDelaying = true;
        hoverDebounce.restart();
    }

    height: Theme.barHeight - (Theme.generalThickness * 2)
    width: expanded ? content.width + 32 : content.width + 16
    Behavior on width {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
    radius: Theme.cornerRadius
    color: mouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
    Behavior on color {
        CAnim {}
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | extraButtons
        onEntered: root.keepExpanded()
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.rightClicked();
            if (mouse.button === Qt.LeftButton)
                root.leftClicked();
        }
    }

    Timer {
        id: hoverDebounce
        property bool isDelaying: false
        interval: Theme.hoverDuration
        repeat: false
        running: !mouseArea.containsMouse && isDelaying
        onTriggered: isDelaying = false
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: Theme.iconFontSize
            source: Quickshell.iconPath(root.iconName)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.expanded || opacity > 0.01
            text: root.label
            font.pointSize: Theme.labelFontSize
            font.family: Theme.labelFontFamily
            color: Theme.fgColor
            opacity: root.expanded ? 1 : 0
            scale: root.expanded ? 1 : 0.8
            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }

    }
}

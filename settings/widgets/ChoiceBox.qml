import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import PeakShell

ComboBox {
    id: box
    signal chosen(string v)
    focusPolicy: Qt.NoFocus
    implicitWidth: currentTextObject.implicitWidth + Settings.cornerLargeRadius

    contentItem: TextField {
        id: currentTextObject
        anchors.centerIn: parent
        text: box.currentText
        verticalAlignment: TextInput.AlignVCenter
        leftPadding: Settings.cornerRadius / 2
        color: Settings.mutedFgColor
        font.pointSize: Settings.labelFontSize
        font.family: Settings.labelFontFamily
        readOnly: true
        focusPolicy: Qt.NoFocus
        background: null
    }

    indicator: IconImage {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: Settings.cornerRadius / 2
        }
        implicitSize: Settings.labelFontSize
        source: Quickshell.iconPath("arrow-down")
    }

    background: Rectangle {
        radius: Settings.cornerRadius
        Behavior on color {
            ColorAnimation {
                duration: Settings.animationDuration
            }
        }
        color: clickOverlay.containsMouse ? Settings.hoveredBgColor : "transparent"
    }

    delegate: ItemDelegate {
        required property var modelData
        required property int index
        width: parent.width
        hoverEnabled: true
        highlighted: box.currentIndex === index
        contentItem: Text {
            anchors.fill: parent
            text: modelData
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            color: Settings.mutedFgColor
            font.pointSize: Settings.labelFontSize
            font.family: Settings.labelFontFamily
            elide: Text.ElideRight
        }
        background: Rectangle {
            anchors.fill: parent
            color: Qt.darker(Settings.bgColor, 3)
            border.color: Settings.mutedAccent
            border.width: Settings.generalThickness
            radius: Settings.cornerRadius
        }
    }

    popup: Popup {
        y: box.height + 4
        x: 0
        width: box.width
        padding: 4
        contentItem: ListView {
            spacing: 2
            clip: true
            implicitHeight: Math.min(contentHeight, 200)
            model: box.delegateModel
            currentIndex: box.highlightedIndex
            highlightMoveDuration: 0
        }
        background: Rectangle {
            radius: Settings.cornerRadius
            color: Settings.mutedBgColor
            border.color: Settings.mutedAccent
            border.width: Settings.generalThickness
        }
    }

    MouseArea {
        id: clickOverlay
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (box.popup.visible)
                box.popup.close();
            else
                box.popup.open();
        }
    }

    onActivated: index => chosen(box.model[index])
}

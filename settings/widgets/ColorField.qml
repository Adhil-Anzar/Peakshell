import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import PeakShell

RowLayout {
    property string value: ""
    signal edited(string v)
    spacing: 8
    Rectangle {
        implicitWidth: 34
        implicitHeight: 26
        radius: 8
        color: swatchOk ? value : "transparent"
        border.color: Settings.mutedAccent
        border.width: 1
        property bool swatchOk: parent.value !== "transparent" && parent.value.match(/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/)
    }
    TextField {
        Layout.fillWidth: true
        text: parent.value
        color: Settings.fgColor
        font.pointSize: Settings.labelFontSize
        font.family: Settings.labelFontFamily
        placeholderText: "#AARRGGBB"
        placeholderTextColor: Settings.mutedFgColor
        background: Rectangle {
            color: "transparent"
            border.color: parent.activeFocus ? Settings.accent : Settings.mutedAccent
            border.width: 1
            radius: 8
        }
        onAccepted: {
            parent.edited(text.trim());
            focus = false;
        }
        onEditingFinished: {
            if (activeFocus)
                return;
            parent.edited(text.trim());
        }
    }
}

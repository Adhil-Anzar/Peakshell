import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import PeakShell

TextField {
    property bool commitOnType: false
    signal committed(string v)
    color: Settings.fgColor
    font.pointSize: Settings.labelFontSize
    font.family: Settings.labelFontFamily
    placeholderTextColor: Settings.mutedFgColor
    selectByMouse: true
    background: Rectangle {
        color: "transparent"
        border.color: parent.activeFocus ? Settings.accent : Settings.mutedAccent
        border.width: 1
        radius: 8
    }
    onAccepted: {
        committed(text);
        focus = false;
    }
    onEditingFinished: {
        if (!activeFocus)
            committed(text);
    }
    onTextEdited: {
        if (commitOnType)
            committed(text);
    }
}

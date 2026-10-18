import QtQuick
import QtQuick.Layouts
import PeakShell

RowLayout {
    property string label: ""
    property string hint: ""
    default property alias control: slot.data
    Layout.fillWidth: true
    spacing: 12
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            Layout.fillWidth: true
            text: label
            color: Settings.fgColor
            font.pointSize: Settings.labelFontSize
            font.family: Settings.labelFontFamily
            elide: Text.ElideRight
        }
        Text {
            visible: hint.length > 0
            Layout.fillWidth: true
            text: hint
            color: Settings.mutedFgColor
            font.pointSize: Math.max(8, Settings.labelFontSize - 2)
            font.family: Settings.labelFontFamily
            wrapMode: Text.WordWrap
        }
    }
    Item {
        id: slot
        Layout.preferredWidth: 260
        Layout.alignment: Qt.AlignVCenter
        // childrenRect folds the control's laid-out geometry back into the
        // layout and loops (Qt logs "Binding loop detected for implicitHeight").
        // The control's own implicit height does not depend on this item.
        implicitHeight: slot.children.length > 0 ? slot.children[0].implicitHeight : 0
    }
}

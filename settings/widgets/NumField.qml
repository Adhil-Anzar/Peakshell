import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import PeakShell
import "root:/"

RowLayout {
    id: root
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property bool isInt: false
    signal edited(real v)
    spacing: 8
    opacity: enabled ? 1 : 0.45

    function fmt(v) {
        if (root.isInt)
            return Math.round(v).toString();
        return (Math.round(v * 10) / 10).toString();
    }
    function commit() {
        var v = parseFloat(field.text);
        if (isNaN(v) || v < root.from || v > root.to) {
            field.text = fmt(root.value);
            return;
        }
        if (root.isInt)
            v = Math.round(v);
        root.edited(v);
        field.text = fmt(v);
        field.focus = false;
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        from: root.from
        to: root.to
        stepSize: root.step
        value: root.value
        onMoved: root.edited(root.isInt ? Math.round(value) : value)
        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitHeight: 6
            width: slider.availableWidth
            height: implicitHeight
            radius: 3
            color: Settings.mutedBgColor
            Rectangle {
                width: parent.width * slider.visualPosition
                height: parent.height
                radius: 3
                color: Theme.accent
            }
        }
        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            implicitWidth: 14
            implicitHeight: 14
            radius: 7
            color: Theme.accent
            border.color: Settings.fgColor
            border.width: 1
        }
    }
    TextField {
        id: field
        Layout.preferredWidth: 76
        color: acceptableInput ? Settings.fgColor : Settings.dangerPulse
        font.pointSize: Settings.labelFontSize
        font.family: Settings.labelFontFamily
        horizontalAlignment: TextInput.AlignRight
        inputMethodHints: Qt.ImhDigitsOnly
        validator: root.isInt ? intValidator : dblValidator
        IntValidator {
            id: intValidator
            bottom: root.from
            top: root.to
        }
        DoubleValidator {
            id: dblValidator
            bottom: root.from
            top: root.to
            decimals: 1
            notation: DoubleValidator.StandardNotation
        }
        background: Rectangle {
            color: "transparent"
            border.color: field.activeFocus ? Theme.accent : Settings.mutedAccent
            border.width: 1
            radius: 8
        }
        Component.onCompleted: text = fmt(root.value)
        onAccepted: commit()
        onEditingFinished: {
            if (!activeFocus)
                commit();
        }
    }
    Connections {
        target: root
        function onValueChanged() {
            if (!field.activeFocus)
                field.text = root.fmt(root.value);
        }
    }
}

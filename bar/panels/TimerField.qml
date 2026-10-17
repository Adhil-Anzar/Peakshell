import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

ColumnLayout {
    id: field

    property string label: ""
    property int value: 0

    signal advanced()
    signal dismissed()

    readonly property int numberSize: Theme.labelFontSize * 3

    spacing: 2

    function setValue(v) {
        field.value = v;
        input.text = (v < 10 ? "0" : "") + v;
    }

    function focusInput() {
        input.forceActiveFocus();
        input.selectAll();
    }

    TextInput {
        id: input

        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: Math.ceil(field.numberSize * 1.5)
        horizontalAlignment: TextInput.AlignHCenter
        color: Theme.fgColor
        font.pointSize: field.numberSize
        font.family: Theme.labelFontFamily
        font.bold: true
        maximumLength: 2
        inputMethodHints: Qt.ImhDigitsOnly
        selectByMouse: true
        cursorVisible: activeFocus

        onTextEdited: {
            const digits = text.replace(/\D/g, "").slice(0, 2);
            if (digits !== text)
                text = digits;
            field.value = digits.length ? parseInt(digits, 10) : 0;
            if (digits.length === 2)
                field.advanced();
        }

        Keys.onEscapePressed: field.dismissed()
        Keys.onReturnPressed: field.dismissed()
        Keys.onEnterPressed: field.dismissed()
    }

    Text {
        Layout.alignment: Qt.AlignHCenter
        text: field.label
        color: Theme.mutedFgColor
        opacity: input.activeFocus ? 1 : 0
        font.pointSize: Theme.labelFontSize * 0.8
        font.family: Theme.labelFontFamily

        Behavior on opacity {
            Anim { type: Anim.DefaultEffects }
        }
    }
}

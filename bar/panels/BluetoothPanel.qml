import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: bluetoothPanel
    property real barOffset: 0
    property var panelHost
    //screen: panelHost ? panelHost.screen : null
    property bool isShiftDown: false

    function calculateHeight(itemCount, space) {
        if (itemCount > Theme.bluetoothItemMaxCount)
            return Theme.bluetoothItemSize * Theme.bluetoothItemMaxCount + Math.abs(space * (Theme.bluetoothItemMaxCount - 1));
        return Theme.bluetoothItemSize * itemCount + Math.abs(space * (itemCount - 1));
    }

    visible: false
    focusable: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    onVisibleChanged: {
        // Defer starting discovery so the open animation renders first.
        // Stopping still happens immediately.
        if (visible)
            Qt.callLater(() => BluetoothResolve.setDiscovering(true));
        else
            BluetoothResolve.setDiscovering(false);
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Dismiss on clicking outside
    MouseArea {
        anchors.fill: parent
        onClicked: bluetoothPanel.visible = false
    }

    FocusScope {
        anchors.fill: parent
        focus: bluetoothPanel.visible
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                bluetoothPanel.visible = false;
                event.accepted = true;
            }
            if (event.key === Qt.Key_Shift)
                bluetoothPanel.isShiftDown = true;
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Shift)
                bluetoothPanel.isShiftDown = false;
        }
        onActiveFocusChanged: {
            if (!activeFocus)
                bluetoothPanel.isShiftDown = false;
        }
    }

    Item {
        x: bluetoothPanel.barOffset + Theme.barHorizontalPad
        y: 0
        width: Theme.bluetoothPanelWidth
        height: bluetoothColumnContainer.height
        visible: bluetoothPanel.visible

        opacity: bluetoothPanel.visible ? 1 : 0
        scale: bluetoothPanel.visible ? 1 : 0.94
        transformOrigin: Item.TopLeft

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
        Behavior on scale {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Absorb clicks so they don't reach the dismiss area
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            id: bluetoothColumnContainer
            width: Theme.bluetoothPanelWidth
            spacing: 5
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredHeight: connectedBluetoothText.height + Theme.cornerRadius
                    Layout.preferredWidth: connectedBluetoothText.width + Theme.cornerLargeRadius
                    Layout.alignment: Qt.AlignCenter | Qt.AlignLeft
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    radius: Theme.cornerRadius
                    Row {
                        id: connectedBluetoothText
                        anchors.centerIn: parent
                        spacing: 8
                        ClickButton {
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.labelFontSize * 1.5
                            symbol: "go-previous"
                            bgColor: "transparent"
                            onPress: bluetoothPanel.visible = false
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Devices"
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            color: Theme.fgColor
                        }
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Rectangle {
                    Layout.preferredHeight: bluetoothSwitch.height + Theme.cornerRadius
                    Layout.preferredWidth: bluetoothSwitch.width + Theme.cornerLargeRadius
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    radius: Theme.cornerRadius

                    Switch {
                        id: bluetoothSwitch
                        padding: 0
                        rightPadding: Theme.cornerLargeRadius
                        focus: false
                        checked: BluetoothResolve.bluetoothEnabled
                        focusPolicy: Qt.NoFocus
                        anchors.centerIn: parent
                        onToggled: BluetoothResolve.setBluetooth(checked)
                        background: Item {
                            anchors.fill: parent
                            IconImage {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: Theme.iconFontSize
                                source: Quickshell.iconPath(BluetoothResolve.icon)
                            }
                        }
                        indicator: Rectangle {
                            implicitWidth: Theme.cornerRadius * 3
                            implicitHeight: Theme.cornerRadius * 1.5
                            radius: height / 2
                            color: bluetoothSwitch.checked ? Theme.accent : Theme.bgColor
                            border.color: Theme.mutedAccent
                            border.width: Theme.generalThickness / 2
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.animationDuration
                                }
                            }
                            Rectangle {
                                x: bluetoothSwitch.checked ? parent.width - width : 0
                                height: parent.height
                                width: height
                                radius: height / 2
                                color: Theme.bgColorFilled
                                scale: 1.25
                                border.color: Theme.mutedAccent
                                border.width: Theme.generalThickness
                                Behavior on x {
                                    NumberAnimation {
                                        duration: Theme.animationDuration
                                        easing.type: Easing.OutExpo
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                implicitHeight: bluetoothPanel.calculateHeight(BluetoothResolve.connectedDevices.length, spacing)
                visible: BluetoothResolve.connectedDevices.length !== 0
                model: BluetoothResolve.connectedDevices
                spacing: 2
                clip: true
                delegate: Rectangle {
                    width: Theme.bluetoothPanelWidth
                    height: Theme.bluetoothItemSize
                    radius: Theme.cornerRadius
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    RowLayout {
                        anchors.fill: parent
                        Item {
                            height: 1
                            width: Theme.cornerRadius
                        }
                        IconImage {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            implicitSize: Theme.bluetoothItemSize - Theme.cornerRadius
                            source: Quickshell.iconPath(modelData.icon)
                        }
                        Column {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            spacing: 2
                            Layout.fillWidth: true
                            Text {
                                text: modelData.name
                                color: Theme.fgColor
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.batteryAvailable ? modelData.address + " • " + Math.round(modelData.battery * 100) + "%" : modelData.address
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                            }
                        }
                        LabelButton {
                            label: {
                                if (modelData.pairing)
                                    return BluetoothDeviceState.toString(modelData.state);
                                return bluetoothPanel.isShiftDown ? "Forget" : "Disconnect";
                            }
                            onPress: {
                                if (bluetoothPanel.isShiftDown)
                                    BluetoothResolve.forget(modelData);
                                else
                                    BluetoothResolve.disconnect(modelData);
                            }
                        }
                        Item {
                            height: 1
                            width: Theme.cornerRadius
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: knownBluetoothTitle.width + Theme.cornerLargeRadius
                Layout.preferredHeight: visible ? knownBluetoothTitle.height + Theme.cornerRadius : 0
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                color: Theme.bgColor
                visible: BluetoothResolve.bondedDevices.length !== 0
                radius: Theme.cornerRadius
                border.color: Theme.mutedAccent
                border.width: Theme.generalThickness
                Text {
                    id: knownBluetoothTitle
                    anchors.centerIn: parent
                    text: "Known Devices"
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                    color: Theme.fgColor
                }
            }

            ListView {
                Layout.fillWidth: true
                implicitHeight: contentHeight
                visible: BluetoothResolve.bondedDevices.length !== 0
                model: BluetoothResolve.bondedDevices
                spacing: 2
                clip: true
                delegate: Rectangle {
                    width: Theme.bluetoothPanelWidth
                    height: Theme.bluetoothItemSize
                    radius: Theme.cornerRadius
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    RowLayout {
                        anchors.fill: parent
                        Item {
                            height: 1
                            width: Theme.cornerRadius
                        }
                        IconImage {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            implicitSize: Theme.bluetoothItemSize - Theme.cornerRadius
                            source: Quickshell.iconPath(modelData.icon)
                        }
                        Column {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            spacing: 2
                            Layout.fillWidth: true
                            Text {
                                text: modelData.name
                                width: parent.width
                                color: Theme.fgColor
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.address
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                            }
                        }
                        LabelButton {
                            enabled: modelData.state !== BluetoothDeviceState.Connecting
                            label: {
                                if (modelData.state === BluetoothDeviceState.Connecting)
                                    return "Pairing";
                                return bluetoothPanel.isShiftDown ? "Forget" : "Connect";
                            }
                            onPress: {
                                if (bluetoothPanel.isShiftDown)
                                    BluetoothResolve.forget(modelData);
                                else
                                    BluetoothResolve.connect(modelData);
                            }
                        }
                        Item {
                            height: 1
                            width: Theme.cornerRadius
                        }
                    }
                }
            }

            RowLayout {
                Layout.preferredWidth: Theme.bluetoothPanelWidth
                Layout.preferredHeight: visible ? unknownBluetoothTitle.height + Theme.cornerRadius : 0
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                visible: BluetoothResolve.otherDevices.length !== 0
                Rectangle {
                    Layout.preferredWidth: unknownBluetoothTitle.width + Theme.cornerLargeRadius
                    Layout.preferredHeight: unknownBluetoothTitle.height + Theme.cornerRadius
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    color: Theme.bgColor
                    radius: Theme.cornerRadius
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    Text {
                        id: unknownBluetoothTitle
                        anchors.centerIn: parent
                        text: "Available Devices"
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        color: Theme.fgColor
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                Rectangle {
                    Layout.preferredWidth: unknownBluetoothNumber.width + Theme.cornerLargeRadius
                    Layout.preferredHeight: unknownBluetoothNumber.height + Theme.cornerRadius
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    color: Theme.bgColor
                    radius: Theme.cornerRadius
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    Text {
                        id: unknownBluetoothNumber
                        anchors.centerIn: parent
                        text: BluetoothResolve.otherDevices.length
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        color: Theme.fgColor
                    }
                }
            }

            ListView {
                id: unknownBluetoothList
                Layout.fillWidth: true
                implicitHeight: bluetoothPanel.calculateHeight(BluetoothResolve.otherDevices.length, spacing)
                visible: BluetoothResolve.otherDevices.length !== 0
                model: BluetoothResolve.otherDevices
                spacing: 2
                clip: true
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    width: unknownBluetoothList.width
                    height: Theme.bluetoothItemSize
                    radius: Theme.cornerRadius
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    RowLayout {
                        ListView.delayRemove: true
                        anchors.fill: parent
                        Item {
                            height: 1
                            width: Theme.cornerRadius
                        }
                        IconImage {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            implicitSize: Theme.bluetoothItemSize - Theme.cornerRadius
                            source: Quickshell.iconPath(modelData.icon)
                        }
                        Column {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            spacing: 2
                            Layout.fillWidth: true
                            Text {
                                text: modelData.name
                                color: Theme.fgColor
                                font.pointSize: Theme.labelFontSize
                                font.family: Theme.labelFontFamily
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.address
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                            }
                        }
                        LabelButton {
                            enabled: modelData.state !== BluetoothDeviceState.Connecting
                            label: modelData.state === BluetoothDeviceState.Connecting ? "Pairing" : "Connect"
                            onPress: BluetoothResolve.pair(modelData)
                        }
                        Item {
                            height: 1
                            width: Theme.cornerRadius
                        }
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Widgets
import "root:/"
import "root:/components"
import "root:/services"

PanelWindow {
    id: wifiPanel
    property real barOffset: 0
    property var panelHost
    property bool isShiftDown: false

    function calculateHeight(itemCount, space) {
        if (itemCount > Theme.wifiItemMaxCount)
            return Theme.wifiItemSize * Theme.wifiItemMaxCount + Math.abs(space * (Theme.wifiItemMaxCount - 1))
        return Theme.wifiItemSize * itemCount + Math.abs(space * (itemCount - 1))
    }

    visible: false
    focusable: true
    color: "transparent"
    implicitWidth: visible ? Theme.wifiPanelWidth + Theme.barHorizontalPad + barOffset : 0
    implicitHeight: wifiColumnContainer.height
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    onVisibleChanged: INetwork.setScan(visible)

    anchors {
        top: true
        bottom: false
        left: true
        right: false
    }

    FocusScope {
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                wifiPanel.visible = false
                event.accepted = true
            }
            if (event.key === Qt.Key_Shift)
                wifiPanel.isShiftDown = true
        }
        Keys.onReleased: (event) => {
            if (event.key === Qt.Key_Shift)
                wifiPanel.isShiftDown = false
        }
        onActiveFocusChanged: {
            if (!activeFocus)
                wifiPanel.isShiftDown = false
        }
    }

    Item {
        x: visible ? wifiPanel.barOffset : 0
        visible: wifiPanel.visible
        width: Theme.wifiPanelWidth
        ColumnLayout {
            id: wifiColumnContainer
            width: Theme.wifiPanelWidth
            visible: wifiPanel.visible
            spacing: visible ? 5 : 30
            Behavior on spacing {
                NumberAnimation {
                    duration: Theme.animationDuration
                    easing.type: Easing.OutExpo
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.preferredHeight: connectedWifiText.height + Theme.cornerRadius
                    Layout.preferredWidth: connectedWifiText.width + Theme.cornerLargeRadius
                    Layout.alignment: Qt.AlignCenter | Qt.AlignLeft
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    radius: Theme.cornerRadius
                    Row {
                        id: connectedWifiText
                        anchors.centerIn: parent
                        spacing: 8
                        ClickButton {
                            anchors.verticalCenter: parent.verticalCenter
                            size: Theme.labelFontSize * 1.5
                            symbol: "go-previous"
                            bgColor: "transparent"
                            onPress: wifiPanel.visible = false
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Networks"
                            font.pointSize: Theme.labelFontSize
                            font.family: Theme.labelFontFamily
                            color: Theme.fgColor
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredHeight: wifiSwitch.height + Theme.cornerRadius
                    Layout.preferredWidth: wifiSwitch.width + Theme.cornerLargeRadius
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    radius: Theme.cornerRadius

                    Switch {
                        id: wifiSwitch
                        padding: 0
                        rightPadding: Theme.cornerLargeRadius
                        focus: false
                        checked: Networking.wifiEnabled
                        focusPolicy: Qt.NoFocus
                        anchors.centerIn: parent
                        onToggled: INetwork.setWifi(checked)
                        background: Item {
                            anchors.fill: parent
                            IconImage {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: Theme.iconFontSize
                                source: Quickshell.iconPath(wifiSwitch.checked ? INetwork.getStrengthOnlyIcon(INetwork.connectedWifiNetwork) : "network-wireless-off")
                            }
                        }
                        indicator: Rectangle {
                            implicitWidth: Theme.cornerRadius * 3
                            implicitHeight: Theme.cornerRadius * 1.5
                            radius: height / 2
                            color: wifiSwitch.checked ? Theme.accent : Theme.bgColor
                            border.color: Theme.mutedAccent
                            border.width: Theme.generalThickness / 2
                            Behavior on color {
                                ColorAnimation { duration: Theme.animationDuration }
                            }
                            Rectangle {
                                x: wifiSwitch.checked ? parent.width - width : 0
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
                implicitHeight: wifiPanel.calculateHeight(INetwork.connectedNetworks.length, spacing)
                visible: INetwork.connectedNetworks.length !== 0
                model: INetwork.connectedNetworks
                spacing: 2
                clip: true
                delegate: Rectangle {
                    width: Theme.wifiPanelWidth
                    height: Theme.wifiItemSize
                    radius: Theme.cornerRadius
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    RowLayout {
                        anchors.fill: parent
                        Item { height: 1; width: Theme.cornerRadius }
                        IconImage {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            implicitSize: Theme.wifiItemSize
                            source: Quickshell.iconPath(INetwork.getStrengthOnlyIcon(modelData))
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
                                text: WifiSecurityType.toString(modelData.security) + " • " + Math.round(modelData.signalStrength * 100) + "%"
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                            }
                        }
                        LabelButton {
                            label: {
                                if (modelData.stateChanging)
                                    return ConnectionState.toString(modelData.state)
                                return wifiPanel.isShiftDown ? "Forget" : "Disconnect"
                            }
                            onPress: {
                                if (wifiPanel.isShiftDown)
                                    INetwork.forgetWifi(modelData)
                                else
                                    INetwork.disconnect(modelData)
                            }
                        }
                        Item { height: 1; width: Theme.cornerRadius }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: knownNetworksTitle.width + Theme.cornerLargeRadius
                Layout.preferredHeight: visible ? knownNetworksTitle.height + Theme.cornerRadius : 0
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                color: Theme.bgColor
                visible: INetwork.knownLocalWifies.length !== 0
                radius: Theme.cornerRadius
                border.color: Theme.mutedAccent
                border.width: Theme.generalThickness
                Text {
                    id: knownNetworksTitle
                    anchors.centerIn: parent
                    text: "Saved Networks"
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                    color: Theme.fgColor
                }
            }

            ListView {
                Layout.fillWidth: true
                implicitHeight: contentHeight
                visible: INetwork.knownLocalWifies.length !== 0
                model: INetwork.knownLocalWifies
                spacing: 2
                clip: true
                delegate: Rectangle {
                    width: Theme.wifiPanelWidth
                    height: Theme.wifiItemSize
                    radius: Theme.cornerRadius
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    RowLayout {
                        anchors.fill: parent
                        Item { height: 1; width: Theme.cornerRadius }
                        IconImage {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            implicitSize: Theme.wifiItemSize
                            source: Quickshell.iconPath(INetwork.getStrengthOnlyIcon(modelData))
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
                                text: WifiSecurityType.toString(modelData.security) + " • " + Math.round(modelData.signalStrength * 100) + "%"
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                            }
                        }
                        LabelButton {
                            enabled: !modelData.stateChanging
                            label: {
                                if (modelData.stateChanging)
                                    return ConnectionState.toString(modelData.state)
                                return wifiPanel.isShiftDown ? "Forget" : "Join"
                            }
                            onPress: {
                                if (wifiPanel.isShiftDown)
                                    INetwork.forgetWifi(modelData)
                                else
                                    INetwork.connectKnownWifi(modelData)
                            }
                        }
                        Item { height: 1; width: Theme.cornerRadius }
                    }
                }
            }

            RowLayout {
                Layout.preferredWidth: Theme.wifiPanelWidth
                Layout.preferredHeight: visible ? unknownNetworksTitle.height + Theme.cornerRadius : 0
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                visible: INetwork.unknownLocalWifies.length !== 0
                Rectangle {
                    Layout.preferredWidth: unknownNetworksTitle.width + Theme.cornerLargeRadius
                    Layout.preferredHeight: unknownNetworksTitle.height + Theme.cornerRadius
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                    color: Theme.bgColor
                    radius: Theme.cornerRadius
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    Text {
                        id: unknownNetworksTitle
                        anchors.centerIn: parent
                        text: "Available Networks"
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        color: Theme.fgColor
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: unknownNetworksNumber.width + Theme.cornerLargeRadius
                    Layout.preferredHeight: unknownNetworksNumber.height + Theme.cornerRadius
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    color: Theme.bgColor
                    radius: Theme.cornerRadius
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    Text {
                        id: unknownNetworksNumber
                        anchors.centerIn: parent
                        text: INetwork.unknownLocalWifies.length
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        color: Theme.fgColor
                    }
                }
            }

            ListView {
                id: unknownNetworkList
                Layout.fillWidth: true
                implicitHeight: wifiPanel.calculateHeight(INetwork.unknownLocalWifies.length, spacing)
                visible: INetwork.unknownLocalWifies.length !== 0
                model: INetwork.unknownLocalWifies
                spacing: 2
                clip: true
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    width: unknownNetworkList.width
                    height: Theme.wifiItemSize
                    radius: Theme.cornerRadius
                    color: Theme.bgColor
                    border.color: Theme.mutedAccent
                    border.width: Theme.generalThickness
                    RowLayout {
                        ListView.delayRemove: true
                        anchors.fill: parent
                        Item { height: 1; width: Theme.cornerRadius }
                        IconImage {
                            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                            implicitSize: Theme.wifiItemSize
                            source: Quickshell.iconPath(INetwork.getStrengthOnlyIcon(modelData))
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
                                text: WifiSecurityType.toString(modelData.security) + " • " + Math.round(modelData.signalStrength * 100) + "%"
                                color: Theme.mutedFgColor
                                font.pointSize: Theme.labelFontSize * 0.8
                                font.family: Theme.labelFontFamily
                            }
                        }
                        LabelButton {
                            enabled: !modelData.stateChanging
                            label: modelData.stateChanging ? ConnectionState.toString(modelData.state) : "Connect"
                            onPress: INetwork.connectUnknownWifi(modelData)
                        }
                        Item { height: 1; width: Theme.cornerRadius }
                    }
                }
            }
        }
    }
}

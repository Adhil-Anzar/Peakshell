import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import "root:/"

Rectangle {
    function toggleWifiPanel() {
        wifiPanel.visible = !wifiPanel.visible;
        wifiHoverDebounce.isDelaying = true;
        wifiHoverDebounce.restart();
    }

    // Transitions
    width: container.width + 32
    Behavior on width {
        NumberAnimation {
            duration: Theme.animationDuration
            easing.type: Easing.OutExpo
        }
    }
    // Styling
    color: Theme.bgColor
    border.color: Theme.accent
    border.width: Theme.generalThickness
    radius: Theme.cornerRadius
    implicitHeight: Theme.barHeight
    // Icon / Label Text
    Row {
        id: container
        anchors.centerIn: parent
        spacing: 5
        Rectangle {
            height: Theme.barHeight - (Theme.generalThickness * 2)
            width:  notificationHoverDebounce.isDelaying ? notificationContainer.width + 32 :  notificationContainer.width + 16
            radius: Theme.cornerRadius
            color: notificationMouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"
            Behavior on color {
                ColorAnimation {
                duration: Theme.animationDuration
                }
            }
            MouseArea {
                id: notificationMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onEntered: { notificationHoverDebounce.isDelaying = true; notificationHoverDebounce.restart() }
                onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                        Swaync.toggleDnd();
                    }
                    if (mouse.button === Qt.LeftButton){
                        Swaync.togglePanel();
                    }
                }
            }
            Timer {
                id: notificationHoverDebounce
                property bool isDelaying: false
                interval: Theme.hoverDuration
                repeat: false
                running: !notificationMouseArea.containsMouse && isDelaying

                onTriggered: isDelaying = false;
            }

            Row {
                anchors.centerIn: parent
                id: notificationContainer
                spacing: 5
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.iconFontSize
                    source: Quickshell.iconPath(getIcon())
                    function getIcon() {
                        if (Swaync.isDndOn) return "notification-disabled";
                        if (Swaync.notificationCount === 0) return "notification-inactive";
                        return "notification-active"
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: notificationHoverDebounce.isDelaying
                    text: Swaync.notificationCount === 0 ? "" : Swaync.notificationCount + " Notifications"
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                    color: Theme.fgColor
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
                }
            }
        }
        Rectangle {
            height: Theme.barHeight -  (Theme.generalThickness * 2)
            width: wifiHoverDebounce.isDelaying ? wifiContainer.width + 32 : wifiContainer.width + 16
            radius: Theme.cornerRadius
            color: wifiMouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"

            MouseArea {
                id: wifiMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onEntered: { wifiHoverDebounce.isDelaying = true; wifiHoverDebounce.restart() }
                onClicked: function(mouse) {
                    if (mouse.button === Qt.LeftButton) {
                        toggleWifiPanel();
                    }
                }
            }

            Timer {
                id: wifiHoverDebounce
                property bool isDelaying: false
                interval: Theme.hoverDuration
                repeat: false
                running: !notificationMouseArea.containsMouse && isDelaying

                onTriggered: isDelaying = false;
            }
            Behavior on color {
                ColorAnimation {
                duration: Theme.animationDuration
                }
            }
            Row {
                anchors.centerIn: parent
                id: wifiContainer
                spacing: 5
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.iconFontSize
                    source: Quickshell.iconPath(INetwork.networkStrengthIcon)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: wifiHoverDebounce.isDelaying
                    text: INetwork.connectionMessage // sdsd
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                    color: Theme.fgColor
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
                }
            }
        }
        Rectangle {
            height: Theme.barHeight -  (Theme.generalThickness * 2)
            width: bluetoothHoverDebounce.isDelaying ? bluetoothContainer.width + 32 : bluetoothContainer.width + 16
            radius: Theme.cornerRadius
            color: bluetoothMouseArea.containsMouse ? Theme.hoveredBgColor : "transparent"

            MouseArea {
                id: bluetoothMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { bluetoothHoverDebounce.isDelaying = true; bluetoothHoverDebounce.restart() }
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
            }
            Timer {
                id: bluetoothHoverDebounce
                property bool isDelaying: false
                interval: Theme.hoverDuration
                repeat: false
                running: !notificationMouseArea.containsMouse && isDelaying

                onTriggered: isDelaying = false;
            }
            Behavior on color {
                ColorAnimation {
                duration: Theme.animationDuration
                }
            }
            Row {
                anchors.centerIn: parent
                id: bluetoothContainer
                spacing: 5
                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.iconFontSize
                    source: Quickshell.iconPath("bluetooth-active")
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: bluetoothHoverDebounce.isDelaying
                    text: "Airpods Pro 2"
                    font.pointSize: Theme.labelFontSize
                    font.family: Theme.labelFontFamily
                    color: Theme.fgColor
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.animationDuration } }
                }
            }
        }
        // Wifi Panel
        PanelWindow {
            id: wifiPanel
            property bool isShiftDown: false
            function getSpacingDistance() { return container.mapToGlobal(0, 0).x ; }
            function calculateHeight(itemCount, space) {
                if (itemCount > Theme.wifiItemMaxCount) return Theme.wifiItemSize * Theme.wifiItemMaxCount + Math.abs(space * (Theme.wifiItemMaxCount - 1))
                return Theme.wifiItemSize * itemCount + Math.abs(space * (itemCount - 1))
            }
            visible: false
            focusable: true
            color: "transparent"
            implicitWidth: visible ? Theme.wifiPanelWidth + Theme.barHorizontalPad + getSpacingDistance() : 0
            implicitHeight: wifiColumnContainer.height
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            //exclusionMode: ExclusionMode.Ignore

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
                    if (event.key === Qt.Key_Shift) wifiPanel.isShiftDown = true;
                }
                Keys.onReleased: (event) => {
                    if (event.key === Qt.Key_Shift) wifiPanel.isShiftDown = false;
                }
                onActiveFocusChanged: {
                    if (!activeFocus) wifiPanel.isShiftDown = false;
                }
            }
            Item {
                x: visible ? wifiPanel.getSpacingDistance() : 0
                visible: wifiPanel.visible
                //implicitHeight: Theme.wifiPanelHeight
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
                                    onPress: {
                                        wifiPanel.visible = false
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: `Networks`
                                    font.pointSize: Theme.labelFontSize
                                    font.family: Theme.labelFontFamily
                                    color: Theme.fgColor
                                }
                            }
                        }
                        Item { Layout.fillWidth: true; }
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
                                anchors.margins: 0
                                //icon.source: Quickshell.iconPath((checked ? "network-wireless-on" : "network-wireless-off"))
                                onToggled: {
                                    INetwork.setWifi(checked);
                                    if (checked) wifiSwitchThumb.state = "on"
                                    else wifiSwitchThumb.state = "off"
                                }
                                background: Item {
                                    anchors.fill: parent
                                    IconImage {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitSize: Theme.iconFontSize
                                        source: Quickshell.iconPath((wifiSwitch.checked ? INetwork.getStrengthOnlyIcon(INetwork.connectedWifiNetwork) : "network-wireless-off"))
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
                                        ColorAnimation {
                                            duration: Theme.animationDuration
                                        }
                                    }

                                    Rectangle {
                                        id: wifiSwitchThumb
                                        x: wifiSwitch.checked ? parent.width - this.width : 0
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
                        id: connectedNetworkList
                        Layout.fillWidth: true
                        implicitHeight: wifiPanel.calculateHeight(INetwork.connectedNetworks.length, spacing)
                        visible: INetwork.connectedNetworks.length !== 0
                        model: INetwork.connectedNetworks
                        spacing: 2
                        clip: true
                        Behavior on height {
                            NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo; }
                        }
                        addDisplaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo }
                        }
                        removeDisplaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo  }
                        }
                        populate: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo }
                        }
                        delegate: Rectangle {
                            width: Theme.wifiPanelWidth
                            height: Theme.wifiItemSize
                            radius: Theme.cornerRadius
                            color: Theme.bgColor
                            border.color: Theme.mutedAccent
                            border.width: Theme.generalThickness
                            MouseArea {
                                id: connectedNetworkItemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                            }

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
                                    Text {
                                        text: modelData.name
                                        color: Theme.fgColor
                                        font.pointSize: Theme.labelFontSize
                                        font.family: Theme.labelFontFamily
                                        wrapMode: Text.WrapAnywhere
                                    }
                                    Text {
                                        text: WifiSecurityType.toString(modelData.security) + " • " + Math.round(modelData.signalStrength * 100) + "%"
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.8
                                        font.family: Theme.labelFontFamily
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                LabelButton {
                                    label: {
                                        if (modelData.stateChanging) return ConnectionState.toString(modelData.state);
                                        if (wifiPanel.isShiftDown) return "Forget";
                                        else return "Disconnect";
                                    }
                                    onPress: {
                                        if (wifiPanel.isShiftDown) {
                                            // Forget
                                            INetwork.forgetWifi(modelData)
                                        }
                                        else {
                                            // Disconnect
                                            INetwork.disconnect(modelData);

                                        }
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

                        Behavior on height {
                            NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo; }
                        }
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
                        id: knownNetworkList
                        Layout.fillWidth: true
                        implicitHeight: contentHeight
                        visible: INetwork.knownLocalWifies.length !== 0
                        model: INetwork.knownLocalWifies
                        spacing: 2
                        clip: true
                        Behavior on height {
                            NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo; }
                        }
                        addDisplaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo }
                        }
                        removeDisplaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo  }
                        }
                        populate: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo }
                        }
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
                                    Text {
                                        text: modelData.name
                                        color: Theme.fgColor
                                        font.pointSize: Theme.labelFontSize
                                        font.family: Theme.labelFontFamily
                                        wrapMode: Text.WrapAnywhere
                                    }
                                    Text {
                                        text: WifiSecurityType.toString(modelData.security) + " • " + Math.round(modelData.signalStrength * 100) + "%"
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.8
                                        font.family: Theme.labelFontFamily
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                LabelButton {
                                    enabled: !modelData.stateChanging
                                    label: {
                                        if (modelData.stateChanging) return ConnectionState.toString(modelData.state);
                                        if (wifiPanel.isShiftDown) return "Forget";
                                        else return "Join";
                                    }
                                    onPress: {
                                        if (wifiPanel.isShiftDown) {
                                            // Forget
                                            INetwork.forgetWifi(modelData)
                                        }
                                        else {
                                            // Connect
                                            INetwork.connectKnownWifi(modelData);

                                        }
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

                        Behavior on height {
                            NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo; }
                        }
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

                        Behavior on height {
                            NumberAnimation { duration: Theme.animationDuration; easing.type: Easing.OutExpo; }
                        }
                        addDisplaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo }
                        }
                        removeDisplaced: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo  }
                        }
                        populate: Transition {
                            NumberAnimation { properties: "x,y"; duration: Theme.animationDuration; easing.type: Easing.OutExpo }
                        }
                        ScrollBar.vertical: ScrollBar { }

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
                                    Text {
                                        text: modelData.name
                                        color: Theme.fgColor
                                        font.pointSize: Theme.labelFontSize
                                        font.family: Theme.labelFontFamily
                                        wrapMode: Text.WrapAnywhere
                                    }
                                    Text {
                                        text: WifiSecurityType.toString(modelData.security) + " • " + Math.round(modelData.signalStrength * 100) + "%"
                                        color: Theme.mutedFgColor
                                        font.pointSize: Theme.labelFontSize * 0.8
                                        font.family: Theme.labelFontFamily
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                LabelButton {
                                    enabled: !modelData.stateChanging
                                    label: {
                                        if (modelData.stateChanging) return ConnectionState.toString(modelData.state);
                                        else return "Connect";
                                    }
                                    onPress: INetwork.connectUnknownWifi(modelData);
                                }
                                Item { height: 1; width: Theme.cornerRadius }
                            }

                        }
                    }
                }

            }

        }
    }
}

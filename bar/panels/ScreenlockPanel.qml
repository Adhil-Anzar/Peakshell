import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Widgets
import Quickshell.Io
import "root:/"
import "root:/components"
import "root:/services"

Scope {
    id: lockScope
    readonly property string username: Quickshell.env("USER") || "User"

    property string authError: ""
    property bool authenticating: false
    property string pendingPassword: ""

    // "clock" mirrors the SDDM lock screen, "login" mirrors its login screen.
    property string page: "clock"
    property bool capsLockOn: false
    property bool powerMenuOpen: false
    property int powerIndex: 0

    // Tracks the surface that received input so failure/regain focus only
    // affects the monitor the user is actually interacting with.
    property string activeScreen: ""

    // Power actions shown in the session menu. Logout is replaced by Switch
    // User, matching the requested SDDM-style ordering.
    readonly property var powerActions: {
        const switchAction = Power.powerActions.find(action => action.id === "switch");
        const otherActions = Power.powerActions.filter(action => action.id !== "logout" && action.id !== "switch");
        return switchAction ? [switchAction].concat(otherActions) : otherActions;
    }

    // Emitted from the outer scope so the lock surface can react to events
    // triggered by PamContext. Ids declared inside WlSessionLockSurface are
    // not visible here.
    signal shakeRequested
    signal unlockingRequested

    function lock() {
        sessionLock.locked = true;
    }

    function failAuthentication(message) {
        if (pam.active)
            pam.abort();
        authenticating = false;
        pendingPassword = "";
        authError = message;
        shakeRequested();
    }

    IpcHandler {
        target: "lock"

        function lock() {
            sessionLock.locked = true;
        }
    }

    PamContext {
        id: pam
        config: "login"

        onCompleted: result => {
            authTimeout.stop();
            lockScope.authenticating = false;
            lockScope.pendingPassword = "";
            if (result === PamResult.Success) {
                lockScope.authError = "";
                // Clear focus while the surface is still mapped, then unlock.
                lockScope.unlockingRequested();
                sessionLock.locked = false;
            } else {
                if (lockScope.authError === "")
                    lockScope.authError = "Authentication failed.";
                lockScope.shakeRequested();
            }
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            if (lockScope.pendingPassword !== "") {
                respond(lockScope.pendingPassword);
                lockScope.pendingPassword = "";
            } else {
                // Never leave PAM waiting for a response we cannot provide.
                lockScope.failAuthentication("Authentication failed.");
            }
        }

        onError: err => {
            // onCompleted(Error) is emitted right after this and handles the
            // state reset, so only set the more specific message here.
            lockScope.authError = "PAM session error.";
        }
    }

    Timer {
        id: authTimeout
        interval: 15000
        repeat: false
        onTriggered: {
            if (lockScope.authenticating)
                lockScope.failAuthentication("Authentication timed out.");
        }
    }

    function verifyPassword(password) {
        if (password.length === 0 || authenticating)
            return;
        authenticating = true;
        authError = "";
        pendingPassword = password;

        if (pam.active) {
            pam.abort();
        }
        if (!pam.start()) {
            failAuthentication("Unable to start authentication.");
            return;
        }
        authTimeout.restart();
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockWindow

            readonly property bool loginPage: lockScope.page === "login"
            readonly property real pageMargin: Math.max(48, height * 0.10)
            readonly property real menuMargin: Math.max(24, height * 0.045)
            readonly property string screenName: screen ? screen.name : ""

            property bool mouseActive: false

            color: "black"

            function enterLogin() {
                if (lockScope.authenticating)
                    return;
                lockScope.activeScreen = lockWindow.screenName;
                lockScope.page = "login";
                pwdInput.forceActiveFocus();
                Qt.callLater(() => {
                    if (lockScope.page === "login" && !lockScope.powerMenuOpen && lockScope.activeScreen === lockWindow.screenName)
                        pwdInput.forceActiveFocus();
                });
            }

            function leaveLogin() {
                if (lockScope.authenticating)
                    return;
                lockScope.page = "clock";
                lockScope.authError = "";
                lockScope.capsLockOn = false;
                pwdInput.text = "";
                screenRoot.forceActiveFocus();
            }

            function openPowerMenu() {
                if (lockScope.authenticating)
                    return;
                lockScope.activeScreen = lockWindow.screenName;
                lockScope.powerIndex = 0;
                lockScope.powerMenuOpen = true;
                pwdInput.focus = false;
                screenRoot.forceActiveFocus();
            }

            function closePowerMenu() {
                if (!lockScope.powerMenuOpen)
                    return;
                lockScope.powerMenuOpen = false;
                if (lockScope.activeScreen === lockWindow.screenName && lockScope.page === "login")
                    pwdInput.forceActiveFocus();
                Qt.callLater(() => {
                    if (lockScope.activeScreen === lockWindow.screenName && lockScope.page === "login" && !lockScope.powerMenuOpen)
                        pwdInput.forceActiveFocus();
                });
            }

            function movePowerSelection(delta) {
                const count = lockScope.powerActions.length;
                if (count === 0)
                    return;
                lockScope.powerIndex = (lockScope.powerIndex + delta + count) % count;
            }

            function triggerPower(action) {
                if (!action)
                    return;
                closePowerMenu();
                Power.execute(action.id);
            }

            onVisibleChanged: {
                if (visible) {
                    lockScope.activeScreen = lockWindow.screenName;
                    lockScope.page = "clock";
                    lockScope.authError = "";
                    lockScope.authenticating = false;
                    lockScope.capsLockOn = false;
                    lockScope.powerMenuOpen = false;
                    lockScope.powerIndex = 0;
                    lockWindow.mouseActive = false;
                    mouseIdleTimer.stop();
                    pwdInput.text = "";
                    screenRoot.forceActiveFocus();
                } else {
                    mouseIdleTimer.stop();
                    lockScope.powerMenuOpen = false;
                }
            }

            Connections {
                target: lockScope

                function onShakeRequested() {
                    shakeAnim.restart();
                    pwdInput.text = "";
                    pwdInput.forceActiveFocus();
                    Qt.callLater(() => {
                        if (lockScope.activeScreen === lockWindow.screenName && lockScope.page === "login" && !lockScope.powerMenuOpen)
                            pwdInput.forceActiveFocus();
                    });
                }

                function onUnlockingRequested() {
                    // Drop text-input focus while the surface is still mapped
                    // so the Wayland text-input protocol disables cleanly.
                    pwdInput.text = "";
                    pwdInput.focus = false;
                }
            }

            LockScreenBackground {
                anchors.fill: parent
                // Password entry (including the authentication spinner) gets
                // an extra blur + dim for readability.
                blurMax: (pwdInput.activeFocus || lockScope.authenticating) ? 36 : (powerButton.activeFocus ? 36 : 0)
                brightness: lockWindow.loginPage ? -0.05 : 0
                saturation: 0
                overlayOpacity: (pwdInput.activeFocus || lockScope.authenticating) ? 0.55 : (powerButton.activeFocus ? 0.38 : 0.28)
            }

            Timer {
                id: mouseIdleTimer
                interval: 5000
                repeat: false
                onTriggered: lockWindow.mouseActive = false
            }

            FocusScope {
                id: screenRoot

                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    if (lockScope.powerMenuOpen) {
                        if (event.key === Qt.Key_Escape) {
                            lockWindow.closePowerMenu();
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                            lockWindow.movePowerSelection(-1);
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                            lockWindow.movePowerSelection(1);
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            lockWindow.triggerPower(lockScope.powerActions[lockScope.powerIndex]);
                        }
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_CapsLock) {
                        lockScope.capsLockOn = !lockScope.capsLockOn;
                        if (lockScope.page === "clock")
                            lockWindow.enterLogin();
                        event.accepted = true;
                        return;
                    }

                    if (lockScope.page === "clock") {
                        if (event.key === Qt.Key_Escape) {
                            event.accepted = true;
                            return;
                        }
                        lockWindow.enterLogin();
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Escape) {
                        if (!lockScope.authenticating)
                            lockWindow.leaveLogin();
                        event.accepted = true;
                    }
                }

                // Clicking the blurred clock screen is equivalent to pressing
                // a key in the SDDM theme. On the login page it only restores
                // focus to the password field.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: lockScope.page === "clock" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPositionChanged: {
                        lockWindow.mouseActive = true;
                        mouseIdleTimer.restart();
                    }
                    onClicked: {
                        lockScope.activeScreen = lockWindow.screenName;
                        if (lockScope.page === "clock")
                            lockWindow.enterLogin();
                        else if (lockScope.powerMenuOpen)
                            lockWindow.closePowerMenu();
                        else
                            pwdInput.forceActiveFocus();
                    }
                }

                // ---------------------------------------------------------
                // Lock state: clock, date, and the "press any key" hint.
                // ---------------------------------------------------------
                Column {
                    id: clockColumn

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: lockWindow.pageMargin
                    spacing: -6

                    opacity: lockWindow.loginPage ? 0 : 1
                    visible: !lockWindow.loginPage || opacity > 0.001

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(Time.date, "hh:mm AP")
                        color: Theme.fgColor
                        font.family: Theme.labelFontFamily
                        font.pixelSize: Math.max(48, Math.min(96, lockWindow.height * 0.065))
                        font.weight: Font.Black
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(Time.date, "dddd, MMMM dd, yyyy")
                        color: Theme.mutedFgColor
                        font.family: Theme.labelFontFamily
                        font.pixelSize: Math.max(12, Math.min(18, lockWindow.height * 0.013))
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    id: lockHint

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: lockWindow.pageMargin
                    spacing: 8

                    opacity: (!lockWindow.loginPage && lockWindow.mouseActive) ? 1 : 0
                    visible: (!lockWindow.loginPage && lockWindow.mouseActive) || opacity > 0.001

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    Item {
                        width: 18
                        height: 18
                        anchors.verticalCenter: parent.verticalCenter

                        IconImage {
                            anchors.fill: parent
                            source: Quickshell.iconPath("input-keyboard")
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                brightness: 1.0
                                colorizationColor: Theme.mutedFgColor
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Press any key"
                        color: Theme.mutedFgColor
                        font.family: Theme.labelFontFamily
                        font.pointSize: Theme.labelFontSize
                    }
                }

                // ---------------------------------------------------------
                // Login state: avatar, username, password and status.
                // ---------------------------------------------------------
                ColumnLayout {
                    id: loginContainer

                    anchors.centerIn: parent
                    spacing: 10

                    opacity: lockWindow.loginPage ? 1 : 0
                    scale: lockWindow.loginPage ? 1 : 0.5
                    visible: lockWindow.loginPage || opacity > 0.001
                    enabled: lockWindow.loginPage

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    UserIcon {
                        Layout.alignment: Qt.AlignHCenter
                        size: 120
                        username: lockScope.username
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: lockScope.username
                        color: Theme.fgColor
                        font.family: Theme.labelFontFamily
                        font.pointSize: Theme.labelFontSize * 1.35
                        font.bold: true
                    }

                    RowLayout {
                        id: passwordRow

                        Layout.alignment: Qt.AlignHCenter
                        spacing: 5
                        visible: !lockScope.authenticating

                        transform: Translate {
                            id: shakeOffset
                        }

                        Rectangle {
                            id: passwordFrame

                            Layout.preferredWidth: 300
                            Layout.preferredHeight: 44
                            radius: Theme.cornerRadius

                            color: pwdInput.activeFocus ? Theme.hoveredBgColor : Theme.mutedBgColor
                            border.width: Theme.generalThickness
                            border.color: {
                                if (lockScope.authError !== "")
                                    return Theme.dangerPulse;
                                if (pwdInput.activeFocus)
                                    return Theme.accent;
                                return Theme.mutedAccent;
                            }

                            Behavior on color {
                                CAnim {}
                            }
                            Behavior on border.color {
                                CAnim {}
                            }

                            Item {
                                anchors.fill: parent

                                IconImage {
                                    id: passwordIcon

                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 18
                                    source: Quickshell.iconPath("dialog-password", "system-lock-screen")
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        colorization: 1.0
                                        brightness: 1.0
                                        colorizationColor: Theme.mutedFgColor
                                    }
                                }

                                TextInput {
                                    id: pwdInput

                                    anchors.left: passwordIcon.right
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 12

                                    color: Theme.fgColor
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.bgColor
                                    echoMode: TextInput.Password
                                    passwordCharacter: "●"
                                    clip: true
                                    autoScroll: true
                                    font.pointSize: Theme.labelFontSize
                                    font.family: Theme.labelFontFamily
                                    verticalAlignment: TextInput.AlignVCenter
                                    activeFocusOnTab: true
                                    selectByMouse: true
                                    enabled: !lockScope.authenticating

                                    onAccepted: lockScope.verifyPassword(pwdInput.text)
                                    onTextChanged: {
                                        if (text.length > 0 && lockScope.authError !== "")
                                            lockScope.authError = "";
                                    }

                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_CapsLock) {
                                            lockScope.capsLockOn = !lockScope.capsLockOn;
                                            event.accepted = true;
                                        } else if (event.key === Qt.Key_Escape) {
                                            if (!lockScope.authenticating)
                                                lockWindow.leaveLogin();
                                            event.accepted = true;
                                        }
                                    }
                                }

                                Text {
                                    id: passwordPlaceholder

                                    anchors.left: pwdInput.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Password"
                                    visible: pwdInput.text.length === 0 && pwdInput.preeditText.length === 0
                                    color: Theme.mutedFgColor
                                    font.family: pwdInput.font.family
                                    font.pointSize: pwdInput.font.pointSize
                                    font.italic: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    onClicked: pwdInput.forceActiveFocus()
                                }
                            }
                        }

                        Rectangle {
                            id: loginButton

                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            radius: Theme.cornerRadius
                            color: Theme.accent
                            opacity: loginButtonMouse.pressed ? 0.8 : 1.0
                            scale: loginButtonMouse.pressed ? 0.94 : (loginButtonMouse.containsMouse ? 1.04 : 1.0)

                            Behavior on opacity {
                                Anim {
                                    type: Anim.FastEffects
                                }
                            }
                            Behavior on scale {
                                Anim {
                                    type: Anim.DefaultSpatial
                                }
                            }

                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 20
                                source: Quickshell.iconPath("go-next", "arrow-right")
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    colorization: 1.0
                                    brightness: 1.0
                                    colorizationColor: Theme.bgColor
                                }
                            }

                            MouseArea {
                                id: loginButtonMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: lockScope.verifyPassword(pwdInput.text)
                            }
                        }
                    }

                    RowLayout {
                        id: spinnerRow

                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 44
                        spacing: 8
                        visible: lockScope.authenticating
                        opacity: visible ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 150
                            }
                        }

                        Item {
                            width: 20
                            height: 20

                            IconImage {
                                anchors.fill: parent
                                source: Quickshell.iconPath("view-refresh")
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    colorization: 1.0
                                    brightness: 1.0
                                    colorizationColor: Theme.accent
                                }
                            }

                            RotationAnimation on rotation {
                                running: spinnerRow.visible
                                from: 0
                                to: 360
                                loops: Animation.Infinite
                                duration: 1000
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Authenticating"
                            color: Theme.mutedFgColor
                            font.family: Theme.labelFontFamily
                            font.pointSize: Theme.labelFontSize
                        }
                    }

                    Text {
                        id: statusMessage

                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: 340
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap

                        text: lockScope.authError !== "" ? lockScope.authError : (lockScope.capsLockOn ? "Caps Lock is on" : "")
                        visible: text !== "" && !lockScope.authenticating
                        color: lockScope.authError !== "" ? Theme.dangerPulse : Theme.mutedFgColor
                        font.family: Theme.labelFontFamily
                        font.pointSize: Theme.labelFontSize * 0.9

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }

                Rectangle {
                    id: powerButton

                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: lockWindow.menuMargin
                    anchors.bottomMargin: lockWindow.menuMargin
                    width: 44
                    height: 44
                    radius: Theme.cornerRadius

                    z: 2
                    opacity: lockWindow.loginPage ? 1 : 0
                    visible: lockWindow.loginPage || opacity > 0.001
                    enabled: lockWindow.loginPage
                    activeFocusOnTab: lockWindow.loginPage

                    color: (lockScope.powerMenuOpen || powerButton.activeFocus) ? Theme.hoveredBgColor : (powerMouse.containsMouse ? Theme.mutedBgColor : "transparent")
                    border.width: Theme.generalThickness
                    border.color: (lockScope.powerMenuOpen || powerButton.activeFocus) ? Theme.accent : (powerMouse.containsMouse ? Theme.mutedAccent : "transparent")
                    scale: powerMouse.pressed ? 0.94 : ((powerMouse.containsMouse || powerButton.activeFocus) ? 1.04 : 1.0)

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                            lockWindow.openPowerMenu();
                            event.accepted = true;
                        }
                    }

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on border.color {
                        CAnim {}
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 20
                        source: Quickshell.iconPath("system-shutdown", "system-log-out")
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            colorization: 1.0
                            brightness: 1.0
                            colorizationColor: Theme.fgColor
                        }
                    }

                    MouseArea {
                        id: powerMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lockWindow.openPowerMenu()
                    }
                }

                // Dismiss layer for the power popup.
                Item {
                    id: powerMenuBackdrop

                    anchors.fill: parent
                    z: 8
                    visible: lockScope.powerMenuOpen || powerPopup.opacity > 0.001
                    enabled: visible

                    MouseArea {
                        anchors.fill: parent
                        onClicked: lockWindow.closePowerMenu()
                    }
                }

                Rectangle {
                    id: powerPopup

                    readonly property bool opened: lockScope.powerMenuOpen

                    anchors.right: powerButton.right
                    anchors.bottom: powerButton.top
                    anchors.bottomMargin: 8
                    width: 190
                    height: menuColumn.implicitHeight + 12
                    radius: Theme.cornerRadius
                    color: Theme.bgColor
                    border.width: Theme.generalThickness
                    border.color: Theme.mutedAccent

                    z: 9
                    visible: lockScope.powerMenuOpen || opacity > 0.001
                    opacity: opened ? 1 : 0
                    scale: opened ? 1 : 0.94
                    transformOrigin: Item.BottomRight

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }

                    // Consume clicks inside the popup so only outside clicks
                    // reach the dismiss layer.
                    MouseArea {
                        anchors.fill: parent
                    }

                    Column {
                        id: menuColumn

                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        Repeater {
                            model: lockScope.powerActions

                            delegate: Rectangle {
                                id: powerItem

                                required property var modelData
                                required property int index

                                width: menuColumn.width
                                height: 38
                                radius: Math.max(0, Theme.cornerRadius - 2)
                                color: lockScope.powerIndex === powerItem.index ? Theme.hoveredBgColor : (powerItemMouse.containsMouse ? Theme.mutedBgColor : "transparent")

                                Behavior on color {
                                    CAnim {}
                                }

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 10

                                    IconImage {
                                        anchors.verticalCenter: parent.verticalCenter
                                        implicitSize: 18
                                        source: Quickshell.iconPath(powerItem.modelData.icon)
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            colorization: 1.0
                                            brightness: 1.0
                                            colorizationColor: Theme.fgColor
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: powerItem.modelData.name
                                        color: Theme.fgColor
                                        font.family: Theme.labelFontFamily
                                        font.pointSize: Theme.labelFontSize
                                    }
                                }

                                MouseArea {
                                    id: powerItemMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: lockScope.powerIndex = powerItem.index
                                    onClicked: lockWindow.triggerPower(powerItem.modelData)
                                }
                            }
                        }
                    }
                }

                // Short horizontal shake used for failed authentication.
                SequentialAnimation {
                    id: shakeAnim
                    loops: 1

                    NumberAnimation {
                        target: shakeOffset
                        property: "x"
                        to: -24
                        duration: 40
                    }
                    NumberAnimation {
                        target: shakeOffset
                        property: "x"
                        to: 24
                        duration: 40
                    }
                    NumberAnimation {
                        target: shakeOffset
                        property: "x"
                        to: -18
                        duration: 40
                    }
                    NumberAnimation {
                        target: shakeOffset
                        property: "x"
                        to: 18
                        duration: 40
                    }
                    NumberAnimation {
                        target: shakeOffset
                        property: "x"
                        to: -10
                        duration: 40
                    }
                    NumberAnimation {
                        target: shakeOffset
                        property: "x"
                        to: 10
                        duration: 40
                    }
                    NumberAnimation {
                        target: shakeOffset
                        property: "x"
                        to: 0
                        duration: 40
                    }
                }
            }
        }
    }
}

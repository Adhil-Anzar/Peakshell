import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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
    function lock() {
        sessionLock.locked = true;
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
            lockScope.authenticating = false;
            if (result === PamResult.Success) {
                lockScope.authError = "";
                sessionLock.locked = false;
            } else {
                lockScope.authError = pam.message !== "" ? pam.message : "Authentication failed.";
                shakeAnim.start();
            }
        }

        onResponseRequiredChanged: {
            if (responseRequired && lockScope.pendingPassword !== "") {
                respond(lockScope.pendingPassword);
                lockScope.pendingPassword = "";
            }
        }

        onError: err => {
            lockScope.authenticating = false;
            lockScope.authError = "PAM session error.";
            shakeAnim.start();
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
        pam.start();
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: lockWindow
            onVisibleChanged: {
                if (visible) {
                    pwdInput.forceActiveFocus();
                }
            }

            color: Theme.bgColor

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    pwdInput.forceActiveFocus();
                    if (lockScope.authError !== "") {
                        lockScope.authError = "";
                    }
                }
            }

            // Centered Lock Screen Content
            ColumnLayout {
                id: mainCard
                anchors.centerIn: parent
                spacing: 28

                // User Profile Section
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    // Avatar Circle
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 80
                        height: 80
                        radius: 40
                        color: Theme.mutedBgColor
                        border.color: Theme.borderColor
                        border.width: Theme.generalThickness

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 44
                            source: Quickshell.iconPath("user-identity")
                        }
                    }

                    // Username Header
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: lockScope.username
                        font.pointSize: Theme.labelFontSize * 1.5
                        font.family: Theme.labelFontFamily
                        font.bold: true
                        color: Theme.fgColor
                    }

                    // Status / Subtitle Instruction
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: lockScope.authenticating ? "Authenticating..." : (lockScope.authError !== "" ? lockScope.authError : "Enter password to unlock")
                        font.pointSize: Theme.labelFontSize * 0.95
                        font.family: Theme.labelFontFamily
                        color: lockScope.authError !== "" ? Theme.dangerPulse : Theme.mutedFgColor

                        Behavior on color {
                            CAnim {}
                        }
                    }
                }

                // Password Input Field Container
                Rectangle {
                    id: inputFrame
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 300
                    implicitHeight: Theme.barHeight || 44
                    radius: Theme.cornerRadius
                    color: pwdInput.activeFocus ? Theme.hoveredBgColor : Theme.mutedBgColor
                    border.color: {
                        if (lockScope.authError !== "")
                            return Theme.dangerPulse;
                        if (pwdInput.activeFocus)
                            return Theme.accent;
                        return Theme.borderColor;
                    }
                    border.width: Theme.generalThickness

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on border.color {
                        CAnim {}
                    }

                    // Violent Shake using custom Anim component with fast spatial curves
                    SequentialAnimation {
                        id: shakeAnim
                        loops: 1

                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: -30
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: 30
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: -25
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: 25
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: -18
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: 18
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: -10
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: 10
                            type: Anim.FastEffects
                        }
                        Anim {
                            target: pwdInput
                            property: "anchors.horizontalCenterOffset"
                            to: 0
                            type: Anim.FastEffects
                        }
                    }

                    TextInput {
                        id: pwdInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        focus: true
                        echoMode: TextInput.Password
                        color: Theme.fgColor
                        font.pointSize: Theme.labelFontSize
                        font.family: Theme.labelFontFamily
                        verticalAlignment: TextInput.AlignVCenter

                        onAccepted: {
                            lockScope.verifyPassword(pwdInput.text);
                            pwdInput.text = "";
                        }
                    }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import PeakShell
import "root:/"
import "pages"
import "pages/theme"
import "widgets"

Item {
    id: root
    property int currentPage: 0
    property var navItems: [
        { label: "Theme", icon: "preferences-desktop-theme", fallback: "applications-graphics" },
        { label: "Config", icon: "preferences-system", fallback: "configure" },
        { label: "Animation", icon: "preferences-desktop-effects", fallback: "chronometer" },
        { label: "Layout", icon: "preferences-desktop-display", fallback: "view-grid" },
        { label: "Launcher", icon: "system-search", fallback: "edit-find" },
        { label: "Clipboard", icon: "edit-paste", fallback: "edit-copy" },
        { label: "Notifications", icon: "notification-active", fallback: "dialog-information" },
        { label: "OSD", icon: "video-display", fallback: "preferences-desktop-display" },
        { label: "Modules", icon: "preferences-plugin", fallback: "applications-utilities" }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 220
            color: "transparent"
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    text: "PeakShell"
                    color: Settings.fgColor
                    font.pointSize: Settings.labelFontSize + 6
                    font.bold: true
                    font.family: Settings.labelFontFamily
                }
                Repeater {
                    model: root.navItems
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 44
                        radius: Settings.cornerRadius
                        color: root.currentPage === index ? Settings.hoveredBgColor : (navMa.containsMouse ? Settings.mutedBgColor : "transparent")
                        border.color: root.currentPage === index ? Theme.accent : "transparent"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            IconImage {
                                Layout.alignment: Qt.AlignVCenter
                                implicitSize: 20
                                source: Quickshell.iconPath(modelData.icon, modelData.fallback)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: Settings.fgColor
                                font.pointSize: Settings.labelFontSize + 1
                                font.family: Settings.labelFontFamily
                            }
                        }
                        MouseArea {
                            id: navMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.currentPage = index
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
                Text {
                    Layout.fillWidth: true
                    text: "Changes apply instantly"
                    color: Settings.mutedFgColor
                    font.pointSize: Math.max(8, Settings.labelFontSize - 2)
                    font.family: Settings.labelFontFamily
                    wrapMode: Text.WordWrap
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            Flickable {
                id: flick
                anchors.fill: parent
                anchors.margins: 16
                contentWidth: width
                contentHeight: pageCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: pageCol
                    width: flick.width
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: root.navItems[root.currentPage].label
                        color: Settings.fgColor
                        font.pointSize: Settings.labelFontSize + 6
                        font.bold: true
                        font.family: Settings.labelFontFamily
                    }
                    ThemeColorsPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 0
                    }
                    ThemeConfigPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 1
                    }
                    ThemeAnimationPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 2
                    }
                    ThemeLayoutPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 3
                    }
                    LauncherPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 4
                    }
                    ClipboardPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 5
                    }
                    NotificationsPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 6
                    }
                    OsdPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 7
                    }
                    ModulesPage {
                        Layout.fillWidth: true
                        visible: root.currentPage === 8
                    }
                }
                ScrollBar.vertical: ScrollBar {}
            }
        }
    }

    onCurrentPageChanged: flick.contentY = 0
}

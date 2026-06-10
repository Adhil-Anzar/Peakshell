pragma Singleton

import QtQuick

QtObject {
    // Colors
    property string panelBg: "transparent"
    property string bgColor: "#77000000"
    property string bgColorFilled: "#FF000000"
    property string hoveredBgColor: "#77444444"
    property string mutedBgColor: "#AA242424"
    property string fgColor: "#FFFFFFFF"
    property string mutedFgColor: "#FFA0A0A0"
    property string altFgColor: "#FF050505"
    property string accent:  "#FF8C00BA"
    property string mutedAccent: "#AA797979"
    property string battery: "#FF21AB5F"
    // Sizings
    property real barHeight: 40
    property real barHorizontalPad: 20
    property real barVerticalPad: 10
    property real cornerRadius: 14
    property real cornerLargeRadius: 28
    property int generalThickness: 2
    property real dropdownOffset: 10
    property real thumbnailSize: 56
    // Fonts
    property int labelFontSize: 11
    property int iconFontSize: 24
    property string iconFontFamily: "Jetbrains Mono NL"
    property string labelFontFamily: "JetBrains Mono NL"
    // Durations ( ms )
    property int animationDuration: 300
    property int mediaPlayerUpdateDuration: 1000
    property int networkUpdateInterval: 1000

    // Arch Dashboard
    property real dashboardWidth: 500
    property real dashboardHeight: 750
    // Wifi Panel
    property real wifiPanelWidth: 400
    property real wifiPanelHeight: 400 // Maximum height for the panel
    property real wifiItemSize: 60 // Basically Height for the item
}

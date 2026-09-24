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
    property int animationDuration: 350
    property int spatialDuration: 450
    property int fastSpatialDuration: 300
    property int slowSpatialDuration: 600
    property int effectsDuration: 200
    property int mediaPlayerUpdateDuration: 1000
    property int networkUpdateInterval: 1000
    property int hoverDuration: 3000

    // Fluid Animation Bezier Curves (Material 3 Expressive, matching Caelestia)
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var curveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var curveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]

    // Arch Dashboard
    property real dashboardWidth: 500
    property real dashboardHeight: 750
    // Sound Panel
    property real soundPanelWidth: 400
    property real soundItemMaxCount: 10
    property real soundItemSize: 100
    // Wifi Panel
    property real wifiPanelWidth: 400
    property real wifiItemMaxCount: 14 // Maximum height for the panel
    property real wifiItemSize: 60 // Basically Height for the item
    // Bluetooth Panel
    property real bluetoothPanelWidth: 400
    property real bluetoothItemMaxCount: 14 // Maximum height for the panel
    property real bluetoothItemSize: 60 // Basically Height for the item

    // Workspace Panel & Preview
    property real workspacePanelWidth: 400
    property real workspacePanelHeight: 100
    property real workspacePreviewWidth: 648
    property real workspacePreviewHeight: 432
    property string urgentPulseColor: "#CC8800FF"

    // Clock & Calendar Panel
    property real clockPanelWidth: 450
    property real clockPanelHeight: 460

    // Tray Menu Panel
    property real trayMenuWidth: 260
    property real trayMenuItemHeight: 34

    // Power
    property int lowPowerThreshold: 20
}

pragma Singleton

import QtQuick
import PeakShell

QtObject {
    property string panelBg: Settings.panelBg
    property string bgColor: Settings.bgColor
    property string bgColorFilled: Settings.bgColorFilled
    property string hoveredBgColor: Settings.hoveredBgColor
    property string mutedBgColor: Settings.mutedBgColor
    property string fgColor: Settings.fgColor
    property string mutedFgColor: Settings.mutedFgColor
    property string altFgColor: Settings.altFgColor
    property color accent: Settings.accent
    Behavior on accent {
        ColorAnimation { duration: animationDuration }
    }
    property string mutedAccent: Settings.mutedAccent
    property string battery: Settings.battery
    property string danger: Settings.danger
    property string dangerPulse: Settings.dangerPulse
    property bool accentFromWallpaper: Settings.accentFromWallpaper
    property bool accentCycleEnabled: Settings.accentCycleEnabled
    property int accentCycleInterval: Settings.accentCycleInterval
    readonly property var syntaxPalette: ({
        foreground: fgColor,
        muted: mutedFgColor,
        accent: accent,
        accentSoft: urgentPulseColor,
        string: battery,
        danger: dangerPulse
    })
    property real barHeight: Settings.barHeight
    property real barHorizontalPad: Settings.barHorizontalPad
    property real barVerticalPad: Settings.barVerticalPad
    property real cornerRadius: Settings.cornerRadius
    property real cornerLargeRadius: Settings.cornerLargeRadius
    property int generalThickness: Settings.generalThickness
    property real dropdownOffset: Settings.dropdownOffset
    property real thumbnailSize: Settings.thumbnailSize
    property int labelFontSize: Settings.labelFontSize
    property int iconFontSize: Settings.iconFontSize
    property string iconFontFamily: Settings.iconFontFamily
    property string labelFontFamily: Settings.labelFontFamily
    property int animationDuration: Settings.animationDuration
    property int spatialDuration: Settings.spatialDuration
    property int fastSpatialDuration: Settings.fastSpatialDuration
    property int slowSpatialDuration: Settings.slowSpatialDuration
    property int effectsDuration: Settings.effectsDuration
    property int fastEffectsDuration: Settings.fastEffectsDuration
    property int mediaPlayerUpdateDuration: Settings.mediaPlayerUpdateDuration
    property int networkUpdateInterval: Settings.networkUpdateInterval
    property int hoverDuration: Settings.hoverDuration

    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var curveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var curveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]

    property real dashboardWidth: Settings.dashboardWidth
    property real dashboardHeight: Settings.dashboardHeight
    property real soundPanelWidth: Settings.soundPanelWidth
    property real soundItemMaxCount: Settings.soundItemMaxCount
    property real soundItemSize: Settings.soundItemSize
    property real wifiPanelWidth: Settings.wifiPanelWidth
    property real wifiItemMaxCount: Settings.wifiItemMaxCount
    property real wifiItemSize: Settings.wifiItemSize
    property real bluetoothPanelWidth: Settings.bluetoothPanelWidth
    property real bluetoothItemMaxCount: Settings.bluetoothItemMaxCount
    property real bluetoothItemSize: Settings.bluetoothItemSize
    property real brightnessPanelWidth: Settings.brightnessPanelWidth
    property real brightnessItemSize: Settings.brightnessItemSize

    property real mediaPanelWidth: Settings.mediaPanelWidth

    property real workspacePanelWidth: Settings.workspacePanelWidth
    property real workspacePanelHeight: Settings.workspacePanelHeight
    property real workspacePreviewWidth: Settings.workspacePreviewWidth
    property real workspacePreviewHeight: Settings.workspacePreviewHeight
    property string urgentPulseColor: Settings.urgentPulseColor

    property real clockPanelWidth: Settings.clockPanelWidth
    property real clockPanelHeight: Settings.clockPanelHeight
    property real timerPanelWidth: Settings.timerPanelWidth

    property real trayMenuWidth: Settings.trayMenuWidth
    property real trayMenuItemHeight: Settings.trayMenuItemHeight

    property real launcherWidth: Settings.launcherWidth
    property real launcherPadding: Settings.launcherPadding
    property real launcherSearchHeight: Settings.launcherSearchHeight
    property real launcherItemHeight: Settings.launcherItemHeight
    property real launcherIconSize: Settings.launcherIconSize
    property int launcherSearchFontSize: Settings.launcherSearchFontSize
    property int launcherMaxItems: Settings.launcherMaxItems

    property real clipboardWidth: Settings.clipboardWidth
    property real clipboardItemHeight: Settings.clipboardItemHeight
    property int clipboardMaxItems: Settings.clipboardMaxItems
    property int clipboardMaxVisibleItems: Settings.clipboardMaxVisibleItems
    property bool clipboardFuzzy: Settings.clipboardFuzzy

    property real notificationPanelWidth: Settings.notificationPanelWidth
    property real notificationItemMaxCount: Settings.notificationItemMaxCount
    property real notificationPopupWidth: Settings.notificationPopupWidth
    property int notificationPopupTimeout: Settings.notificationPopupTimeout
    property int notificationMaxPopups: Settings.notificationMaxPopups
    property bool notificationShowCopyButton: Settings.notificationShowCopyButton
    property real notificationIconSize: Settings.notificationIconSize

    property int lowPowerThreshold: Settings.lowPowerThreshold

    // On-screen display
    property int osdDuration: Settings.osdDuration
    property real osdBottomMargin: Settings.osdBottomMargin
    property string osdMonitor: Settings.osdMonitor

    // System monitor overlay
    property bool overlayBackground: Settings.overlayBackground
    property bool overlayBorder: Settings.overlayBorder
    property string overlayDisplayMode: Settings.overlayDisplayMode

    // Bar module visibility
    property bool moduleMediaPlayer: Settings.moduleMediaPlayer
    property bool moduleNotifications: Settings.moduleNotifications
    property bool moduleSound: Settings.moduleSound
    property bool moduleWifi: Settings.moduleWifi
    property bool moduleBluetooth: Settings.moduleBluetooth
    property bool moduleBrightness: Settings.moduleBrightness
    property bool brightnessScreenOffAtMin: Settings.brightnessScreenOffAtMin
    property bool moduleDateTime: Settings.moduleDateTime
    property bool moduleWorkspaces: Settings.moduleWorkspaces
    property bool moduleSysTray: Settings.moduleSysTray
}

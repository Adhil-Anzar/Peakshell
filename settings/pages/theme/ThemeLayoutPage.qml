import QtQuick
import QtQuick.Layouts
import PeakShell
import "../../widgets"

ColumnLayout {
    spacing: 12
    Section {
        title: "Bar and shape"
        resetLabel: "Reset layout"
        onReset: Settings.resetLayout()
        Row { label: "Bar height"; NumField { width: parent.width; value: Settings.barHeight; from: 20; to: 80; step: 1; onEdited: v => Settings.barHeight = v } }
        Row { label: "Bar side margin"; NumField { width: parent.width; value: Settings.barHorizontalPad; from: 0; to: 60; step: 1; onEdited: v => Settings.barHorizontalPad = v } }
        Row { label: "Bar top margin"; NumField { width: parent.width; value: Settings.barVerticalPad; from: 0; to: 40; step: 1; onEdited: v => Settings.barVerticalPad = v } }
        Row { label: "Corner radius"; NumField { width: parent.width; value: Settings.cornerRadius; from: 0; to: 30; step: 1; onEdited: v => Settings.cornerRadius = v } }
        Row { label: "Large corner radius"; NumField { width: parent.width; value: Settings.cornerLargeRadius; from: 0; to: 48; step: 1; onEdited: v => Settings.cornerLargeRadius = v } }
        Row { label: "Border thickness"; NumField { width: parent.width; value: Settings.generalThickness; from: 1; to: 6; step: 1; isInt: true; onEdited: v => Settings.generalThickness = v } }
        Row { label: "Dropdown offset"; NumField { width: parent.width; value: Settings.dropdownOffset; from: 0; to: 40; step: 1; onEdited: v => Settings.dropdownOffset = v } }
        Row { label: "Thumbnail size"; NumField { width: parent.width; value: Settings.thumbnailSize; from: 16; to: 128; step: 1; onEdited: v => Settings.thumbnailSize = v } }
    }
    Section {
        title: "Dashboard and panels"
        Row { label: "Dashboard width"; NumField { width: parent.width; value: Settings.dashboardWidth; from: 200; to: 900; step: 1; onEdited: v => Settings.dashboardWidth = v } }
        Row { label: "Dashboard height"; NumField { width: parent.width; value: Settings.dashboardHeight; from: 200; to: 1100; step: 1; onEdited: v => Settings.dashboardHeight = v } }
        Row { label: "Sound panel width"; NumField { width: parent.width; value: Settings.soundPanelWidth; from: 200; to: 800; step: 1; onEdited: v => Settings.soundPanelWidth = v } }
        Row { label: "Sound items shown"; NumField { width: parent.width; value: Settings.soundItemMaxCount; from: 1; to: 30; step: 1; onEdited: v => Settings.soundItemMaxCount = v } }
        Row { label: "Sound item size"; NumField { width: parent.width; value: Settings.soundItemSize; from: 20; to: 200; step: 1; onEdited: v => Settings.soundItemSize = v } }
        Row { label: "Wi-Fi panel width"; NumField { width: parent.width; value: Settings.wifiPanelWidth; from: 200; to: 800; step: 1; onEdited: v => Settings.wifiPanelWidth = v } }
        Row { label: "Wi-Fi items shown"; NumField { width: parent.width; value: Settings.wifiItemMaxCount; from: 1; to: 30; step: 1; onEdited: v => Settings.wifiItemMaxCount = v } }
        Row { label: "Wi-Fi item size"; NumField { width: parent.width; value: Settings.wifiItemSize; from: 20; to: 200; step: 1; onEdited: v => Settings.wifiItemSize = v } }
        Row { label: "Bluetooth panel width"; NumField { width: parent.width; value: Settings.bluetoothPanelWidth; from: 200; to: 800; step: 1; onEdited: v => Settings.bluetoothPanelWidth = v } }
        Row { label: "Bluetooth items shown"; NumField { width: parent.width; value: Settings.bluetoothItemMaxCount; from: 1; to: 30; step: 1; onEdited: v => Settings.bluetoothItemMaxCount = v } }
        Row { label: "Bluetooth item size"; NumField { width: parent.width; value: Settings.bluetoothItemSize; from: 20; to: 200; step: 1; onEdited: v => Settings.bluetoothItemSize = v } }
        Row { label: "Media panel width"; NumField { width: parent.width; value: Settings.mediaPanelWidth; from: 240; to: 800; step: 1; onEdited: v => Settings.mediaPanelWidth = v } }
        Row { label: "Workspace panel width"; NumField { width: parent.width; value: Settings.workspacePanelWidth; from: 200; to: 800; step: 1; onEdited: v => Settings.workspacePanelWidth = v } }
        Row { label: "Workspace panel height"; NumField { width: parent.width; value: Settings.workspacePanelHeight; from: 40; to: 300; step: 1; onEdited: v => Settings.workspacePanelHeight = v } }
        Row { label: "Workspace preview width"; NumField { width: parent.width; value: Settings.workspacePreviewWidth; from: 300; to: 1600; step: 1; onEdited: v => Settings.workspacePreviewWidth = v } }
        Row { label: "Workspace preview height"; NumField { width: parent.width; value: Settings.workspacePreviewHeight; from: 200; to: 1000; step: 1; onEdited: v => Settings.workspacePreviewHeight = v } }
        Row { label: "Clock panel width"; NumField { width: parent.width; value: Settings.clockPanelWidth; from: 200; to: 800; step: 1; onEdited: v => Settings.clockPanelWidth = v } }
        Row { label: "Clock panel height"; NumField { width: parent.width; value: Settings.clockPanelHeight; from: 200; to: 800; step: 1; onEdited: v => Settings.clockPanelHeight = v } }
        Row { label: "Timer panel width"; NumField { width: parent.width; value: Settings.timerPanelWidth; from: 200; to: 800; step: 1; onEdited: v => Settings.timerPanelWidth = v } }
        Row { label: "Tray menu width"; NumField { width: parent.width; value: Settings.trayMenuWidth; from: 120; to: 600; step: 1; onEdited: v => Settings.trayMenuWidth = v } }
        Row { label: "Tray item height"; NumField { width: parent.width; value: Settings.trayMenuItemHeight; from: 16; to: 80; step: 1; onEdited: v => Settings.trayMenuItemHeight = v } }
    }
    Section {
        title: "Launcher sizing"
        Row { label: "Width"; NumField { width: parent.width; value: Settings.launcherWidth; from: 300; to: 1000; step: 1; onEdited: v => Settings.launcherWidth = v } }
        Row { label: "Padding"; NumField { width: parent.width; value: Settings.launcherPadding; from: 0; to: 32; step: 1; onEdited: v => Settings.launcherPadding = v } }
        Row { label: "Search bar height"; NumField { width: parent.width; value: Settings.launcherSearchHeight; from: 32; to: 100; step: 1; onEdited: v => Settings.launcherSearchHeight = v } }
        Row { label: "Result row height"; NumField { width: parent.width; value: Settings.launcherItemHeight; from: 32; to: 120; step: 1; onEdited: v => Settings.launcherItemHeight = v } }
        Row { label: "Result icon size"; NumField { width: parent.width; value: Settings.launcherIconSize; from: 12; to: 64; step: 1; onEdited: v => Settings.launcherIconSize = v } }
        Row { label: "Search font size"; NumField { width: parent.width; value: Settings.launcherSearchFontSize; from: 8; to: 32; step: 1; isInt: true; onEdited: v => Settings.launcherSearchFontSize = v } }
        Row { label: "Visible results"; NumField { width: parent.width; value: Settings.launcherMaxItems; from: 1; to: 12; step: 1; isInt: true; onEdited: v => Settings.launcherMaxItems = v } }
    }
    Section {
        title: "Notification sizing"
        Row { label: "Panel width"; NumField { width: parent.width; value: Settings.notificationPanelWidth; from: 200; to: 800; step: 1; onEdited: v => Settings.notificationPanelWidth = v } }
        Row { label: "Panel items shown"; NumField { width: parent.width; value: Settings.notificationItemMaxCount; from: 1; to: 20; step: 1; onEdited: v => Settings.notificationItemMaxCount = v } }
        Row { label: "Popup width"; NumField { width: parent.width; value: Settings.notificationPopupWidth; from: 200; to: 800; step: 1; onEdited: v => Settings.notificationPopupWidth = v } }
        Row { label: "Popup timeout"; hint: "Milliseconds before a popup fades"; NumField { width: parent.width; value: Settings.notificationPopupTimeout; from: 1000; to: 30000; step: 500; isInt: true; onEdited: v => Settings.notificationPopupTimeout = v } }
        Row { label: "Max popups"; NumField { width: parent.width; value: Settings.notificationMaxPopups; from: 1; to: 10; step: 1; isInt: true; onEdited: v => Settings.notificationMaxPopups = v } }
        Row { label: "Icon size"; NumField { width: parent.width; value: Settings.notificationIconSize; from: 12; to: 64; step: 1; onEdited: v => Settings.notificationIconSize = v } }
    }
}

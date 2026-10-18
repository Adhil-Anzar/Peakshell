import QtQuick
import QtQuick.Layouts
import PeakShell
import "root:/services"
import "../../widgets"

ColumnLayout {
    spacing: 12
    Section {
        title: "Fonts"
        resetLabel: "Reset config"
        onReset: Settings.resetConfig()
        Row { label: "Label size"; NumField { width: parent.width; value: Settings.labelFontSize; from: 8; to: 32; step: 1; isInt: true; onEdited: v => Settings.labelFontSize = v } }
        Row { label: "Icon size"; NumField { width: parent.width; value: Settings.iconFontSize; from: 8; to: 48; step: 1; isInt: true; onEdited: v => Settings.iconFontSize = v } }
        Row { label: "Label font"; StrField { width: parent.width; text: Settings.labelFontFamily; onCommitted: v => { if (v.length > 0) Settings.labelFontFamily = v } } }
        Row { label: "Icon font"; StrField { width: parent.width; text: Settings.iconFontFamily; onCommitted: v => { if (v.length > 0) Settings.iconFontFamily = v } } }
    }
    Section {
        title: "Refresh intervals"
        hint: "How often live data is polled, in milliseconds"
        Row { label: "Media player"; hint: "Player position poll interval"; NumField { width: parent.width; value: Settings.mediaPlayerUpdateDuration; from: 250; to: 5000; step: 50; isInt: true; onEdited: v => Settings.mediaPlayerUpdateDuration = v } }
        Row { label: "Network speed"; hint: "Speed poll interval"; NumField { width: parent.width; value: Settings.networkUpdateInterval; from: 250; to: 5000; step: 50; isInt: true; onEdited: v => Settings.networkUpdateInterval = v } }
    }
    Section {
        title: "Power"
        // Low battery warning cannot fire without a battery.
        visible: Platform.isLaptop
        Row { label: "Low battery warning"; hint: "Percent triggering the warning"; NumField { width: parent.width; value: Settings.lowPowerThreshold; from: 1; to: 50; step: 1; isInt: true; onEdited: v => Settings.lowPowerThreshold = v } }
    }
}

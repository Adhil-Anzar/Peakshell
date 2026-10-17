import QtQuick
import QtQuick.Layouts
import PeakShell
import "../../widgets"

ColumnLayout {
    spacing: 12
    Section {
        title: "Animations"
        hint: "Durations in milliseconds"
        resetLabel: "Reset animation"
        onReset: Settings.resetAnimation()
        Row { label: "General"; NumField { width: parent.width; value: Settings.animationDuration; from: 10; to: 2000; step: 10; isInt: true; onEdited: v => Settings.animationDuration = v } }
        Row { label: "Spatial"; NumField { width: parent.width; value: Settings.spatialDuration; from: 10; to: 2000; step: 10; isInt: true; onEdited: v => Settings.spatialDuration = v } }
        Row { label: "Fast spatial"; NumField { width: parent.width; value: Settings.fastSpatialDuration; from: 10; to: 2000; step: 10; isInt: true; onEdited: v => Settings.fastSpatialDuration = v } }
        Row { label: "Slow spatial"; NumField { width: parent.width; value: Settings.slowSpatialDuration; from: 10; to: 2000; step: 10; isInt: true; onEdited: v => Settings.slowSpatialDuration = v } }
        Row { label: "Effects"; NumField { width: parent.width; value: Settings.effectsDuration; from: 10; to: 2000; step: 10; isInt: true; onEdited: v => Settings.effectsDuration = v } }
        Row { label: "Fast effects"; NumField { width: parent.width; value: Settings.fastEffectsDuration; from: 10; to: 2000; step: 10; isInt: true; onEdited: v => Settings.fastEffectsDuration = v } }
        Row { label: "Hover reveal"; hint: "How long bar labels linger"; NumField { width: parent.width; value: Settings.hoverDuration; from: 100; to: 10000; step: 100; isInt: true; onEdited: v => Settings.hoverDuration = v } }
    }
}

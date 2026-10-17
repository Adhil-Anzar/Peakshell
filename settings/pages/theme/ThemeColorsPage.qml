import QtQuick
import QtQuick.Layouts
import PeakShell
import "../../widgets"

ColumnLayout {
    spacing: 12
    Section {
        title: "Colors"
        resetLabel: "Reset theme"
        onReset: Settings.resetTheme()
        Row { label: "Panel background"; hint: "Bar container, transparent lets wallpaper through"; ColorField { width: parent.width; value: Settings.panelBg; onEdited: v => { if (isColor(v)) Settings.panelBg = v } } }
        Row { label: "Background"; hint: "Cards and popups"; ColorField { width: parent.width; value: Settings.bgColor; onEdited: v => { if (isColor(v)) Settings.bgColor = v } } }
        Row { label: "Background filled"; hint: "Opaque surfaces and menus"; ColorField { width: parent.width; value: Settings.bgColorFilled; onEdited: v => { if (isColor(v)) Settings.bgColorFilled = v } } }
        Row { label: "Hovered background"; hint: "Selected row highlight"; ColorField { width: parent.width; value: Settings.hoveredBgColor; onEdited: v => { if (isColor(v)) Settings.hoveredBgColor = v } } }
        Row { label: "Muted background"; hint: "Inactive tracks and hovers"; ColorField { width: parent.width; value: Settings.mutedBgColor; onEdited: v => { if (isColor(v)) Settings.mutedBgColor = v } } }
        Row { label: "Foreground"; hint: "Primary text and icons"; ColorField { width: parent.width; value: Settings.fgColor; onEdited: v => { if (isColor(v)) Settings.fgColor = v } } }
        Row { label: "Muted foreground"; hint: "Secondary text"; ColorField { width: parent.width; value: Settings.mutedFgColor; onEdited: v => { if (isColor(v)) Settings.mutedFgColor = v } } }
        Row { label: "Alt foreground"; hint: "Text on accent surfaces"; ColorField { width: parent.width; value: Settings.altFgColor; onEdited: v => { if (isColor(v)) Settings.altFgColor = v } } }
        Row { label: "Accent"; hint: "Selection, sliders and borders"; ColorField { width: parent.width; value: Settings.accent; onEdited: v => { if (isColor(v)) Settings.accent = v } } }
        Row { label: "Muted accent"; hint: "Card borders"; ColorField { width: parent.width; value: Settings.mutedAccent; onEdited: v => { if (isColor(v)) Settings.mutedAccent = v } } }
        Row { label: "Battery"; hint: "Battery level bar"; ColorField { width: parent.width; value: Settings.battery; onEdited: v => { if (isColor(v)) Settings.battery = v } } }
        Row { label: "Danger"; hint: "Idle warning background"; ColorField { width: parent.width; value: Settings.danger; onEdited: v => { if (isColor(v)) Settings.danger = v } } }
        Row { label: "Danger pulse"; hint: "Critical warning flash"; ColorField { width: parent.width; value: Settings.dangerPulse; onEdited: v => { if (isColor(v)) Settings.dangerPulse = v } } }
        Row { label: "Urgent pulse"; hint: "Urgent workspace glow"; ColorField { width: parent.width; value: Settings.urgentPulseColor; onEdited: v => { if (isColor(v)) Settings.urgentPulseColor = v } } }
    }

    function isColor(v) {
        return v === "transparent" || /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(v);
    }
}

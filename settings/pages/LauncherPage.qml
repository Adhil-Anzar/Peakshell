import QtQuick
import QtQuick.Layouts
import PeakShell
import "../widgets"

ColumnLayout {
    spacing: 12
    Section {
        title: "Features"
        resetLabel: "Reset launcher"
        onReset: Settings.resetLauncher()
        Row {
            label: "Web search"
            hint: "Show a web search result when nothing else matches"
            Toggle {
                x: parent.width - width
                checked: Settings.launcherWebSearch
                onToggled: v => Settings.launcherWebSearch = v
            }
        }
        Row {
            label: "Calculator"
            hint: "Evaluate math expressions right in the launcher"
            Toggle {
                x: parent.width - width
                checked: Settings.launcherCalc
                onToggled: v => Settings.launcherCalc = v
            }
        }
        Row {
            label: "Fuzzy search"
            hint: "Off means only literal substring matches are shown"
            Toggle {
                x: parent.width - width
                checked: Settings.launcherFuzzy
                onToggled: v => Settings.launcherFuzzy = v
            }
        }
        Row {
            label: "Power options"
            hint: "Show logout, reboot, shutdown and the power menu in the launcher"
            Toggle {
                x: parent.width - width
                checked: Settings.launcherPowerActions
                onToggled: v => Settings.launcherPowerActions = v
            }
        }
        Row {
            label: "Wallpaper actions"
            hint: "Show next/previous wallpaper (and preview) in the launcher"
            Toggle {
                x: parent.width - width
                checked: Settings.launcherWallpaperActions
                onToggled: v => Settings.launcherWallpaperActions = v
            }
        }
    }
    Section {
        title: "Search engine"
        hint: "Used when web search is on. The query is appended to the URL."
        visible: Settings.launcherWebSearch
        Row {
            label: "Engine"
            ChoiceBox {
                width: parent.width
                model: Settings.searchEngineNames()
                currentIndex: Math.max(0, Settings.searchEngineNames().indexOf(Settings.searchEngine))
                onChosen: v => Settings.searchEngine = v
            }
        }
        Row {
            label: "Custom URL"
            hint: "Example: https://search.example.com/?q="
            visible: Settings.searchEngine === "Custom"
            StrField {
                width: parent.width
                text: Settings.customSearchUrl
                placeholderText: "https://…/?q="
                onCommitted: v => Settings.customSearchUrl = v.trim()
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Resolves to: " + Settings.searchUrl
            color: Settings.mutedFgColor
            font.pointSize: Math.max(8, Settings.labelFontSize - 2)
            font.family: Settings.labelFontFamily
            elide: Text.ElideMiddle
        }
    }
}

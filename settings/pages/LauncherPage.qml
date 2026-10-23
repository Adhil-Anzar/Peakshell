import QtQuick
import QtQuick.Layouts
import PeakShell
import "../widgets"

ColumnLayout {
    spacing: 12

    readonly property string folderTerm: Settings.launcherFolderTerm === "folder" ? "folder" : "directory"
    readonly property string folderTermPlural: folderTerm + "s"

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
            label: "Fuzzy app search"
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
        title: "Scoped search"
        hint: Settings.launcherScopeKey.length > 0
            ? "Type " + Settings.launcherScopeKey + "files, " + Settings.launcherScopeKey + folderTerm
              + ", " + Settings.launcherScopeKey + "app, " + Settings.launcherScopeKey + "action, "
              + Settings.launcherScopeKey + "calc or " + Settings.launcherScopeKey + "web. "
              + "Press Tab to complete it into a tag."
            : "Scoped search is disabled. Set a prefix (for example /) to enable it."
        Row {
            label: "Scope prefix"
            hint: "Starts a scoped search; Tab completes it into a tag. Clear to disable."
            StrField {
                width: parent.width
                text: Settings.launcherScopeKey
                placeholderText: "/"
                onCommitted: v => Settings.launcherScopeKey = v.trim()
            }
        }
    }
    Section {
        title: "Files & " + folderTermPlural
        hint: "Recent files first, then the system index (Baloo when available). Files and "
              + folderTermPlural + " are searched in the background."
        Row {
            label: "Terminology"
            hint: "Call these items " + folderTermPlural + " throughout the launcher and settings."
            ChoiceBox {
                width: parent.width
                model: ["Directory", "Folder"]
                currentIndex: Settings.launcherFolderTerm === "folder" ? 1 : 0
                onChosen: v => Settings.launcherFolderTerm = v.toLowerCase()
            }
        }
        Row {
            label: "Search files"
            hint: "Show matching files in the launcher"
            Toggle {
                x: parent.width - width
                checked: Settings.launcherFileSearch
                onToggled: v => Settings.launcherFileSearch = v
            }
        }
        Row {
            label: "Fuzzy file search"
            hint: "Allow approximate file-name matches (typos, missing separators)"
            visible: Settings.launcherFileSearch
            Toggle {
                x: parent.width - width
                checked: Settings.launcherFileFuzzy
                onToggled: v => Settings.launcherFileFuzzy = v
            }
        }
        Row {
            label: "Search " + folderTermPlural
            hint: "Show matching " + folderTermPlural + " in the launcher"
            Toggle {
                x: parent.width - width
                checked: Settings.launcherFolderSearch
                onToggled: v => Settings.launcherFolderSearch = v
            }
        }
        Row {
            label: "Fuzzy " + folderTerm + " search"
            hint: "Allow approximate " + folderTerm + "-name matches (typos, missing separators)"
            visible: Settings.launcherFolderSearch
            Toggle {
                x: parent.width - width
                checked: Settings.launcherFolderFuzzy
                onToggled: v => Settings.launcherFolderFuzzy = v
            }
        }
        Row {
            label: "Search entire filesystem"
            hint: "Recursively scan hidden config paths and all local files and "
                  + folderTermPlural + " in addition to the index. Slow; off by default."
            Toggle {
                x: parent.width - width
                checked: Settings.launcherFullFilesystemSearch
                onToggled: v => Settings.launcherFullFilesystemSearch = v
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

import QtQuick
import QtQuick.Layouts
import Quickshell
import PeakShell
import "../widgets"

ColumnLayout {
    id: root
    spacing: 12

    property var monitorNames: {
        const names = ["All monitors"];
        for (const screen of Quickshell.screens)
            names.push(screen.name);
        return names;
    }

    Section {
        title: "On-screen display"
        hint: "Feedback shown when volume, brightness, lock keys or media change"
        resetLabel: "Reset OSD"
        onReset: Settings.resetOsd()

        Row {
            label: "Timeout"
            hint: "How long the OSD stays on screen, in milliseconds"
            NumField {
                width: parent.width
                value: Settings.osdDuration
                from: 200
                to: 10000
                step: 100
                isInt: true
                onEdited: v => Settings.osdDuration = v
            }
        }
        Row {
            label: "Bottom margin"
            hint: "Distance from the bottom edge as a percentage of the screen height"
            NumField {
                width: parent.width
                value: Settings.osdBottomMargin
                from: 0
                to: 80
                step: 1
                onEdited: v => Settings.osdBottomMargin = v
            }
        }
        Row {
            label: "Output"
            hint: "Show the OSD on every monitor or only one"
            ChoiceBox {
                width: parent.width
                model: root.monitorNames
                currentIndex: Math.max(0, root.monitorNames.indexOf(Settings.osdMonitor === "" ? "All monitors" : Settings.osdMonitor))
                onChosen: v => Settings.osdMonitor = v === "All monitors" ? "" : v
            }
        }
    }
}

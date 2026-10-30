import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import PeakShell
import "root:/"
import "../widgets"

ColumnLayout {
    id: root
    spacing: 12

    // Component keys match the tokens stored in Settings.overlayOrder.
    readonly property var componentKeys: ["cpu", "gpu", "ram"]
    readonly property var displayModeKeys: ["iconText", "text", "icon"]
    readonly property var displayModeLabels: ["Icon and text", "Text only", "Icon only"]
    readonly property var componentInfo: ({
        cpu: {
            label: "CPU",
            icon: "indicator-sensors-cpu",
            metrics: [
                { id: "load", label: "Utilization", hint: "Processor load percentage" },
                { id: "temp", label: "Temperature", hint: "Package temperature in °C" }
            ]
        },
        gpu: {
            label: "GPU",
            icon: "indicator-sensors-gpu",
            metrics: [
                { id: "load", label: "Utilization", hint: "Graphics load percentage" },
                { id: "temp", label: "Temperature", hint: "Graphics temperature in °C" }
            ]
        },
        ram: {
            label: "RAM",
            icon: "indicator-sensors-memory",
            metrics: [
                { id: "usage", label: "Usage", hint: "Used memory percentage" }
            ]
        }
    })

    readonly property var order: normalizeOrder(Settings.overlayOrder)

    // Repairs a hand-edited order: drops unknown/duplicate tokens and appends
    // any components that are missing.
    function normalizeOrder(raw) {
        const parsed = (raw || "").split(",").map(part => part.trim());
        const keys = [];
        for (const key of parsed) {
            if (componentKeys.indexOf(key) !== -1 && keys.indexOf(key) === -1)
                keys.push(key);
        }
        for (const key of componentKeys) {
            if (keys.indexOf(key) === -1)
                keys.push(key);
        }
        return keys;
    }

    function componentEnabled(key) {
        switch (key) {
        case "cpu":
            return Settings.overlayCpuEnabled;
        case "gpu":
            return Settings.overlayGpuEnabled;
        case "ram":
            return Settings.overlayRamEnabled;
        }
        return false;
    }

    function setComponentEnabled(key, value) {
        switch (key) {
        case "cpu":
            Settings.overlayCpuEnabled = value;
            break;
        case "gpu":
            Settings.overlayGpuEnabled = value;
            break;
        case "ram":
            Settings.overlayRamEnabled = value;
            break;
        }
    }

    function metricEnabled(key, metric) {
        switch (key + "/" + metric) {
        case "cpu/load":
            return Settings.overlayCpuLoad;
        case "cpu/temp":
            return Settings.overlayCpuTemp;
        case "gpu/load":
            return Settings.overlayGpuLoad;
        case "gpu/temp":
            return Settings.overlayGpuTemp;
        case "ram/usage":
            return Settings.overlayRamUsage;
        }
        return false;
    }

    function setMetricEnabled(key, metric, value) {
        switch (key + "/" + metric) {
        case "cpu/load":
            Settings.overlayCpuLoad = value;
            break;
        case "cpu/temp":
            Settings.overlayCpuTemp = value;
            break;
        case "gpu/load":
            Settings.overlayGpuLoad = value;
            break;
        case "gpu/temp":
            Settings.overlayGpuTemp = value;
            break;
        case "ram/usage":
            Settings.overlayRamUsage = value;
            break;
        }
    }

    function move(index, delta) {
        const target = index + delta;
        if (target < 0 || target >= order.length)
            return;
        const keys = order.slice();
        const swap = keys[index];
        keys[index] = keys[target];
        keys[target] = swap;
        Settings.overlayOrder = keys.join(",");
    }

    Section {
        title: "Appearance"
        hint: "The system monitor overlay is toggled from the bar overlay shortcut."
        resetLabel: "Reset overlay"
        onReset: Settings.resetOverlay()

        Row {
            label: "Background"
            hint: "Draw the panel background behind the metrics"
            Toggle {
                x: parent.width - width
                checked: Settings.overlayBackground
                onToggled: v => Settings.overlayBackground = v
            }
        }
        Row {
            label: "Border"
            hint: "Outline the overlay with the muted theme border"
            Toggle {
                x: parent.width - width
                checked: Settings.overlayBorder
                onToggled: v => Settings.overlayBorder = v
            }
        }
        Row {
            label: "Display"
            hint: "Component names, icons with names, or icons alone (values are always shown)"
            ChoiceBox {
                width: parent.width
                model: root.displayModeLabels
                currentIndex: Math.max(0, root.displayModeKeys.indexOf(Settings.overlayDisplayMode))
                onChosen: v => Settings.overlayDisplayMode = root.displayModeKeys[root.displayModeLabels.indexOf(v)]
            }
        }
    }

    Section {
        title: "Components"
        hint: "Show or hide metrics and use the arrows to reorder them in the overlay."

        Repeater {
            model: root.order

            delegate: Rectangle {
                id: entry
                required property string modelData
                required property int index

                readonly property var info: root.componentInfo[modelData]
                readonly property bool componentOn: root.componentEnabled(modelData)

                Layout.fillWidth: true
                implicitHeight: entryColumn.implicitHeight + 20
                radius: Settings.cornerRadius
                color: Settings.mutedBgColor
                border.color: entry.componentOn ? Theme.accent : Settings.mutedAccent
                border.width: entry.componentOn ? Settings.generalThickness : 1

                ColumnLayout {
                    id: entryColumn
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        IconImage {
                            implicitSize: 18
                            source: Quickshell.iconPath(entry.info.icon)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.info.label
                            color: Settings.fgColor
                            opacity: entry.componentOn ? 1 : 0.5
                            font.pointSize: Settings.labelFontSize + 1
                            font.bold: true
                            font.family: Settings.labelFontFamily
                        }

                        // Reorder controls
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: Settings.cornerRadius
                            color: upMa.containsMouse && entry.index > 0 ? Settings.hoveredBgColor : "transparent"
                            border.color: Settings.mutedAccent
                            border.width: 1
                            opacity: entry.index > 0 ? 1 : 0.3
                            Text {
                                anchors.centerIn: parent
                                text: "↑"
                                color: Settings.fgColor
                                font.pointSize: Settings.labelFontSize
                                font.family: Settings.labelFontFamily
                            }
                            MouseArea {
                                id: upMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: entry.index > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (entry.index > 0)
                                        root.move(entry.index, -1);
                                }
                            }
                        }
                        Rectangle {
                            implicitWidth: 26
                            implicitHeight: 26
                            radius: Settings.cornerRadius
                            color: downMa.containsMouse && entry.index < root.order.length - 1 ? Settings.hoveredBgColor : "transparent"
                            border.color: Settings.mutedAccent
                            border.width: 1
                            opacity: entry.index < root.order.length - 1 ? 1 : 0.3
                            Text {
                                anchors.centerIn: parent
                                text: "↓"
                                color: Settings.fgColor
                                font.pointSize: Settings.labelFontSize
                                font.family: Settings.labelFontFamily
                            }
                            MouseArea {
                                id: downMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: entry.index < root.order.length - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (entry.index < root.order.length - 1)
                                        root.move(entry.index, 1);
                                }
                            }
                        }

                        Toggle {
                            checked: entry.componentOn
                            onToggled: v => root.setComponentEnabled(entry.modelData, v)
                        }
                    }

                    Repeater {
                        model: entry.info.metrics

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.leftMargin: 26
                            spacing: 8
                            opacity: entry.componentOn ? 1 : 0.5

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: Settings.fgColor
                                    font.pointSize: Settings.labelFontSize
                                    font.family: Settings.labelFontFamily
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.hint
                                    color: Settings.mutedFgColor
                                    font.pointSize: Math.max(8, Settings.labelFontSize - 2)
                                    font.family: Settings.labelFontFamily
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Toggle {
                                checked: root.metricEnabled(entry.modelData, modelData.id)
                                onToggled: v => root.setMetricEnabled(entry.modelData, modelData.id, v)
                            }
                        }
                    }
                }
            }
        }
    }
}

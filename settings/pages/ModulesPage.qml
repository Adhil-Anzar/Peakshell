import QtQuick
import QtQuick.Layouts
import PeakShell
import "../widgets"

ColumnLayout {
    spacing: 12
    Section {
        title: "Bar modules"
        hint: "Toggle which modules are shown on the bar"
        resetLabel: "Reset modules"
        onReset: Settings.resetModules()
        Row {
            label: "Media player"
            hint: "Now playing module with album art and transport controls"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleMediaPlayer
                onToggled: v => Settings.moduleMediaPlayer = v
            }
        }
        Row {
            label: "Notifications"
            hint: "Notification center chip (right click toggles Do Not Disturb)"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleNotifications
                onToggled: v => Settings.moduleNotifications = v
            }
        }
        Row {
            label: "Sound"
            hint: "Volume and audio device chip"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleSound
                onToggled: v => Settings.moduleSound = v
            }
        }
        Row {
            label: "Wi-Fi"
            hint: "Wireless network chip"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleWifi
                onToggled: v => Settings.moduleWifi = v
            }
        }
        Row {
            label: "Bluetooth"
            hint: "Bluetooth chip"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleBluetooth
                onToggled: v => Settings.moduleBluetooth = v
            }
        }
        Row {
            label: "Brightness"
            hint: "Monitor brightness chip (only shown when a monitor supports it)"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleBrightness
                onToggled: v => Settings.moduleBrightness = v
            }
        }
        Row {
            label: "Brightness sleep shortcut"
            hint: "Turn off the screen after three more down presses at 0%"
            Toggle {
                x: parent.width - width
                checked: Settings.brightnessScreenOffAtMin
                onToggled: v => Settings.brightnessScreenOffAtMin = v
            }
        }
        Row {
            label: "Date & time"
            hint: "Clock / calendar module"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleDateTime
                onToggled: v => Settings.moduleDateTime = v
            }
        }
        Row {
            label: "Workspaces"
            hint: "Hyprland workspace indicator"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleWorkspaces
                onToggled: v => Settings.moduleWorkspaces = v
            }
        }
        Row {
            label: "System tray"
            hint: "Tray pill for background application icons"
            Toggle {
                x: parent.width - width
                checked: Settings.moduleSysTray
                onToggled: v => Settings.moduleSysTray = v
            }
        }
    }
}

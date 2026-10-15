//@ pragma UseQApplication
import Quickshell
import "bar"
import "bar/panels"
import "lock" // Path to your LockScreen component

ShellRoot {
    // Global lock screen instance
    ScreenlockPanel {
        id: lockScreen
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property ShellScreen modelData

            WallpaperPanel {
                screen: screenScope.modelData
            }

            Bar {
                screen: screenScope.modelData
            }
        }
    }
}

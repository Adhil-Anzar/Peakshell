//@ pragma UseQApplication
import Quickshell
import "bar"
import "bar/panels"

ShellRoot {
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

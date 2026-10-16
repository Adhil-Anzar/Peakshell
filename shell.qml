//@ pragma UseQApplication
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
import Quickshell
import "bar"
import "bar/panels"
import "lock" // Path to your LockScreen component

ShellRoot {
    // Global lock screen instance
    ScreenlockPanel {
        id: lockScreen
    }

    settings.watchFiles: true

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

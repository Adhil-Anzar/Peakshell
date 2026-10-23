qml_module(peakshell-wallpapers
    URI PeakShell.Wallpapers
    SOURCES
        wallpaperaccent.cpp
        wallpaperaccent.hpp
        wallpaperscanner.cpp
    LIBRARIES
        Qt::Concurrent
        Qt::Gui
        peakshell-util
        peakshell-core
    DEPENDENCIES
        PeakShell
)

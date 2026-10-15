qml_module(peakshell-apps
    URI PeakShell.Apps
    SOURCES
        appscanner.cpp
    LIBRARIES
        Qt::Concurrent
        peakshell-util
        peakshell-core
    DEPENDENCIES
        PeakShell
)

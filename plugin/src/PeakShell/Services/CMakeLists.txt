qml_module(peakshell-services
    URI PeakShell.Services
    SOURCES
        tickingservice.cpp
        systemmonitor.cpp
        networkusage.cpp
        sessionmanager.cpp
    LIBRARIES
        Qt::Concurrent
        Qt::DBus
        peakshell-util
        peakshell-core
    DEPENDENCIES
        PeakShell
)

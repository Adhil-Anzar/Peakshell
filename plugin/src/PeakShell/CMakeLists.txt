qml_module(peakshell-core
    URI PeakShell
    INCLUDE_PREFIX core
    SOURCES
        utils.cpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        peakshell-util
)

add_subdirectory(Services)
add_subdirectory(Apps)
add_subdirectory(Wallpapers)

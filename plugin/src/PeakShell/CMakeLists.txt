qml_module(peakshell-core
    URI PeakShell
    INCLUDE_PREFIX core
    SOURCES
        utils.cpp
        utils.hpp
        settings.cpp
        settings.hpp
    LIBRARIES
        Qt::Gui
        Qt::Quick
        Qt::Concurrent
        Qt::DBus
        peakshell-util
)

add_subdirectory(Services)
add_subdirectory(Apps)
add_subdirectory(Wallpapers)

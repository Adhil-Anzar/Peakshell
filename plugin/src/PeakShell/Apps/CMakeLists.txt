# calculator.cpp only wraps the third-party exprtk header (copied from
# OpenSearch, never edited); silence its warnings without touching our own.
set_source_files_properties(calculator.cpp PROPERTIES COMPILE_OPTIONS "-w")

qml_module(peakshell-apps
    URI PeakShell.Apps
    SOURCES
        appscanner.cpp
        appscanner.hpp
        clipboardmanager.cpp
        clipboardmanager.hpp
        calculator.cpp
        calculator.h
        fuzzy/fuzzysearch.cpp
        fuzzy/fuzzysearch.h
        fuzzy/Matrix.h
    LIBRARIES
        Qt::Concurrent
        Qt::Gui
        peakshell-util
        peakshell-core
    DEPENDENCIES
        PeakShell
)

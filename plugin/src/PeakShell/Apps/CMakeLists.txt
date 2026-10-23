# calculator.cpp only wraps the third-party exprtk header (copied from
# OpenSearch, never edited); silence its warnings without touching our own.
set_source_files_properties(calculator.cpp PROPERTIES COMPILE_OPTIONS "-w")

# Optional: clipboard text previews get syntax highlighting when the KDE
# syntax-highlighting library is available. Without it they still render as
# escaped, whitespace-preserving plain text.
find_package(KF6SyntaxHighlighting QUIET)
# Optional: Baloo gives us the same index Dolphin/KRunner use. Without it the
# launcher falls back to a bounded asynchronous home-directory scan.
find_package(KF6Baloo QUIET)

qml_module(peakshell-apps
    URI PeakShell.Apps
    SOURCES
        appscanner.cpp
        appscanner.hpp
        clipboardmanager.cpp
        clipboardmanager.hpp
        calculator.cpp
        calculator.h
        filesearch.cpp
        filesearch.hpp
        fuzzy/fuzzysearch.cpp
        fuzzy/fuzzysearch.h
        fuzzy/Matrix.h
        syntaxhighlighter.cpp
        syntaxhighlighter.hpp
    LIBRARIES
        Qt::Concurrent
        Qt::Gui
        peakshell-util
        peakshell-core
    DEPENDENCIES
        PeakShell
)

if(KF6SyntaxHighlighting_FOUND)
    target_link_libraries(peakshell-apps PRIVATE KF6::SyntaxHighlighting)
    target_compile_definitions(peakshell-apps PRIVATE PEAKSHELL_HAVE_KSYNTAXHIGHLIGHTING)
endif()

if(KF6Baloo_FOUND)
    target_link_libraries(peakshell-apps PRIVATE KF6::Baloo)
    target_compile_definitions(peakshell-apps PRIVATE PEAKSHELL_HAVE_BALOO)
endif()

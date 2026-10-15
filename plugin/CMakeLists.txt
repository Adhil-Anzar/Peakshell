find_package(Qt6 REQUIRED COMPONENTS Core Qml Gui Quick Concurrent DBus)
find_package(PkgConfig REQUIRED)

set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
qt_standard_project_setup(REQUIRES 6.8)

include(cmake/pch.cmake)
include(cmake/qml-module.cmake)

# Header-only utility helpers
add_library(peakshell-util INTERFACE)
target_include_directories(peakshell-util INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/include")

add_subdirectory(src/PeakShell)

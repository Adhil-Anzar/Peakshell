cmake_minimum_required(VERSION 3.19)

project(peakshell VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(INSTALL_LIBDIR "${CMAKE_INSTALL_LIBDIR}/peakshell" CACHE STRING "Library install dir")
set(INSTALL_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE STRING "QML install dir")
set(INSTALL_QSCONFDIR "${CMAKE_INSTALL_SYSCONFDIR}/xdg/quickshell/peakshell" CACHE STRING "Quickshell config install dir")

add_compile_definitions(
    QT_NO_CAST_FROM_ASCII
    QT_NO_CAST_TO_ASCII
    QT_NO_CAST_FROM_BYTEARRAY
)

add_compile_options(
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion
    -Wold-style-cast -Wnull-dereference -Wdouble-promotion
    -Wformat=2 -Wfloat-equal -Woverloaded-virtual
    -Wsign-conversion -Wredundant-decls -Wswitch
    -Wunreachable-code
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture -Wno-nonportable-include-path)
endif()

add_subdirectory(cli)
add_subdirectory(plugin)

# Install QML shell files
foreach(dir bar bar/modules bar/panels components services)
    install(DIRECTORY ${dir} DESTINATION "${INSTALL_QSCONFDIR}")
endforeach()

# Installed config should not watch files for changes (dev-only feature).
file(READ shell.qml SHELL_QML)
string(REPLACE "settings.watchFiles: true" "settings.watchFiles: false" SHELL_QML "${SHELL_QML}")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/qml")
file(WRITE "${CMAKE_BINARY_DIR}/qml/shell.qml" "${SHELL_QML}")

install(FILES "${CMAKE_BINARY_DIR}/qml/shell.qml" Theme.qml DESTINATION "${INSTALL_QSCONFDIR}")

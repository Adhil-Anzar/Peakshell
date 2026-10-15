add_executable(peakshell main.cpp)

target_compile_definitions(peakshell PRIVATE
    PEAKSHELL_VERSION="${PROJECT_VERSION}"
    PEAKSHELL_SOURCE_DIR="${CMAKE_SOURCE_DIR}"
    PEAKSHELL_BINARY_DIR="${CMAKE_BINARY_DIR}"
    PEAKSHELL_QSCONFDIR="${CMAKE_INSTALL_FULL_SYSCONFDIR}/xdg/quickshell/peakshell"
    PEAKSHELL_QMLDIR="${CMAKE_INSTALL_FULL_LIBDIR}/qt6/qml"
)

add_custom_command(TARGET peakshell POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E create_symlink
        "$<TARGET_FILE:peakshell>"
        "${CMAKE_SOURCE_DIR}/peakshell"
    COMMENT "Creating peakshell symlink in project root"
)

install(TARGETS peakshell DESTINATION "${CMAKE_INSTALL_BINDIR}")

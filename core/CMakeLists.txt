include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# globally enable MOC to parse Q_OBJECT macros
set(CMAKE_AUTOMOC ON)

set(APOLLO_RELEASE "${PROJECT_VERSION}")
set(APOLLO_COMMIT "unknown" CACHE STRING "Git commit embedded in the release")
set(APOLLO_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/..")
get_filename_component(APOLLO_SOURCE_ROOT "${APOLLO_SOURCE_ROOT}" ABSOLUTE)
if(EXISTS "${APOLLO_SOURCE_ROOT}/RELEASE.json")
    file(READ "${APOLLO_SOURCE_ROOT}/RELEASE.json" APOLLO_RELEASE_METADATA)
    string(JSON APOLLO_COMMIT GET "${APOLLO_RELEASE_METADATA}" commit)
    string(JSON APOLLO_BUILD_TIME GET "${APOLLO_RELEASE_METADATA}" buildTime)
endif()
if(APOLLO_COMMIT STREQUAL "unknown")
    find_package(Git QUIET)
    if(Git_FOUND)
        execute_process(
            COMMAND "${GIT_EXECUTABLE}" rev-parse HEAD
            WORKING_DIRECTORY "${APOLLO_SOURCE_ROOT}"
            OUTPUT_VARIABLE APOLLO_GIT_COMMIT
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
        if(APOLLO_GIT_COMMIT)
            set(APOLLO_COMMIT "${APOLLO_GIT_COMMIT}")
        endif()
    endif()
endif()
if(NOT APOLLO_BUILD_TIME)
    string(TIMESTAMP APOLLO_BUILD_TIME "%Y-%m-%dT%H:%M:%SZ" UTC)
endif()
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/apollo_release.h.in"
    "${CMAKE_BINARY_DIR}/generated/apollo_release.h"
    @ONLY
)

if(NOT DEFINED APOLLO_QML_BUILD_DIR)
    set(APOLLO_QML_BUILD_DIR "${CMAKE_BINARY_DIR}/qml")
endif()
set(QT_QML_OUTPUT_DIRECTORY "${APOLLO_QML_BUILD_DIR}")
if(NOT DEFINED APOLLO_QML_INSTALL_DIR)
    set(APOLLO_QML_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml")
endif()
if(NOT DEFINED APOLLO_CONFIG_INSTALL_DIR)
    set(APOLLO_CONFIG_INSTALL_DIR "etc/xdg/quickshell/apollo")
endif()
# Find Qt 6 basics
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network ShaderTools LinguistTools)
find_package(Qt6Keychain REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(Udev REQUIRED IMPORTED_TARGET libudev)
pkg_check_modules(Pipewire IMPORTED_TARGET libpipewire-0.3 REQUIRED)
pkg_check_modules(Cava IMPORTED_TARGET libcava QUIET)
if(NOT Cava_FOUND)
    pkg_check_modules(Cava IMPORTED_TARGET cava REQUIRED)
endif()
qt_standard_project_setup(REQUIRES 6.5)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# Base reusable logic
add_subdirectory(src)
add_subdirectory(plugin/desktopcards)

if(BUILD_TESTING)
    add_subdirectory(tests)
endif()

# Quickshell plugins
add_subdirectory(plugin/weather)
add_subdirectory(plugin/weathermap)
add_subdirectory(plugin/niri)
add_subdirectory(plugin/cava)
add_subdirectory(plugin/media)
add_subdirectory(plugin/keyboard)
add_subdirectory(plugin/lyrics)
add_subdirectory(plugin/i18n)
add_subdirectory(plugin/runtime)
add_subdirectory(plugin/gamma)
add_subdirectory(plugin/windowpreview)

install(
    DIRECTORY "${APOLLO_QML_BUILD_DIR}/Apollo/"
    DESTINATION "${APOLLO_QML_INSTALL_DIR}/Apollo"
    FILES_MATCHING
        PATTERN "qmldir"
        PATTERN "*.qmltypes"
        PATTERN "*.so*"
)


install(
    DIRECTORY
        "${APOLLO_SOURCE_ROOT}/Common"
        "${APOLLO_SOURCE_ROOT}/Components"
        "${APOLLO_SOURCE_ROOT}/Modules"
        "${APOLLO_SOURCE_ROOT}/Services"
        "${APOLLO_SOURCE_ROOT}/Widgets"
    DESTINATION "${APOLLO_CONFIG_INSTALL_DIR}"
    PATTERN "*.qmlc" EXCLUDE
)
install(
    FILES
        "${APOLLO_SOURCE_ROOT}/shell.qml"
        "${APOLLO_SOURCE_ROOT}/AppShell.qml"
    DESTINATION "${APOLLO_CONFIG_INSTALL_DIR}"
)
install(
    DIRECTORY "${APOLLO_SOURCE_ROOT}/assets/"
    DESTINATION "${APOLLO_CONFIG_INSTALL_DIR}/assets"
)
install(
    DIRECTORY "${APOLLO_SOURCE_ROOT}/scripts/"
    DESTINATION "${APOLLO_CONFIG_INSTALL_DIR}/scripts"
    USE_SOURCE_PERMISSIONS
    PATTERN "__pycache__" EXCLUDE
    PATTERN "*.pyc" EXCLUDE
    PATTERN "dev" EXCLUDE
    PATTERN "ci" EXCLUDE
    PATTERN "install" EXCLUDE
    PATTERN "release.py" EXCLUDE
    PATTERN "check-package.py" EXCLUDE
)
install(
    DIRECTORY "${APOLLO_SOURCE_ROOT}/matugen/templates/"
    DESTINATION "${APOLLO_CONFIG_INSTALL_DIR}/matugen/templates"
)
install(
    FILES "${APOLLO_SOURCE_ROOT}/matugen/config.toml"
    DESTINATION "${APOLLO_CONFIG_INSTALL_DIR}/matugen"
)

install(
    FILES "${APOLLO_SOURCE_ROOT}/packaging/systemd/user/apollo-shell.service"
    DESTINATION "${APOLLO_SYSTEMD_USER_INSTALL_DIR}"
)

install(DIRECTORY "${APOLLO_SOURCE_ROOT}/licenses/"
    DESTINATION "${APOLLO_CONFIG_INSTALL_DIR}/licenses")
install(FILES "${APOLLO_SOURCE_ROOT}/LICENSE"
    DESTINATION "${APOLLO_CONFIG_INSTALL_DIR}")

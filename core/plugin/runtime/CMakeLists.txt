qt_add_library(ApolloRuntime SHARED)

set_target_properties(ApolloRuntime PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Runtime
)

qt_add_qml_module(ApolloRuntime
    URI Apollo.Runtime
    SOURCES
        src/backlight_state.h
        src/backlight_state.cpp
        src/config_file_watch.h
        src/config_file_watch.cpp
        src/apollo_build_info.h
        src/apollo_build_info.cpp
        src/apollo_file_system.h
        src/apollo_file_system.cpp
        src/icon_theme_controller.h
        src/icon_theme_controller.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Runtime
)

target_include_directories(ApolloRuntime PRIVATE
    src
    ${CMAKE_BINARY_DIR}/generated
)

target_link_libraries(ApolloRuntime PRIVATE
    ApolloRuntimeCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
)

qt_add_shaders(ApolloRuntime "apollo_palette_shaders"
    PREFIX "/apollo/shaders"
    BASE "${APOLLO_SOURCE_ROOT}/assets/shaders"
    # Integer grain hashing requires GLSL integer/bitwise operations.
    GLSL "300es,150"
    FILES "${APOLLO_SOURCE_ROOT}/assets/shaders/zen-palette.frag"
)

qt_add_library(ApolloKeyboard SHARED)

set_target_properties(ApolloKeyboard PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Keyboard
)

qt_add_qml_module(ApolloKeyboard
    URI Apollo.Keyboard
    SOURCES
        src/shortcut_recorder.h
        src/shortcut_recorder.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Keyboard
)

target_include_directories(ApolloKeyboard PUBLIC src)

pkg_check_modules(XkbCommon REQUIRED IMPORTED_TARGET xkbcommon)

target_link_libraries(ApolloKeyboard PRIVATE
    Qt6::Quick
    Qt6::Gui
    PkgConfig::XkbCommon
    Qt6::Core
    Qt6::Qml
)

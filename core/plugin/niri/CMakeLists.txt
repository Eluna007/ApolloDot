qt_add_library(ApolloNiri SHARED)

set_target_properties(ApolloNiri PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Niri
)

qt_add_qml_module(ApolloNiri
    URI Apollo.Niri
    SOURCES
        src/niri_plugin.h
        src/niri_plugin.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Niri
)

target_include_directories(ApolloNiri PUBLIC src)

target_link_libraries(ApolloNiri PRIVATE
    ApolloNiriCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Network
)

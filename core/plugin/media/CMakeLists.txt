qt_add_library(ApolloMedia SHARED)

set_target_properties(ApolloMedia PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Media
)

qt_add_qml_module(ApolloMedia
    URI Apollo.Media
    SOURCES
        src/media_palette_plugin.h
        src/media_palette_plugin.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Media
)

target_include_directories(ApolloMedia PUBLIC src)

target_link_libraries(ApolloMedia PRIVATE
    ApolloMediaCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
)

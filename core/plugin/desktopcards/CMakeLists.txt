qt_add_library(ApolloDesktopCardsCore STATIC)

target_sources(ApolloDesktopCardsCore PRIVATE
    src/wallpaper_analyzer.h
    src/wallpaper_analyzer.cpp
)

set_target_properties(ApolloDesktopCardsCore PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

target_link_libraries(ApolloDesktopCardsCore PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
)

target_include_directories(ApolloDesktopCardsCore PUBLIC src)

qt_add_library(ApolloDesktopCards SHARED)

set_target_properties(ApolloDesktopCards PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/DesktopCards
)

qt_add_qml_module(ApolloDesktopCards
    URI Apollo.DesktopCards
    SOURCES
        src/wallpaper_analyzer.h
        src/wallpaper_analyzer.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/DesktopCards
)

target_include_directories(ApolloDesktopCards PUBLIC src)

target_link_libraries(ApolloDesktopCards PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
)

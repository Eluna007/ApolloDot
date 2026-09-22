qt_add_library(ApolloLyrics SHARED)

set_target_properties(ApolloLyrics PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Lyrics
)

qt_add_qml_module(ApolloLyrics
    URI Apollo.Lyrics
    SOURCES
        src/lyrics.h
        src/lyrics.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Lyrics
)

target_include_directories(ApolloLyrics PUBLIC src)

target_link_libraries(ApolloLyrics PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::Qml
)

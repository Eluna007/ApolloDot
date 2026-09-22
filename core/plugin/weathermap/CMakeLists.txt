qt_add_library(ApolloWeatherMap SHARED)

set_target_properties(ApolloWeatherMap PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/WeatherMap
)

qt_add_qml_module(ApolloWeatherMap
    URI Apollo.WeatherMap
    SOURCES
        src/weather_map_plugin.h
        src/weather_map_plugin.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/WeatherMap
)

target_include_directories(ApolloWeatherMap PUBLIC src)

target_link_libraries(ApolloWeatherMap PRIVATE
    ApolloWeatherMapCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Network
)

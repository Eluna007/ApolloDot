qt_add_library(ApolloWeather SHARED)

set_target_properties(ApolloWeather PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Weather
)

qt_add_qml_module(ApolloWeather
    URI Apollo.Weather
    SOURCES
        src/weather_plugin.h
        src/weather_plugin.cpp
        src/weather_list_model.h
        src/weather_list_model.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Weather
)

target_include_directories(ApolloWeather PUBLIC src)

target_link_libraries(ApolloWeather PRIVATE
    ApolloWeatherCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Network
)

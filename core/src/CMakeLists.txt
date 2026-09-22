# 纯底层可复用的架构层。RuntimeCore 先定义，供其他 core target 共享。
qt_add_library(ApolloRuntimeCore STATIC)
target_sources(ApolloRuntimeCore PRIVATE
    runtime/apollo_paths.h
    runtime/apollo_paths.cpp
    runtime/udev_monitor.h
    runtime/udev_monitor.cpp
    runtime/backlight_reading.h
    runtime/backlight_reading.cpp
)
set_target_properties(ApolloRuntimeCore PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(ApolloRuntimeCore PRIVATE Qt6::Core Qt6::Network PkgConfig::Udev)
target_include_directories(ApolloRuntimeCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ApolloWeatherMapCore STATIC)
target_sources(ApolloWeatherMapCore PRIVATE
    weather_map_provider.h
    weather_map_provider.cpp
)

set_target_properties(ApolloWeatherMapCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ApolloWeatherMapCore PRIVATE
    ApolloRuntimeCore
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6Keychain::Qt6Keychain
)
target_include_directories(ApolloWeatherMapCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ApolloWeatherCore STATIC)
target_sources(ApolloWeatherCore PRIVATE
    weather_types.h
    weather_types.cpp
    weather_calculator.h
    weather_calculator.cpp
    weather_cache.h
    weather_cache.cpp
    weather_climate_normals.h
    weather_climate_normals.cpp
    weather_normals_cache.h
    weather_normals_cache.cpp
    openmeteo_client.h
    openmeteo_client.cpp
    weather_backend.h
    weather_backend.cpp
)
set_target_properties(ApolloWeatherCore PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_link_libraries(ApolloWeatherCore PRIVATE Qt6::Core Qt6::Network)
target_include_directories(ApolloWeatherCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ApolloNiriCore STATIC)
target_sources(ApolloNiriCore PRIVATE
    niri_types.h
    niri_icon_lookup.h
    niri_icon_lookup.cpp
    niri_ipc_client.h
    niri_ipc_client.cpp
    niri_workspace_deriver.h
    niri_workspace_deriver.cpp
    niri_workspace_model.h
    niri_workspace_model.cpp
    niri_window_model.h
    niri_window_model.cpp
    niri_output_model.h
    niri_output_model.cpp
)

set_target_properties(ApolloNiriCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ApolloNiriCore PRIVATE
    Qt6::Core
    Qt6::Network
)
target_include_directories(ApolloNiriCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ApolloCavaCore STATIC)
target_sources(ApolloCavaCore PRIVATE
    audio_collector.h
    audio_collector.cpp
    audio_level_collector.h
    audio_level_collector.cpp
    audio_visual_analyzer.h
    audio_visual_analyzer.cpp
)

set_target_properties(ApolloCavaCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ApolloCavaCore PRIVATE
    Qt6::Core
    PkgConfig::Pipewire
)
target_include_directories(ApolloCavaCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

qt_add_library(ApolloMediaCore STATIC)
target_sources(ApolloMediaCore PRIVATE
    media_palette_backend.h
    media_palette_backend.cpp
)

set_target_properties(ApolloMediaCore PROPERTIES POSITION_INDEPENDENT_CODE ON)

target_link_libraries(ApolloMediaCore PRIVATE
    Qt6::Core
    Qt6::Gui
)
target_include_directories(ApolloMediaCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

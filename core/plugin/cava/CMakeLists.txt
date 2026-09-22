qt_add_library(ApolloCava SHARED)

set_target_properties(ApolloCava PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Cava
)

qt_add_qml_module(ApolloCava
    URI Apollo.Cava
    SOURCES
        src/cava_provider.h
        src/cava_provider.cpp
        src/audio_level_provider.h
        src/audio_level_provider.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Cava
)

target_include_directories(ApolloCava PUBLIC src)

target_link_libraries(ApolloCava PRIVATE
    ApolloCavaCore
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    PkgConfig::Cava
)

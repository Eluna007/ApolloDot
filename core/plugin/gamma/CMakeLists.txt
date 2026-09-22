find_package(Qt6 6.8 REQUIRED COMPONENTS WaylandClient DBus)
qt_add_library(ApolloGamma SHARED)
qt_add_qml_module(ApolloGamma
    URI Apollo.Gamma
    SOURCES src/gamma_backend.h src/gamma_backend.cpp src/gamma_curve.h src/gamma_curve.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Gamma
)
set_target_properties(ApolloGamma PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/Gamma
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
)
qt_generate_wayland_protocol_client_sources(ApolloGamma PRIVATE_CODE
    FILES "${CMAKE_CURRENT_SOURCE_DIR}/protocols/wlr-gamma-control-unstable-v1.xml")
target_include_directories(ApolloGamma PRIVATE src)
target_link_libraries(ApolloGamma PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::WaylandClient Qt6::DBus)

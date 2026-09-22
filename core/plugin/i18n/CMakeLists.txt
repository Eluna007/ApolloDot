qt_add_library(ApolloI18n SHARED)
add_dependencies(ApolloI18n search_catalog)

set_target_properties(ApolloI18n PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/I18n
)

qt_add_qml_module(ApolloI18n
    URI Apollo.I18n
    SOURCES
        src/i18n_manager.h
        src/i18n_manager.cpp
    OUTPUT_DIRECTORY ${APOLLO_QML_BUILD_DIR}/Apollo/I18n
)

file(GLOB_RECURSE APOLLO_TRANSLATION_SOURCES CONFIGURE_DEPENDS
    "${APOLLO_SOURCE_ROOT}/Common/*.js"
    "${APOLLO_SOURCE_ROOT}/Common/*.qml"
    "${APOLLO_SOURCE_ROOT}/Components/*.js"
    "${APOLLO_SOURCE_ROOT}/Components/*.qml"
    "${APOLLO_SOURCE_ROOT}/Modules/*.js"
    "${APOLLO_SOURCE_ROOT}/Modules/*.qml"
    "${APOLLO_SOURCE_ROOT}/Services/*.js"
    "${APOLLO_SOURCE_ROOT}/Services/*.qml"
    "${APOLLO_SOURCE_ROOT}/Widgets/*.js"
    "${APOLLO_SOURCE_ROOT}/Widgets/*.qml"
)
list(APPEND APOLLO_TRANSLATION_SOURCES
    "${APOLLO_SOURCE_ROOT}/core/plugin/keyboard/src/shortcut_recorder.cpp"
    "${APOLLO_SOURCE_ROOT}/AppShell.qml"
    "${APOLLO_SOURCE_ROOT}/shell.qml"
    "${APOLLO_SOURCE_ROOT}/tools/window-preview/Preview.qml"
)

# Qt 6.7+ otherwise scans every target, including tests and dependency headers.
# Earlier Qt versions already use the first target for source extraction.
set(APOLLO_TRANSLATION_TARGET_OPTIONS)
if(Qt6_VERSION VERSION_GREATER_EQUAL 6.7)
    list(APPEND APOLLO_TRANSLATION_TARGET_OPTIONS SOURCE_TARGETS ApolloI18n)
endif()

qt_add_translations(ApolloI18n
    ${APOLLO_TRANSLATION_TARGET_OPTIONS}
    SOURCES ${APOLLO_TRANSLATION_SOURCES}
    TS_FILES
        ${APOLLO_SOURCE_ROOT}/i18n/apollo_en_US.ts
    LUPDATE_OPTIONS -no-obsolete -source-language en_US
    RESOURCE_PREFIX "/i18n"
)
add_dependencies(update_translations search_catalog)

target_include_directories(ApolloI18n PUBLIC src)

target_link_libraries(ApolloI18n PRIVATE
    Qt6::Core
    Qt6::Qml
)

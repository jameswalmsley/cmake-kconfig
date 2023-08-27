set(PROJECT_ROOT        ${CMAKE_SOURCE_DIR})
set(KCONFIG_ROOT        ${PROJECT_ROOT}/Kconfig)
set(BUILD_CONFIG_DIR    ${PROJECT_ROOT}/configs)

include(cmake/extensions.cmake)
include(cmake/python.cmake)
include(cmake/kconfig.cmake)


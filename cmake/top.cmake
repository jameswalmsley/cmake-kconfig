set(PROJECT_ROOT ${CMAKE_SOURCE_DIR})
set(KCONFIG_ROOT ${CMAKE_SOURCE_DIR}/Kconfig)
set(BOARD_DIR ${CMAKE_SOURCE_DIR}/configs)

include(cmake/extensions.cmake)
include(cmake/python.cmake)
include(cmake/kconfig.cmake)


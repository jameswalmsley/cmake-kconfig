set(PROJECT_ROOT ${CMAKE_SOURCE_DIR})
set(KCONFIG_ROOT ${CMAKE_SOURCE_DIR}/Kconfig)
set(BOARD_DIR ${CMAKE_SOURCE_DIR}/configs)
set(AUTOCONF_H ${CMAKE_CURRENT_BINARY_DIR}/kconfig/include/generated/autoconf.h)

if(NOT DEFINED APPLICATION_SOURCE_DIR)
set(APPLICATION_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR} CACHE PATH
    "Application Source Directory"
)
endif()

if(NOT DEFINED APPLICATION_BINARY_DIR)
set(APPLICATION_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR} CACHE PATH
    "Application Binary Directory"
)
endif()

# Re-configure (Re-execute all CMakeLists.txt code) when autoconf.h changes
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${AUTOCONF_H})

include(cmake/extensions.cmake)
include(cmake/python.cmake)
include(cmake/kconfig.cmake)


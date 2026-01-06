cmake_minimum_required(VERSION 3.13)

project(kconfig-test
    VERSION     1.0
    DESCRIPTION "kconfig test project"
    LANGUAGES   C CXX
)

set(PROJECT_ROOT                ${CMAKE_SOURCE_DIR})
list(APPEND CMAKE_MODULE_PATH   ${PROJECT_ROOT}/cmake)

include(kconfig)

if(CONFIG_TEST_OPTION)
    message("Config test_option enabled")
endif()

if(CONFIG_TEST_1)
    add_executable(test1 test1.cpp)
    target_include_directories(test1 PUBLIC ${AUTOCONF_DIR})
endif()

if(CONFIG_TEST_2)
    add_executable(test2 test2.cpp)
    target_include_directories(test2 PUBLIC ${AUTOCONF_DIR})
endif()

# SPDX-License-Identifier: Apache-2.0

########################################################
# Table of contents
########################################################
# 2. Kconfig-aware extensions
# 2.1 *_if_kconfig
# 2.2 Misc
# 3. CMake-generic extensions
# 3.1. *_ifdef
# 3.2. *_ifndef
# 3.3. *_option compiler compatibility checks
# 3.4. Debugging CMake

# This function writes a dict to it's output parameter
# 'return_dict'. The dict has information about the parsed arguments,
#
# Usage:
#   get_parse_args(foo ${ARGN})
#   print(foo_STRIP_PREFIX) # foo_STRIP_PREFIX might be set to 1
function(get_parse_args return_dict)
    foreach(x ${ARGN})
        if(DEFINED single_argument)
            set(${single_argument} ${x} PARENT_SCOPE)
            unset(single_argument)
        else()
            if(x STREQUAL STRIP_PREFIX)
                set(${return_dict}_STRIP_PREFIX 1 PARENT_SCOPE)
            elseif(x STREQUAL NO_SPLIT)
                set(${return_dict}_NO_SPLIT 1 PARENT_SCOPE)
            elseif(x STREQUAL DELIMITER)
                set(single_argument ${return_dict}_DELIMITER)
            endif()
        endif()
    endforeach()
endfunction()

# 1.3 generate_inc_*

# These functions are useful if there is a need to generate a file
# that can be included into the application at build time. The file
# can also be compressed automatically when embedding it.
#
# See tests/application_development/gen_inc_file for an example of
# usage.
function(generate_inc_file
         source_file    # The source file to be converted to hex
         generated_file # The generated file
)
    add_custom_command(
            OUTPUT ${generated_file}
            COMMAND
            ${PYTHON_EXECUTABLE}
            ${PROJECT_ROOT}/scripts/build/file2hex.py
            ${ARGN} # Extra arguments are passed to file2hex.py
            --file ${source_file}
            > ${generated_file} # Does pipe redirection work on Windows?
            DEPENDS ${source_file}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
endfunction()

function(generate_inc_file_for_gen_target
         target          # The cmake target that depends on the generated file
         source_file     # The source file to be converted to hex
         generated_file  # The generated file
         gen_target      # The generated file target we depend on
         # Any additional arguments are passed on to file2hex.py
)
    generate_inc_file(${source_file} ${generated_file} ${ARGN})

    # Ensure 'generated_file' is generated before 'target' by creating a
    # dependency between the two targets

    add_dependencies(${target} ${gen_target})
endfunction()

function(generate_inc_file_for_target
         target          # The cmake target that depends on the generated file
         source_file     # The source file to be converted to hex
         generated_file  # The generated file
         # Any additional arguments are passed on to file2hex.py
)
    # Ensure 'generated_file' is generated before 'target' by creating a
    # 'custom_target' for it and setting up a dependency between the two
    # targets

    # But first create a unique name for the custom target
    generate_unique_target_name_from_filename(${generated_file} generated_target_name)

    add_custom_target(${generated_target_name} DEPENDS ${generated_file})
    generate_inc_file_for_gen_target(${target} ${source_file} ${generated_file} ${generated_target_name} ${ARGN})
endfunction()

########################################################
# 2. Kconfig-aware extensions
########################################################
#
# Kconfig is a configuration language developed for the Linux
# kernel. The below functions integrate CMake with Kconfig.
#
# 2.1 *_if_kconfig
#
# Functions for conditionally including directories and source files
# that have matching KConfig values.
#
# add_subdirectory_if_kconfig(serial)
# is the same as
# add_subdirectory_ifdef(CONFIG_SERIAL serial)
function(add_subdirectory_if_kconfig dir)
    string(TOUPPER config_${dir} UPPER_CASE_CONFIG)
    add_subdirectory_ifdef(${UPPER_CASE_CONFIG} ${dir})
endfunction()

function(target_sources_if_kconfig target scope item)
    get_filename_component(item_basename ${item} NAME_WE)
    string(TOUPPER CONFIG_${item_basename} UPPER_CASE_CONFIG)
    target_sources_ifdef(${UPPER_CASE_CONFIG} ${target} ${scope} ${item})
endfunction()

# 2.2 Misc
#
# import_kconfig(<prefix> <kconfig_fragment> [<keys>] [TARGET <target>])
#
# Parse a KConfig fragment (typically with extension .config) and
# introduce all the symbols that are prefixed with 'prefix' into the
# CMake namespace. List all created variable names in the 'keys'
# output variable if present.
#
# <prefix>          : symbol prefix of settings in the Kconfig fragment.
# <kconfig_fragment>: absolute path to the config fragment file.
# <keys>            : output variable which will be populated with variable
#                     names loaded from the kconfig fragment.
# TARGET <target>   : set all symbols on <target> instead of adding them to the
#                     CMake namespace.
function(import_kconfig prefix kconfig_fragment)
    cmake_parse_arguments(IMPORT_KCONFIG "" "TARGET" "" ${ARGN})
    file(
            STRINGS
            ${kconfig_fragment}
            DOT_CONFIG_LIST
            ENCODING "UTF-8"
    )

    foreach (LINE ${DOT_CONFIG_LIST})
        if("${LINE}" MATCHES "^(${prefix}[^=]+)=([ymn]|.+$)")
            # Matched a normal value assignment, like: CONFIG_NET_BUF=y
            # Note: if the value starts with 'y', 'm', or 'n', then we assume it's a
            # bool or tristate (we don't know the type from <kconfig_fragment> alone)
            # and we only match the first character. This is to align with Kconfiglib.
            set(CONF_VARIABLE_NAME "${CMAKE_MATCH_1}")
            set(CONF_VARIABLE_VALUE "${CMAKE_MATCH_2}")
        elseif("${LINE}" MATCHES "^# (${prefix}[^ ]+) is not set")
            # Matched something like: # CONFIG_FOO is not set
            # This is interpreted as: CONFIG_FOO=n
            set(CONF_VARIABLE_NAME "${CMAKE_MATCH_1}")
            set(CONF_VARIABLE_VALUE "n")
        else()
            # Ignore this line.
            # Note: we also ignore assignments which don't have the desired <prefix>.
            continue()
        endif()

        # If the provided value is n, then the corresponding CMake variable or
        # target property will be unset.
        if("${CONF_VARIABLE_VALUE}" STREQUAL "n")
            if(DEFINED IMPORT_KCONFIG_TARGET)
                set_property(TARGET ${IMPORT_KCONFIG_TARGET} PROPERTY "${CONF_VARIABLE_NAME}")
            else()
                unset("${CONF_VARIABLE_NAME}" PARENT_SCOPE)
            endif()
            list(REMOVE_ITEM keys "${CONF_VARIABLE_NAME}")
            continue()
        endif()

        # Otherwise, the variable/property will be set to the provided value.
        # For string values, we also remove the surrounding quotation marks.
        if("${CONF_VARIABLE_VALUE}" MATCHES "^\"(.*)\"$")
            set(CONF_VARIABLE_VALUE ${CMAKE_MATCH_1})
        endif()

        if(DEFINED IMPORT_KCONFIG_TARGET)
            set_property(TARGET ${IMPORT_KCONFIG_TARGET} PROPERTY "${CONF_VARIABLE_NAME}" "${CONF_VARIABLE_VALUE}")
        else()
            set("${CONF_VARIABLE_NAME}" "${CONF_VARIABLE_VALUE}" PARENT_SCOPE)
        endif()
        list(APPEND keys "${CONF_VARIABLE_NAME}")
    endforeach()

    if(DEFINED IMPORT_KCONFIG_TARGET)
        set_property(TARGET ${IMPORT_KCONFIG_TARGET} PROPERTY "kconfigs" "${keys}")
    endif()

    list(LENGTH IMPORT_KCONFIG_UNPARSED_ARGUMENTS unparsed_length)
    if(unparsed_length GREATER 0)
        if(unparsed_length GREATER 1)
            # Two mandatory arguments and one optional, anything after that is an error.
            list(GET IMPORT_KCONFIG_UNPARSED_ARGUMENTS 1 first_invalid)
            message(FATAL_ERROR "Unexpected argument after '<keys>': import_kconfig(... ${first_invalid})")
        endif()
        set(${IMPORT_KCONFIG_UNPARSED_ARGUMENTS} "${keys}" PARENT_SCOPE)
    endif()
endfunction()

########################################################
# 3. CMake-generic extensions
########################################################
#
# These functions extend the CMake API.
# Primarily they work around limitations in the CMake
# language to allow cleaner build scripts.

# 3.1. *_ifdef
#
# Functions for conditionally executing CMake functions with oneliners
# e.g.
# "<function-name>_ifdef(CONDITION args)"
# Becomes
# """
# if(CONDITION)
#     <function-name>(args)
# endif()
# """
#
# ifdef functions are added on an as-need basis. See
# https://cmake.org/cmake/help/latest/manual/cmake-commands.7.html for
# a list of available functions.
function(add_subdirectory_ifdef feature_toggle dir)
    if(${${feature_toggle}})
        add_subdirectory(${dir})
    endif()
endfunction()

function(target_sources_ifdef feature_toggle target scope item)
    if(${${feature_toggle}})
        target_sources(${target} ${scope} ${item} ${ARGN})
    endif()
endfunction()

function(target_compile_definitions_ifdef feature_toggle target scope item)
    if(${${feature_toggle}})
        target_compile_definitions(${target} ${scope} ${item} ${ARGN})
    endif()
endfunction()

function(target_include_directories_ifdef feature_toggle target scope item)
    if(${${feature_toggle}})
        target_include_directories(${target} ${scope} ${item} ${ARGN})
    endif()
endfunction()

function(target_link_libraries_ifdef feature_toggle target item)
    if(${${feature_toggle}})
        target_link_libraries(${target} ${item} ${ARGN})
    endif()
endfunction()

function(add_compile_option_ifdef feature_toggle option)
    if(${${feature_toggle}})
        add_compile_options(${option})
    endif()
endfunction()

function(target_compile_option_ifdef feature_toggle target scope option)
    if(${feature_toggle})
        target_compile_options(${target} ${scope} ${option})
    endif()
endfunction()

function(target_cc_option_ifdef feature_toggle target scope option)
    if(${feature_toggle})
        target_cc_option(${target} ${scope} ${option})
    endif()
endfunction()

macro(list_append_ifdef feature_toggle list)
    if(${${feature_toggle}})
        list(APPEND ${list} ${ARGN})
    endif()
endmacro()

# 3.2. *_ifndef
# See 3.1 *_ifdef
function(set_ifndef variable value)
    if(NOT ${variable})
        set(${variable} ${value} ${ARGN} PARENT_SCOPE)
    endif()
endfunction()

function(add_subdirectory_ifndef feature_toggle source_dir)
    if(NOT ${feature_toggle})
        add_subdirectory(${source_dir} ${ARGN})
    endif()
endfunction()

function(target_sources_ifndef feature_toggle target scope item)
    if(NOT ${feature_toggle})
        target_sources(${target} ${scope} ${item} ${ARGN})
    endif()
endfunction()

function(target_compile_definitions_ifndef feature_toggle target scope item)
    if(NOT ${feature_toggle})
        target_compile_definitions(${target} ${scope} ${item} ${ARGN})
    endif()
endfunction()

function(target_include_directories_ifndef feature_toggle target scope item)
    if(NOT ${feature_toggle})
        target_include_directories(${target} ${scope} ${item} ${ARGN})
    endif()
endfunction()

function(target_link_libraries_ifndef feature_toggle target item)
    if(NOT ${feature_toggle})
        target_link_libraries(${target} ${item} ${ARGN})
    endif()
endfunction()

function(add_compile_option_ifndef feature_toggle option)
    if(NOT ${feature_toggle})
        add_compile_options(${option})
    endif()
endfunction()

function(target_compile_option_ifndef feature_toggle target scope option)
    if(NOT ${feature_toggle})
        target_compile_options(${target} ${scope} ${option})
    endif()
endfunction()

function(target_cc_option_ifndef feature_toggle target scope option)
    if(NOT ${feature_toggle})
        target_cc_option(${target} ${scope} ${option})
    endif()
endfunction()

macro(list_append_ifndef feature_toggle list)
    if(NOT ${feature_toggle})
        list(APPEND ${list} ${ARGN})
    endif()
endmacro()

# 3.3. *_option Compiler-compatibility checks
#
# Utility functions for silently omitting compiler flags when the
# compiler lacks support. *_cc_option was ported from KBuild, see
# cc-option in
# https://www.kernel.org/doc/Documentation/kbuild/makefiles.txt

# Writes 1 to the output variable 'ok' for the language 'lang' if
# the flag is supported, otherwise writes 0.
#
# lang must be C or CXX
#
# TODO: Support ASM
#
# Usage:
#
# check_compiler_flag(C "-Wall" my_check)
# print(my_check) # my_check is now 1
function(check_compiler_flag lang option ok)
    if(NOT DEFINED CMAKE_REQUIRED_QUIET)
        set(CMAKE_REQUIRED_QUIET 1)
    endif()

    string(MAKE_C_IDENTIFIER
        check${option}_${lang}_${CMAKE_REQUIRED_FLAGS}
        ${ok}
    )

    if(${lang} STREQUAL C)
        check_c_compiler_flag("${option}" ${${ok}})
    else()
        check_cxx_compiler_flag("${option}" ${${ok}})
    endif()

    if(${${${ok}}})
        set(ret 1)
    else()
        set(ret 0)
    endif()

    set(${ok} ${ret} PARENT_SCOPE)
endfunction()

function(target_cc_option target scope option)
    target_cc_option_fallback(${target} ${scope} ${option} "")
endfunction()

# Support an optional second option for when the first option is not
# supported.
function(target_cc_option_fallback target scope option1 option2)
    if(CONFIG_CPLUSPLUS)
        foreach(lang C CXX)
            # For now, we assume that all flags that apply to C/CXX also
            # apply to ASM.
            check_compiler_flag(${lang} ${option1} check)
            if(${check})
                target_compile_options(${target} ${scope}
                    $<$<COMPILE_LANGUAGE:${lang}>:${option1}>
                    $<$<COMPILE_LANGUAGE:ASM>:${option1}>
                )
            elseif(option2)
                target_compile_options(${target} ${scope}
                    $<$<COMPILE_LANGUAGE:${lang}>:${option2}>
                    $<$<COMPILE_LANGUAGE:ASM>:${option2}>
                )
            endif()
        endforeach()
    else()
        check_compiler_flag(C ${option1} check)
        if(${check})
            target_compile_options(${target} ${scope} ${option1})
        elseif(option2)
            target_compile_options(${target} ${scope} ${option2})
        endif()
    endif()
endfunction()

function(target_ld_options target scope)
    get_parse_args(args ${ARGN})
    list(REMOVE_ITEM ARGN NO_SPLIT)

    foreach(option ${ARGN})
        if(args_NO_SPLIT)
            set(option ${ARGN})
        endif()
        string(JOIN "" check_identifier "check" ${option})
        string(MAKE_C_IDENTIFIER ${check_identifier} check)

        set(SAVED_CMAKE_REQUIRED_FLAGS ${CMAKE_REQUIRED_FLAGS})
        string(JOIN " " CMAKE_REQUIRED_FLAGS ${CMAKE_REQUIRED_FLAGS} ${option})
        check_compiler_flag(C "" ${check})
        set(CMAKE_REQUIRED_FLAGS ${SAVED_CMAKE_REQUIRED_FLAGS})

        target_link_libraries_ifdef(${check} ${target} ${scope} ${option})

        if(args_NO_SPLIT)
            break()
        endif()
    endforeach()
endfunction()

# 3.3.1 Toolchain integration
#
# 'toolchain_parse_make_rule' is a function that parses the output of
# 'gcc -M'.
#
# The argument 'input_file' is in input parameter with the path to the
# file with the dependency information.
#
# The argument 'include_files' is an output parameter with the result
# of parsing the include files.
function(toolchain_parse_make_rule input_file include_files)
    file(STRINGS ${input_file} input)

    # The file is formatted like this:
    # empty_file.o: misc/empty_file.c \
    # nrf52840dk_nrf52840/nrf52840dk_nrf52840.dts \
    # nrf52840_qiaa.dtsi

    # The dep file will contain `\` for line continuation.
    # This results in `\;` which is then treated a the char `;` instead of
    # the element separator, so let's get the pure `;` back.
    string(REPLACE "\;" ";" input_as_list ${input})

    # Pop the first line and treat it specially
    list(POP_FRONT input_as_list first_input_line)
    string(FIND ${first_input_line} ": " index)
    math(EXPR j "${index} + 2")
    string(SUBSTRING ${first_input_line} ${j} -1 first_include_file)

    # Remove whitespace before and after filename and convert to CMake path.
    string(STRIP "${first_include_file}" first_include_file)
    file(TO_CMAKE_PATH "${first_include_file}" first_include_file)
    set(result "${first_include_file}")

    # Remove whitespace before and after filename and convert to CMake path.
    foreach(file ${input_as_list})
        string(STRIP "${file}" file)
        file(TO_CMAKE_PATH "${file}" file)
        list(APPEND result "${file}")
    endforeach()

    set(${include_files} ${result} PARENT_SCOPE)
endfunction()

# 3.4. Debugging CMake

# Usage:
#     print(BOARD)
#
# will print: "BOARD: nrf52_pca10040"
function(print arg)
    message(STATUS "${arg}: ${${arg}}")
endfunction()

# Usage:
#     assert(TOOLCHAIN_VARIANT "TOOLCHAIN_VARIANT not set.")
#
# will cause a FATAL_ERROR and print an error message if the first
# expression is false
macro(assert test comment)
    if(NOT ${test})
        message(FATAL_ERROR "Assertion failed: ${comment}")
    endif()
endmacro()

# Usage:
#     assert_not(OBSOLETE_VAR "OBSOLETE_VAR has been removed; use NEW_VAR instead")
#
# will cause a FATAL_ERROR and print an error message if the first
# expression is true
macro(assert_not test comment)
    if(${test})
        message(FATAL_ERROR "Assertion failed: ${comment}")
    endif()
endmacro()

# Usage:
#     assert_exists(CMAKE_READELF)
#
# will cause a FATAL_ERROR if there is no file or directory behind the
# variable
macro(assert_exists var)
    if(NOT EXISTS ${${var}})
        message(FATAL_ERROR "No such file or directory: ${var}: '${${var}}'")
    endif()
endmacro()

# 3.5. File system management
function(generate_unique_target_name_from_filename filename target_name)
    get_filename_component(basename ${filename} NAME)
    string(REPLACE "." "_" x ${basename})
    string(REPLACE "@" "_" x ${x})

    string(MD5 unique_chars ${filename})

    set(${target_name} gen_${x}_${unique_chars} PARENT_SCOPE)
endfunction()
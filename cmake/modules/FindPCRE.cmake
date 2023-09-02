#.rst:
# FindPCRE
# --------
# Finds the PCRECPP library
#
# This will define the following targets:
#
#   PCRE::PCRECPP - The PCRECPP library
#   PCRE::PCRE    - The PCRE library

if(NOT PCRE::pcre)

  include(cmake/scripts/common/ModuleHelpers.cmake)

  set(MODULE_LC pcre)

  SETUP_BUILD_VARS()

  # Check for existing PCRE. If version >= PCRE-VERSION file version, dont build
  find_package(PCRE CONFIG QUIET)

  if((PCRE_VERSION VERSION_LESS ${${MODULE}_VER} AND ENABLE_INTERNAL_PCRE) OR
     ((CORE_SYSTEM_NAME STREQUAL linux OR CORE_SYSTEM_NAME STREQUAL freebsd) AND ENABLE_INTERNAL_PCRE))

    set(PCRE_VERSION ${${MODULE}_VER})
    set(PCRE_DEBUG_POSTFIX d)

    set(patches "${CORE_SOURCE_DIR}/tools/depends/target/${MODULE_LC}/001-all-cmakeconfig.patch"
                "${CORE_SOURCE_DIR}/tools/depends/target/${MODULE_LC}/002-all-enable_docs_pc.patch"
                "${CORE_SOURCE_DIR}/tools/depends/target/${MODULE_LC}/003-all-postfix.patch"
                "${CORE_SOURCE_DIR}/tools/depends/target/${MODULE_LC}/004-win-pdb.patch"
                "${CORE_SOURCE_DIR}/tools/depends/target/${MODULE_LC}/jit_aarch64.patch")

    if(CORE_SYSTEM_NAME STREQUAL darwin_embedded)
      list(APPEND patches "${CORE_SOURCE_DIR}/tools/depends/target/${MODULE_LC}/tvos-bitcode-fix.patch"
                          "${CORE_SOURCE_DIR}/tools/depends/target/${MODULE_LC}/ios-clear_cache.patch")
    endif()

    generate_patchcommand("${patches}")

    set(CMAKE_ARGS -DPCRE_NEWLINE=ANYCRLF
                   -DPCRE_NO_RECURSE=ON
                   -DPCRE_MATCH_LIMIT_RECURSION=1500
                   -DPCRE_SUPPORT_JIT=ON
                   -DPCRE_SUPPORT_PCREGREP_JIT=ON
                   -DPCRE_SUPPORT_UTF=ON
                   -DPCRE_SUPPORT_UNICODE_PROPERTIES=ON
                   -DPCRE_SUPPORT_LIBZ=OFF
                   -DPCRE_SUPPORT_LIBBZ2=OFF
                   -DPCRE_BUILD_PCREGREP=OFF
                   -DPCRE_BUILD_TESTS=OFF)

    if(WIN32 OR WINDOWS_STORE)
      list(APPEND CMAKE_ARGS -DINSTALL_MSVC_PDB=ON)
    elseif(CORE_SYSTEM_NAME STREQUAL android)
      # CMake CheckFunctionExists incorrectly detects strtoq for android
      list(APPEND CMAKE_ARGS -DHAVE_STRTOQ=0)
    endif()

    # populate PCRECPP lib without a separate module
    if(NOT CORE_SYSTEM_NAME MATCHES windows)
      # Non windows platforms have a lib prefix for the lib artifact
      set(_libprefix "lib")
    endif()
    # regex used to get platform extension (eg lib for windows, .a for unix)
    string(REGEX REPLACE "^.*\\." "" _LIBEXT ${${MODULE}_BYPRODUCT})
    set(PCRECPP_LIBRARY_DEBUG ${DEP_LOCATION}/lib/${_libprefix}pcrecpp${${MODULE}_DEBUG_POSTFIX}.${_LIBEXT})
    set(PCRECPP_LIBRARY_RELEASE ${DEP_LOCATION}/lib/${_libprefix}pcrecpp.${_LIBEXT})

    BUILD_DEP_TARGET()

  else()
    if(NOT TARGET PCRE::pcre)
      if(PKG_CONFIG_FOUND)
        pkg_check_modules(PC_PCRE pcre pcrecpp QUIET)
      endif()

      find_path(PCRE_INCLUDE_DIR pcrecpp.h
                                 PATHS ${PC_PCRE_INCLUDEDIR})
      find_library(PCRECPP_LIBRARY_RELEASE NAMES pcrecpp
                                           PATHS ${PC_PCRE_LIBDIR})
      find_library(PCRE_LIBRARY_RELEASE NAMES pcre
                                        PATHS ${PC_PCRE_LIBDIR})
      find_library(PCRECPP_LIBRARY_DEBUG NAMES pcrecppd
                                         PATHS ${PC_PCRE_LIBDIR})
      find_library(PCRE_LIBRARY_DEBUG NAMES pcred
                                      PATHS ${PC_PCRE_LIBDIR})
      set(PCRE_VERSION ${PC_PCRE_VERSION})
    else()

      # Populate variables for find_package_handle_standard_args usage
      get_target_property(_PCRE_CONFIGURATIONS PCRE::pcre IMPORTED_CONFIGURATIONS)
      foreach(_pcre_config IN LISTS _PCRE_CONFIGURATIONS)
        # Just set to RELEASE var so select_library_configurations can continue to work its magic
        if((NOT ${_pcre_config} STREQUAL "RELEASE") AND
           (NOT ${_pcre_config} STREQUAL "DEBUG"))
          get_target_property(PCRE_LIBRARY_RELEASE PCRE::pcre IMPORTED_LOCATION_${_pcre_config})
        else()
          get_target_property(PCRE_LIBRARY_${_pcre_config} PCRE::pcre IMPORTED_LOCATION_${_pcre_config})
        endif()
      endforeach()

      get_target_property(_PCRECPP_CONFIGURATIONS PCRE::pcrecpp IMPORTED_CONFIGURATIONS)
      foreach(_pcrecpp_config IN LISTS _PCRECPP_CONFIGURATIONS)
        # Just set to RELEASE var so select_library_configurations can continue to work its magic
        if((NOT ${_pcrecpp_config} STREQUAL "RELEASE") AND
           (NOT ${_pcrecpp_config} STREQUAL "DEBUG"))
          get_target_property(PCRECPP_LIBRARY_RELEASE PCRE::pcrecpp IMPORTED_LOCATION_${_pcrecpp_config})
        else()
          get_target_property(PCRECPP_LIBRARY_${_pcrecpp_config} PCRE::pcrecpp IMPORTED_LOCATION_${_pcrecpp_config})
        endif()
      endforeach()

      # ToDo: patch PCRE cmake to include includedir in config file
      find_path(PCRE_INCLUDE_DIR pcrecpp.h
                                 PATHS ${PC_PCRE_INCLUDEDIR})

      set_target_properties(PCRE::pcre PROPERTIES
                                       INTERFACE_INCLUDE_DIRECTORIES "${PCRE_INCLUDE_DIR}")
      set_target_properties(PCRE::pcrecpp PROPERTIES
                                          INTERFACE_INCLUDE_DIRECTORIES "${PCRE_INCLUDE_DIR}")
    endif()
  endif()

  if(TARGET PCRE::pcre)
    get_target_property(PCRE_INCLUDE_DIR PCRE::pcre INTERFACE_INCLUDE_DIRECTORIES)
  endif()

  include(SelectLibraryConfigurations)
  select_library_configurations(PCRECPP)
  select_library_configurations(PCRE)

  include(FindPackageHandleStandardArgs)
  find_package_handle_standard_args(PCRE
                                    REQUIRED_VARS PCRECPP_LIBRARY PCRE_LIBRARY PCRE_INCLUDE_DIR
                                    VERSION_VAR PCRE_VERSION)

  if(PCRE_FOUND)
    if(NOT TARGET PCRE::pcre)
      add_library(PCRE::pcre UNKNOWN IMPORTED)
      if(PCRE_LIBRARY_RELEASE)
        set_target_properties(PCRE::pcre PROPERTIES
                                         IMPORTED_CONFIGURATIONS RELEASE
                                         IMPORTED_LOCATION_RELEASE "${PCRE_LIBRARY_RELEASE}")
      endif()
      if(PCRE_LIBRARY_DEBUG)
        set_target_properties(PCRE::pcre PROPERTIES
                                         IMPORTED_CONFIGURATIONS DEBUG
                                         IMPORTED_LOCATION_DEBUG "${PCRE_LIBRARY_DEBUG}")
      endif()
      set_target_properties(PCRE::pcre PROPERTIES
                                       INTERFACE_INCLUDE_DIRECTORIES "${PCRE_INCLUDE_DIR}")
    endif()
    if(NOT TARGET PCRE::pcrecpp)
      add_library(PCRE::pcrecpp UNKNOWN IMPORTED)
      if(PCRECPP_LIBRARY_RELEASE)
        set_target_properties(PCRE::pcrecpp PROPERTIES
                                            IMPORTED_CONFIGURATIONS RELEASE
                                            IMPORTED_LOCATION_RELEASE "${PCRECPP_LIBRARY_RELEASE}")
      endif()
      if(PCRECPP_LIBRARY_DEBUG)
        set_target_properties(PCRE::pcrecpp PROPERTIES
                                            IMPORTED_CONFIGURATIONS DEBUG
                                            IMPORTED_LOCATION_DEBUG "${PCRECPP_LIBRARY_DEBUG}")
      endif()
      set_target_properties(PCRE::pcrecpp PROPERTIES
                                          INTERFACE_INCLUDE_DIRECTORIES "${PCRE_INCLUDE_DIR}")
    endif()

    # Wee need to explicitly add this define. The cmake config does not propagate this info
    if(WIN32)
      set_property(TARGET PCRE::pcre APPEND PROPERTY
                                            INTERFACE_COMPILE_DEFINITIONS "PCRE_STATIC=1")
      set_property(TARGET PCRE::pcrecpp APPEND PROPERTY
                                               INTERFACE_COMPILE_DEFINITIONS "PCRE_STATIC=1")
    endif()

    if(TARGET pcre)
      add_dependencies(PCRE::pcre pcre)
      add_dependencies(PCRE::pcrecpp pcre)
    endif()

    set_property(GLOBAL APPEND PROPERTY INTERNAL_DEPS_PROP PCRE::pcre)
    set_property(GLOBAL APPEND PROPERTY INTERNAL_DEPS_PROP PCRE::pcrecpp)
  endif()
endif()

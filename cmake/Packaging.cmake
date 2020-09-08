
set(linux_supported_packaging_systems
  DEB
  RPM
  TGZ
)
if("${CMAKE_SYSTEM_NAME}" STREQUAL "Linux")
  set(PLATFORM_POSIX 1)
  set(PLATFORM_LINUX 1)
elseif("${CMAKE_SYSTEM_NAME}" STREQUAL "Darwin")
  set(PLATFORM_POSIX 1)
  set(PLATFORM_MACOS 1)
elseif("${CMAKE_SYSTEM_NAME}" STREQUAL "Windows")
  set(PLATFORM_WINDOWS 1)
else()
  message(FATAL_ERROR "Unrecognized platform")
endif()

function(overwrite_cache_variable variable_name type value)
  get_property(current_help_string CACHE "${variable_name}" PROPERTY HELPSTRING)
  if(NOT DEFINED current_help_string)
    set(current_help_string "No description")
  endif()
  list(APPEND cache_args "CACHE" "${type}" "${current_help_string}")
  set("${variable_name}" "${value}" ${cache_args} FORCE)
endfunction()

function(identifyPackagingSystem)
  if(NOT PACKAGING_SYSTEM)
      identifyPackagingSystemFromPlatform()
  endif()

  if(DEFINED PLATFORM_LINUX)
    list (FIND linux_supported_packaging_systems "${PACKAGING_SYSTEM}" _index)
    if (NOT ${_index} GREATER -1)
      message(WARNING "Selected an unsupported packaging system, please choose from this list: ${linux_supported_packaging_systems}")
    endif()
  endif()

  findPackagingTool()
endfunction()

function(identifyPackagingSystemFromPlatform)
  if(DEFINED PLATFORM_LINUX)
    find_program(lsb_release_exec lsb_release)
    if(NOT "${lsb_release_exec}" STREQUAL "lsb_release_exec_NOTFOUND")
      execute_process(COMMAND ${lsb_release_exec} -is
                      OUTPUT_VARIABLE lsb_release_id_short
                      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    else()
      message(WARNING "lsb_release NOT FOUND")
    endif()
    set(deb_distros
      Ubuntu
      Debian
    )
    set(rpm_distros
      Fedora
      CentOS
    )
    message(STATUS "Linux Standard Base: ${lsb_release_id_short}")
    list (FIND deb_distros "${lsb_release_id_short}" _index_deb)
    list (FIND rpm_distros "${lsb_release_id_short}" _index_rpm)
    if (${_index_deb} GREATER -1)
        set(platform_packaging_system "DEB")
    elseif(_index_rpm GREATER -1)
      set(platform_packaging_system "RPM")
    else()
      set(platform_packaging_system "TGZ")
      message(WARNING
        "Failed to identify Linux flavor, either lsb_release is missing or we couldn't identify your distro.\n"
        "The package target will now generate TGZ, if you want to generate native packages please install lsb_release, "
        "or choose a different packaging system through the CMake variable PACKAGING_SYSTEM; available values are DEB, RPM"
      )
    endif()
  endif()
  overwrite_cache_variable("PACKAGING_SYSTEM" "STRING" "${platform_packaging_system}")
endfunction()

function(findPackagingTool)
  if(PACKAGING_SYSTEM STREQUAL "DEB")
    unset(PACKAGING_TOOL_PATH_INTERNAL CACHE)
    unset(deb_packaging_tool CACHE)
    find_program(deb_packaging_tool dpkg)

    if("${deb_packaging_tool}" STREQUAL "deb_packaging_tool-NOTFOUND")
      message(WARNING "Packaging tool dpkg needed to create DEB packages has not been found, please install it if you want to create packages")
    endif()
  elseif(PACKAGING_SYSTEM STREQUAL "RPM")
    unset(PACKAGING_TOOL_PATH_INTERNAL CACHE)
    unset(rpm_packaging_tool CACHE)
    find_program(rpm_packaging_tool rpmbuild)
    if("${rpm_packaging_tool}" STREQUAL "rpm_packaging_tool-NOTFOUND")
      message(WARNING "Packaging tool rpmbuild needed to create RPM packages has not been found, please install it if you want to create packages")
    endif()
  endif()
endfunction()

function(generatePackageTargets)
    identifyPackagingSystem()
    overwrite_cache_variable(CPACK_GENERATOR "STRING" "${PACKAGING_SYSTEM}")
    message(STATUS "CPACK_GENERATOR ${CPACK_GENERATOR}")
    if(NOT CPACK_GENERATOR STREQUAL "DEB" AND NOT CPACK_GENERATOR STREQUAL "RPM")
        set(CPACK_STRIP_FILES ON)
    endif()

    if(CPACK_GENERATOR STREQUAL "TGZ")
        set(CPACK_INCLUDE_TOPLEVEL_DIRECTORY 0)
        set(CPACK_SET_DESTDIR ON)
    endif()
    if(CPACK_GENERATOR STREQUAL "DEB")
        message(STATUS "Generating Deb package")
        set(CPACK_DEBIAN_PACKAGE_NAME "nghttp2")
        set(CPACK_DEBIAN_PACKAGE_PRIORITY "extra")
        set(CPACK_DEBIAN_PACKAGE_SECTION "default")
        set(CPACK_DEB_COMPONENT_INSTALL ON)
        set(CPACK_DEBIAN_DEBUGINFO_PACKAGE ON)
        set(CPACK_DEBIAN_OSQUERY_PACKAGE_NAME ${CPACK_PACKAGE_NAME})
        set(CPACK_DEBIAN_PACKAGE_RELEASE "${OSQUERY_PACKAGE_RELEASE}")
        set(CPACK_DEBIAN_OSQUERY_FILE_NAME "${CPACK_PACKAGE_NAME}_${CPACK_PACKAGE_VERSION}.amd64.deb")
        set(CPACK_DEBIAN_PACKAGE_HOMEPAGE "https://nghttp2.org")
        set(CPACK_BINARY_DEB "ON")
    elseif(CPACK_GENERATOR STREQUAL "RPM")
        message(STATUS "Generating Rpm package")
        set(CPACK_RPM_PACKAGE_GROUP "default")
        set(CPACK_RPM_DEBUGINFO_PACKAGE ON)
        set(CPACK_RPM_PACKAGE_AUTOREQPROV ON)
        set(CPACK_RPM_PACKAGE_PROVIDES "nghttp2, libnghttp2")
    else()
        message(FATAL_ERROR "Unsupported platform")
    endif()
endfunction()

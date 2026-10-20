# Installation-only machine-code archives. The original targets keep LTO and
# remain the only inputs to libLLVM, other shared libraries, and compiler tools.
include_guard(GLOBAL)
option(PROCURSUS_NATIVE_STATIC_ARCHIVES "Build native public archive copies" OFF)

function(procursus_native_target original)
  set(native "procursus-native-${original}")
  if(TARGET "${native}")
    return()
  endif()
  get_target_property(kind "${original}" TYPE)
  if(NOT kind MATCHES "^(STATIC|OBJECT)_LIBRARY$")
    message(FATAL_ERROR "Unsupported native archive input: ${original} (${kind})")
  endif()
  get_target_property(source_dir "${original}" SOURCE_DIR)
  get_target_property(binary_dir "${original}" BINARY_DIR)
  get_target_property(sources "${original}" SOURCES)
  set(native_sources)
  foreach(source IN LISTS sources)
    if(source MATCHES "^\\$<TARGET_OBJECTS:([^>]+)>$")
      set(object_target "${CMAKE_MATCH_1}")
      procursus_native_target("${object_target}")
      list(APPEND native_sources "$<TARGET_OBJECTS:procursus-native-${object_target}>")
    elseif(source MATCHES "\\$<")
      list(APPEND native_sources "${source}")
    else()
      if(IS_ABSOLUTE "${source}")
        set(absolute "${source}")
      elseif(EXISTS "${source_dir}/${source}")
        set(absolute "${source_dir}/${source}")
      else()
        # CMake also accepts relative names whose generated-source properties
        # were attached to the absolute binary path (lld's VCSVersion.inc).
        # Only query that path for absent source files: querying an unrelated
        # binary path creates a source entry and changes relative resolution.
        get_source_file_property(binary_generated "${binary_dir}/${source}"
          DIRECTORY "${source_dir}" GENERATED)
        if(binary_generated)
          set(absolute "${binary_dir}/${source}")
        else()
          set(absolute "${source_dir}/${source}")
        endif()
      endif()
      list(APPEND native_sources "${absolute}")
      # Object libraries may originate in another directory. Preserve source
      # properties there as well as the original target's compile properties.
      if(NOT source_dir STREQUAL CMAKE_CURRENT_SOURCE_DIR)
        foreach(property GENERATED HEADER_FILE_ONLY LANGUAGE EXTERNAL_OBJECT
                         COMPILE_FLAGS COMPILE_OPTIONS COMPILE_DEFINITIONS
                         INCLUDE_DIRECTORIES OBJECT_DEPENDS
                         SKIP_PRECOMPILE_HEADERS SKIP_UNITY_BUILD_INCLUSION)
          get_source_file_property(value "${absolute}" DIRECTORY "${source_dir}" "${property}")
          if(NOT value STREQUAL "NOTFOUND")
            set_source_files_properties("${absolute}" PROPERTIES "${property}" "${value}")
          endif()
        endforeach()
      endif()
    endif()
  endforeach()
  if(kind STREQUAL "OBJECT_LIBRARY")
    add_library("${native}" OBJECT EXCLUDE_FROM_ALL ${native_sources})
  else()
    add_library("${native}" STATIC EXCLUDE_FROM_ALL ${native_sources})
    set_target_properties("${native}" PROPERTIES
      ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/procursus-native"
      OUTPUT_NAME "${original}")
  endif()
  # These expressions observe properties added by callers after llvm_add_library
  # returns. Native copies are never added to LLVM's component/export lists.
  foreach(property INCLUDE_DIRECTORIES SYSTEM_INCLUDE_DIRECTORIES
                   COMPILE_DEFINITIONS COMPILE_OPTIONS)
    set_property(TARGET "${native}" PROPERTY "${property}"
      "$<TARGET_PROPERTY:${original},${property}>")
  endforeach()
  # A nested object library can be copied by an archive in its parent (BLAKE3).
  # Its automatic current-directory includes are not target properties.
  get_directory_property(include_current DIRECTORY "${source_dir}"
    DEFINITION CMAKE_INCLUDE_CURRENT_DIR)
  if(include_current AND NOT source_dir STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    target_include_directories("${native}" BEFORE PRIVATE "${binary_dir}" "${source_dir}")
  endif()
  # add_compile_definitions() is directory state, not part of the target's
  # COMPILE_DEFINITIONS property (notably SWIFT_COMPATIBILITY56/PACKS).
  get_directory_property(directory_definitions DIRECTORY "${source_dir}" COMPILE_DEFINITIONS)
  set_property(TARGET "${native}" APPEND PROPERTY COMPILE_DEFINITIONS ${directory_definitions})
  foreach(property COMPILE_FLAGS COMPILE_FEATURES C_STANDARD C_STANDARD_REQUIRED
                   C_EXTENSIONS CXX_STANDARD CXX_STANDARD_REQUIRED CXX_EXTENSIONS
                   POSITION_INDEPENDENT_CODE OSX_ARCHITECTURES LINKER_LANGUAGE
                   C_VISIBILITY_PRESET CXX_VISIBILITY_PRESET VISIBILITY_INLINES_HIDDEN)
    get_target_property(value "${original}" "${property}")
    if(NOT value STREQUAL "value-NOTFOUND")
      set_property(TARGET "${native}" PROPERTY "${property}" "${value}")
    endif()
  endforeach()
  set_property(TARGET "${native}" PROPERTY INTERPROCEDURAL_OPTIMIZATION FALSE)
  target_compile_options("${native}" PRIVATE -fno-lto)
  target_link_libraries("${native}" PRIVATE "$<TARGET_PROPERTY:${original},LINK_LIBRARIES>")
  get_target_property(dependencies "${original}" MANUALLY_ADDED_DEPENDENCIES)
  if(dependencies)
    add_dependencies("${native}" ${dependencies})
  endif()
endfunction()

function(procursus_native_archive original)
  procursus_native_target("${original}")
  add_dependencies(procursus-native-static "procursus-native-${original}")
  install(FILES "$<TARGET_FILE:procursus-native-${original}>"
    DESTINATION "lib${LLVM_LIBDIR_SUFFIX}"
    RENAME "$<TARGET_FILE_NAME:${original}>"
    COMPONENT procursus-native-static EXCLUDE_FROM_ALL)
endfunction()

function(procursus_register_native_archive original)
  if(NOT PROCURSUS_NATIVE_STATIC_ARCHIVES)
    return()
  endif()
  get_target_property(kind "${original}" TYPE)
  if(NOT kind STREQUAL "STATIC_LIBRARY" OR
     NOT original MATCHES "^(LLVM|clang|libclang|Fortran|FIR|flang|lld|Polly)")
    return()
  endif()
  if(NOT TARGET procursus-native-static)
    add_custom_target(procursus-native-static)
  endif()
  # Run in the defining directory after its caller has set feature options.
  cmake_language(EVAL CODE
    "cmake_language(DEFER CALL procursus_native_archive [[${original}]])")
endfunction()

function(procursus_register_native_swift_target original)
  if(PROCURSUS_NATIVE_STATIC_ARCHIVES)
    if(NOT TARGET procursus-native-static)
      add_custom_target(procursus-native-static)
    endif()
    # The Swift patch visits CompatibilityThreading first. Keep clones in
    # their defining directories so automatic current-directory includes match.
    cmake_language(EVAL CODE
      "cmake_language(DEFER CALL procursus_native_target [[${original}]])")
  endif()
endfunction()

function(procursus_native_swift_archive original output destination lipo)
  if(NOT PROCURSUS_NATIVE_STATIC_ARCHIVES)
    return()
  endif()
  set(inputs)
  set(dependencies)
  foreach(target IN LISTS ARGN)
    list(APPEND inputs "$<TARGET_FILE:procursus-native-${target}>")
    list(APPEND dependencies "procursus-native-${target}")
  endforeach()
  set(native_output "${output}.native.a")
  add_custom_command(OUTPUT "${native_output}"
    COMMAND "${lipo}" -create -output "${native_output}" ${inputs}
    DEPENDS ${dependencies} VERBATIM)
  add_custom_target("procursus-native-${original}" DEPENDS "${native_output}")
  add_dependencies(procursus-native-static "procursus-native-${original}")
  get_filename_component(filename "${output}" NAME)
  install(FILES "${native_output}" DESTINATION "${destination}"
    RENAME "${filename}"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE
                WORLD_READ WORLD_EXECUTE
    COMPONENT procursus-native-static EXCLUDE_FROM_ALL)
endfunction()

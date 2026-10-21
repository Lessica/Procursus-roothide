# Match newer CMake's Darwin rpath support when the host has no sw_vers.
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux" AND APPLE
   AND NOT CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG)
  set(CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG "-Wl,-rpath,")
endif()

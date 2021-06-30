cmake_minimum_required(VERSION 2.8.7 FATAL_ERROR)
#project(GTest)
message("Setting up Google Test")
message("CMAKE_CXX_COMPILER: ${CMAKE_CXX_COMPILER}")
message("CMAKE_CXX_FLAGS: ${CMAKE_CXX_FLAGS}")
message("CMAKE_C_COMPILER: ${CMAKE_C_COMPILER}")
message("CMAKE_C_FLAGS: ${CMAKE_C_FLAGS}")

# Enable ExternalProject CMake module
include(ExternalProject)

# Set the build type if it isn't already
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# Set default ExternalProject root directory
set_directory_properties(PROPERTIES EP_PREFIX ${CMAKE_BINARY_DIR}/ThirdParty)

# Add gtest
ExternalProject_Add(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG release-1.8.0
    TIMEOUT 10
    # Force separate output paths for debug and release builds to allow easy
    # identification of correct lib in subsequent TARGET_LINK_LIBRARIES commands
    CMAKE_ARGS -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
               -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_DEBUG:PATH=DebugLibs
               -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE:PATH=ReleaseLibs 
               -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_C_FLAGS='${CMAKE_C_FLAGS}'
               -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER} -DCMAKE_CXX_FLAGS='${CMAKE_CXX_FLAGS}'
               -Dgtest_force_shared_crt=ON
    # Disable install step
    INSTALL_COMMAND ""
    # Wrap download, configure and build steps in a script to log output
    LOG_DOWNLOAD ON
    LOG_CONFIGURE ON
    LOG_BUILD ON)

# Specify include dir
ExternalProject_Get_Property(googletest source_dir)
include_directories(${source_dir}/googletest/include)
include_directories(${source_dir}/googlemock/include)
include_directories(${CMAKE_SOURCE_DIR})

foreach(TARGET main VectorMapTest)

  # Add test executable target
  add_executable(${TARGET} src/${TARGET}.cpp $<TARGET_OBJECTS:HASH_FUNCS>)

  # Create dependency of MainTest on googletest
  add_dependencies(${TARGET} googletest)

  # Specify MainTest's link libraries
  ExternalProject_Get_Property(googletest binary_dir)
  set(Suffix ".a")
  set(Pthread "-pthread")
  target_link_libraries(
    ${TARGET}
    debug ${binary_dir}/googlemock/gtest/DebugLibs/${CMAKE_FIND_LIBRARY_PREFIXES}gtest${Suffix}
    optimized ${binary_dir}/googlemock/gtest/ReleaseLibs/${CMAKE_FIND_LIBRARY_PREFIXES}gtest${Suffix}
    ${Pthread})

  install(TARGETS ${TARGET} DESTINATION ${CMAKE_INSTALL_PREFIX}/bin/ )
  add_test(${TARGET}-UnitTest ${TARGET})
endforeach()

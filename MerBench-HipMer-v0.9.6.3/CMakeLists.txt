# The name of our project is "HipMer". CMakeLists files in this project can
# refer to the root source directory of the project as ${HIPMER_SOURCE_DIR} and
# to the root binary directory of the project as ${HIPMER_BINARY_DIR}.
cmake_minimum_required (VERSION 2.8 FATAL_ERROR)
project (HipMer)
set(HIPMER_SOURCE_DIR ${CMAKE_SOURCE_DIR})

# include modules for UPC, RT and ARGP
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_MODULE_PATH} ${CMAKE_SOURCE_DIR}/cmake/Modules)

enable_testing()

# By default do a full build.  set to 0 to only build single-exec
if (NOT HIPMER_FULL_BUILD STREQUAL "0")
  set(HIPMER_FULL_BUILD True)
else()
  if (HIPMER_FULL_BUILD EQUAL 0)
    set(HIPMER_FULL_BUILD False)
  else()
    set(HIPMER_FULL_BUILD True)
  endif()
endif()

if (HIPMER_FULL_BUILD)
  message("Performing a full build of HipMer and all stand-alone sub modules")
else()
  message("Performing a reduced build of HipMer without stand-alone sub modules")
endif()

if (HIPMER_EMBED_HMMER)
  message("Performing a build with a modified build of the hmmer library")
  set(hmmer_install ${CMAKE_BINARY_DIR}/libhmmer)
  set(hmmer_include ${hmmer_install}/include/lib_nhmmer.h)
  include(ExternalProject)
  ExternalProject_Add(_project_libhmmer
    PREFIX ${CMAKE_BINARY_DIR}
    DOWNLOAD_COMMAND tar -xzf ${CMAKE_SOURCE_DIR}/contrib/hmmer_lib.tar.gz
    SOURCE_DIR ${CMAKE_BINARY_DIR}/src/lib_hmmer-3.1b2
    CONFIGURE_COMMAND ${CMAKE_BINARY_DIR}/src/lib_hmmer-3.1b2/configure --prefix=${hmmer_install} ${HIPMER_HMMER_CONFIGURE_OPTS} CC=${CMAKE_C_COMPILER} CXX=${CMAKE_CXX_COMPILER}
    BUILD_COMMAND make -j16 all && make -j16 check
    INSTALL_COMMAND make install
    BUILD_IN_SOURCE 1
    BUILD_BYPRODUCTS ${hmmer_include}
  )
  add_library(libhmmer STATIC IMPORTED)
  set_property(TARGET libhmmer PROPERTY IMPORTED_LOCATION ${hmmer_install}/lib/libhmmer.a)
  add_library(libeasel STATIC IMPORTED)
  set_property(TARGET libeasel PROPERTY IMPORTED_LOCATION ${hmmer_install}/lib/libeasel.a)
  add_dependencies(libhmmer _project_libhmmer)
  add_dependencies(libeasel _project_libhmmer)
  set(HMMER_LIBS libhmmer libeasel)
  include_directories(${hmmer_install}/include)
  add_definitions(-DHIPMER_EMBED_HMMER=1)
  add_custom_target(project_libhmmer ALL echo "Preparing libhmmer"
		DEPENDS _project_libhmmer libhmmer libeasel
		COMMENT "Built libhmmer")
else()
  set(hmmer_include)
endif()

if (HIPMER_EMBED_PERL)
  message("Performing a build with perl embedded into the UPC code. (May require a static build of perl in the PATH see doc/EmbeddingPerl.README)")
  find_package(PerlLibs REQUIRED)
  message("Using ${PERL_EXECUTABLE} and its libraries ${PERL_LIBRARY}")
endif()

# By default do not use KHASH, but rather VectorMap, set to 1 to use KHASH
if (HIPMER_KHASH STREQUAL "1")
  message("Using KHASH for kmer counting")
  set(HIPMER_KHASH True)
else()
  message("Using STL or VectorMap for kmer counting")
  set(HIPMER_KHASH False)
endif()

find_package(RT QUIET)
find_package(MPI REQUIRED)

# prefer static to dynamic libraries when including third party libs (like ZLIB)
if (APPLE)
  set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".dylib" ".so")
else()
  set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".so")
endif()

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING
        "Choose the type of build, options are: None Debug Release RelWithDebInfo MinSizeRel."
	    FORCE)
endif()
message("Building for ${CMAKE_BUILD_TYPE}")
if(${CMAKE_BUILD_TYPE} STREQUAL "Debug")
    add_definitions(-DDEBUG)
endif()

if(NOT HIPMER_READ_BUFFER)
  set(HIPMER_READ_BUFFER 1048576)
endif()
add_definitions(-DKSEQ_BUFFER_SIZE=${HIPMER_READ_BUFFER})

IF(HIPMER_VERBOSE)
    ADD_DEFINITIONS(-DHIPMER_VERBOSE=${HIPMER_VERBOSE})
ENDIF()

IF (CMAKE_UPC_USE_PTHREADS)
    ADD_DEFINITIONS(-DHIPMER_PTHREADS=${CMAKE_UPC_USE_PTHREADS})
ENDIF()

# get the version from git
set(HIPMER_VERSION_FILE_TEMPLATE       "${CMAKE_SOURCE_DIR}/src/hipmer/common/version.h.in")
set(HIPMER_VERSION_FILE                "${CMAKE_SOURCE_DIR}/src/hipmer/common/version.h")
set(HIPMER_VERSION_DIFF_FILE_TEMPLATE  "${CMAKE_SOURCE_DIR}/src/hipmer/common/version_diff.h.in")
set(HIPMER_VERSION_DIFF_FILE           "${CMAKE_SOURCE_DIR}/src/hipmer/common/version_diff.h")
set(HIPMER_GIT_VERSION_FILE            "${CMAKE_SOURCE_DIR}/HIPMER_VERSION")
set(HIPMER_GIT_DIFF_FILE               "${CMAKE_SOURCE_DIR}/HIPMER_VERSION.diff")
find_package(Git QUIET)
if (GIT_FOUND AND IS_DIRECTORY ${CMAKE_SOURCE_DIR}/.git)
	add_custom_target(GET_GIT_VERSION ALL
                          COMMAND ${GIT_EXECUTABLE} describe --tags --dirty > ${HIPMER_GIT_VERSION_FILE}
                          WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
                          COMMENT "Retrieving git version"
                         )
	add_custom_target(GET_GIT_DIFF ALL
                          COMMAND bash -c '${GIT_EXECUTABLE} diff --raw | tee ${HIPMER_GIT_DIFF_FILE} | xxd -i > ${HIPMER_GIT_DIFF_FILE}.hex' 
                          WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
                          COMMENT "Retrieving git diff"
                         )
else()
	if (NOT EXISTS ${HIPMER_GIT_VERSION_FILE})
		add_custom_target(GET_GIT_VERSION ALL
                                  COMMAND echo "UNKNOWN-VERSION" > ${HIPMER_GIT_VERSION_FILE}
                                  COMMENT "Could not determine the HIPMER_VERSION... no file ${HIPMER_GIT_VERSION_FILE}"
                                  )
		add_custom_target(GET_GIT_DIFF ALL
                                  COMMAND bash -c '> ${HIPMER_GIT_DIFF_FILE}; >${HIPMER_GIT_DIFF_FILE}.hex'
                                  )
	else()
		add_custom_target(GET_GIT_VERSION ALL
                                  COMMAND /bin/true
                                  COMMENT "Git Version is already present in ${HIPMER_GIT_VERSION_FILE}"
                                 )
		add_custom_target(GET_GIT_DIFF ALL
                                  COMMAND /bin/true
                                 )
	endif()
endif()
set(GIT_PREFIX HIPMER)
configure_file(${CMAKE_SOURCE_DIR}/cmake/Modules/makeVersionFile.cmake.in ${CMAKE_BINARY_DIR}/makeVersionFile.cmake @ONLY)
add_custom_target(REPLACE_VERSION_H ALL
		COMMAND ${CMAKE_COMMAND}
			-DHIPMER_GIT_VERSION_FILE=${HIPMER_GIT_VERSION_FILE}
                        -DHIPMER_GIT_DIFF_FILE=${HIPMER_GIT_DIFF_FILE}
			-DHIPMER_VERSION_FILE=${HIPMER_VERSION_FILE}
			-DHIPMER_VERSION_FILE_TEMPLATE=${HIPMER_VERSION_FILE_TEMPLATE}
			-DHIPMER_VERSION_DIFF_FILE=${HIPMER_VERSION_DIFF_FILE}
			-DHIPMER_VERSION_DIFF_FILE_TEMPLATE=${HIPMER_VERSION_DIFF_FILE_TEMPLATE}
			-P ${CMAKE_BINARY_DIR}/makeVersionFile.cmake
		WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
		DEPENDS GET_GIT_VERSION GET_GIT_DIFF
		COMMENT "Building ${HIPMER_VERSION_FILE}")
add_dependencies(REPLACE_VERSION_H GET_GIT_VERSION)
if (HIPMER_EMBED_HMMER)
  add_dependencies(REPLACE_VERSION_H project_libhmmer)
endif()


if(NOT CMAKE_INSTALL_PREFIX)
    message(FATAL_ERROR "Please specify a CMAKE_INSTALL_PREFIX")
endif()
if(NOT IS_ABSOLUTE ${CMAKE_INSTALL_PREFIX})
    get_filename_component(fullpath ${CMAKE_INSTALL_PREFIX} ABSOLUTE)
    set (CMAKE_INSTALL_PREFIX "${fullpath}")
endif()

# if no prefix was passed, install into the build directory
if (CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set (CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}" CACHE PATH "default install path" FORCE )
endif()
message("Installing into ${CMAKE_INSTALL_PREFIX}")
set(HIPMER_INSTALL_DEFAULT "${CMAKE_INSTALL_PREFIX}")

# check compiler and set appropriate linker flags
include( CheckCCompilerFlag )
include( CheckCXXCompilerFlag )

if (NOT HIPMER_NO_AIO)
  try_compile(TRY_GLIB_HAS_AIO_SUPPORT ${CMAKE_CURRENT_BINARY_DIR}/test
					${CMAKE_SOURCE_DIR}/test/hipmer/hello_aio.c
                                        LINK_LIBRARIES ${RT_LIBRARIES})
  if(NOT TRY_GLIB_HAS_AIO_SUPPORT)
    set(AIO false)
    message("No AIO support!")
  else()
    set(AIO true)
  endif()
else()
  set(AIO false)
endif()
if (NOT AIO)
  add_definitions(-DHIPMER_NO_AIO)
endif()

if (HIPMER_HWATOMIC)
  add_definitions(-DUSE_BUPC_HWATOMIC=1)
  message("Using BUPC HW ATOMICS")
else()
  message("NOT Using BUPC HW ATOMICS")
endif()

if (NOT HIPMER_NO_AVX512F)
  try_compile(TRY_AVX512F  ${CMAKE_CURRENT_BINARY_DIR}/test
                                        ${CMAKE_SOURCE_DIR}/test/hipmer/hello_avx512f.c
                                        LINK_LIBRARIES ${RT_LIBRARIES})
  if (NOT TRY_AVX512F)
    set(AVX512F false)
    message("No AVX512 support detected!")
  else()
    set(AVX512F true)
  endif()
else()
  set(AVX512F false)
endif()
if (AVX512F)
  message("Compiling with AVX512 intrinsics")
  add_definitions(-D__AVX512F__)
else()
  message("Not using AVX512 intrinsics")
endif()

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Cray")
  set(CXX0X_FLAG "-h std=c++0x")
  set(CXX11_FLAG "-h std=c++11")
  set(C99_FLAG "-h std=c99")

  

else()
  # gnu / intel / clang
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}  -Wshadow -Wreturn-type")
  check_cxx_compiler_flag("-O" CXX_HAS_DASH_O)
  message("Checked CXX compiler for -O: ${CXX_HAS_DASH_O} '${CMAKE_REQUIRED_DEFINITIONS}'")
  try_compile(TRY_C_HAS_STATIC_LIBGCC ${CMAKE_CURRENT_BINARY_DIR}/test 
                                    ${CMAKE_SOURCE_DIR}/test/hipmer/hello_world.cpp
                                    LINK_LIBRARIES -static-libgcc)
  if (TRY_C_HAS_STATIC_LIBGCC)
    check_c_compiler_flag("-static-libgcc" C_HAS_STATIC_LIBGCC)
    check_cxx_compiler_flag("-static-libgcc" CXX_HAS_STATIC_LIBGCC)
    message("Checked C and CXX compiler for --static-libgcc: ${C_HAS_STATIC_LIBGCC} ${CXX_HAS_STATIC_LIBGCC} '${CMAKE_REQUIRED_DEFINITIONS}'")
    if (C_HAS_STATIC_LIBGCC AND CXX_HAS_STATIC_LIBGCC)
       set( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libgcc" )
       message("Successfully found CMAKE_EXE_LINKER_FLAGS: ${CMAKE_EXE_LINKER_FLAGS}")
    endif()
  endif()

  try_compile(TRY_CXX_HAS_STATIC            ${CMAKE_CURRENT_BINARY_DIR}/test
                                          ${CMAKE_SOURCE_DIR}/test/hipmer/hello_world.cpp
                                          LINK_LIBRARIES -static)

  try_compile(TRY_CXX_HAS_STATIC_LIBSTDCXX ${CMAKE_CURRENT_BINARY_DIR}/test
                                          ${CMAKE_SOURCE_DIR}/test/hipmer/hello_world.cpp
                                          LINK_LIBRARIES -static-libstdc++)
  
  if(TRY_CXX_HAS_STATIC_LIBSTDCXX)
    check_cxx_compiler_flag("-static-libstdc++" CXX_HAS_STATIC_LIBSTDCXX)
    message("Checked CXX compiler for --static-libstd++: ${CXX_HAS_STATIC_LIBSTDCXX} '${CMAKE_REQUIRED_DEFINITIONS}'")
    if (CXX_HAS_STATIC_LIBSTDCXX AND NOT "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
        set( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libstdc++" )
    else ()
        if(TRY_CXX_HAS_STATIC)
            set( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static" )
        endif()
    endif ()
  else()
    if(TRY_CXX_HAS_STATIC)
        set( CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static" )
    endif()
  endif()
  message("Found CMAKE_EXE_LINKER_FLAGS: ${CMAKE_EXE_LINKER_FLAGS}")
endif()

if (APPLE)
  
  # readlink does not work the same and realpath does not exist on MacOSX
  ADD_EXECUTABLE(realpath ${CMAKE_SOURCE_DIR}/src/realpath.c)
  INSTALL(TARGETS realpath DESTINATION ${CMAKE_INSTALL_PREFIX}/bin/ )

endif()

set(BUILD_STATIC_LIBS ON)
set(BUILD_SHARED_LIBS OFF)

if (NOT CXX11_FLAG)
  set(CXX11_FLAG "-std=c++11")
endif()

if (NOT CXX0X_FLAG)
  set(CXX0X_FLAG "-std=c++0x")
endif()

if (NOT C99_FLAG)
  set(C99_FLAG "-std=c99")
endif()

if (NOT CXX_SUPPORTS_OX)
  check_cxx_compiler_flag("${CXX0X_FLAG}" CXX_SUPPORTS_0X)
  message("Checked CXX compiler for ${CXX0X_FLAG}: ${CXX_SUPPORTS_0X} '${CMAKE_REQUIRED_DEFINITIONS}'")
endif()
if (NOT CXX_SUPPORTS_11)
  check_cxx_compiler_flag("${CXX11_FLAG}" CXX_SUPPORTS_11)
  message("Checked CXX compiler for ${CXX11_FLAG}: ${CXX_SUPPORTS_11} '${CMAKE_REQUIRED_DEFINITIONS}'")
endif()
if (NOT C_SUPPORTS_99)
  check_c_compiler_flag("${C99_FLAG}" C_SUPPORTS_99)
  message("Checked C compiler for ${C99_FLAG}: ${C_SUPPORTS_99} '${CMAKE_REQUIRED_DEFINITIONS}'")
endif()


if(CXX_SUPPORTS_11)
    set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX11_FLAG} " )
elseif(CXX_SUPPORTS_0X)
    set( CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CXX0X_FLAG} " )
else()
    message( FATAL_ERROR "Incompatible c++ compiler.  c++0x or c++11 support is required. CMake will exit." )
endif()

if(NOT C_SUPPORTS_99)
  message( FATAL_ERROR "C compiler does not support std=c99.  Cmake will exit.")
endif()

set( CMAKE_VERBOSE_MAKEFILE off)


message(STATUS "Testing the environment..")

# SeqDB with MPI support
find_package(MPI)

include(CheckCXXSourceCompiles)
include(CheckCXXSourceRuns)

check_cxx_source_compiles("
#include <stdlib.h>
#include <sched.h>
int main(void)
{
  if (sched_getcpu() < 0)
  {
    exit(1);
  }
  cpu_set_t coremask;
  if (sched_getaffinity(0, sizeof(coremask), &coremask) != 0) {
    exit(1);
  }
  exit(0);
}" HAS_SCHED)
if (HAS_SCHED)
  add_definitions(-DHAS_SCHED)
else()
  message("No sched.h found\n")
endif()

# build and include optlist library
include_directories("${CMAKE_SOURCE_DIR}/src/optlist")
add_subdirectory("src/optlist")

if (HIPMER_TEST OR NOT HIPMER_NO_UNIT_TESTS)
    enable_testing()
    add_subdirectory(gtest)  
endif()

include(CheckLanguage2)
check_language2(UPC)
if (CMAKE_UPC_COMPILER)
    enable_language(UPC OPTIONAL)
  
    if(CMAKE_UPC_COMPILER_LOADED AND CMAKE_UPC_COMPILER AND EXISTS ${CMAKE_UPC_COMPILER})

        if ((NOT CMAKE_UPC_COMPILER) OR (NOT CMAKE_UPC_COMPILER_ID) OR (NOT EXISTS ${CMAKE_UPC_COMPILER}))
          message(FATAL_ERROR "No working UPC compiler found.")
        endif()

        if (NOT HIPMER_USE_UPC_FLAVOR)
          if (CMAKE_UPC_COMPILER_ID STREQUAL "BUPC")
            message("Detected Berkeley UPC")
            set(HIPMER_USE_UPC_FLAVOR "BUPC")
          elseif (CMAKE_UPC_COMPILER_ID STREQUAL "CrayUPC")
            message("Detected Cray UPC")
            set(HIPMER_USE_UPC_FLAVOR "CRAY_UPC")
          else()
            message("Unknown UPC version, assuming Berkeley UPC")
            set(HIPMER_USE_UPC_FLAVOR "BUPC")
          endif ()
        endif()
        message("adding -DUSE_${HIPMER_USE_UPC_FLAVOR} defintion to all builds")
        add_definitions( -DUSE_${HIPMER_USE_UPC_FLAVOR} )

        add_subdirectory(src/hipmer)
        add_subdirectory(src/microbenchmarks)

        if (HIPMER_TEST OR CMAKE_BUILD_TYPE STREQUAL "Debug")
            add_subdirectory(test/hipmer)
        endif()

    else() 
        message(FATAL_ERROR "UPC compiler was not found to be working, not building HipMer.")
    endif()
else()
    message(FATAL_ERROR "UPC compiler was not found, not building HipMer")
endif()
if (NOT CMAKE_UPC_COMPILER)
   message(FATAL_ERROR "UPC could not be found.  Please make sure it is properly installed and in the PATH. (see http://upc.lbl.gov)
If cmake can not automatically find it, try specifying:
    export HIPMER_BUILD_OPTS=\"-DCMAKE_UPC_COMPILER_ENV_VAR=upcc\"
")
endif()


#unit test scripts
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/test_data.tmp)

set(TEST_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/test)

install(DIRECTORY src/perl/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
        USE_SOURCE_PERMISSIONS
        PATTERN "canonical_assembly.pl")
install(DIRECTORY src/perl/
        DESTINATION ${CMAKE_INSTALL_PREFIX}/bin
        USE_SOURCE_PERMISSIONS
        PATTERN "findDMin2.pl")

install(DIRECTORY test/ DESTINATION ${CMAKE_INSTALL_PREFIX}/etc/meraculous PATTERN ".*" EXCLUDE PATTERN "merBlast" EXCLUDE)
install(DIRECTORY doc/ DESTINATION ${CMAKE_INSTALL_PREFIX}/share/doc/meraculous PATTERN ".*" EXCLUDE)
install(FILES ${HIPMER_GIT_VERSION_FILE} ${HIPMER_GIT_DIFF_FILE} README.md LEGAL.txt LICENSE.txt DESTINATION ${CMAKE_INSTALL_PREFIX})
install(PROGRAMS bootstrap_hipmer_env.sh DESTINATION ${CMAKE_INSTALL_PREFIX}/bin)


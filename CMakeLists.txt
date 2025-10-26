cmake_minimum_required(VERSION 3.14)

project(MyProject VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Download CPM.cmake (for future C++ dependencies)
file(
  DOWNLOAD
  https://github.com/cpm-cmake/CPM.cmake/releases/download/v0.40.2/CPM.cmake
  ${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake
  EXPECTED_HASH SHA256=c8cdc32c03816538ce22781ed72964dc864b2a34a310d3b7104812a5ca2d835d
)
include(${CMAKE_CURRENT_BINARY_DIR}/cmake/CPM.cmake)

# Find libvips (system dependency - see setup.sh for installation)
if(WIN32 AND DEFINED VIPS_INCLUDE_DIR AND DEFINED VIPS_LIBRARY_DIR)
    # Manual configuration for Windows cross-compilation
    add_library(vips INTERFACE)
    target_include_directories(vips INTERFACE ${VIPS_INCLUDE_DIR})
    target_link_directories(vips INTERFACE ${VIPS_LIBRARY_DIR})
    target_link_libraries(vips INTERFACE vips-cpp-42 vips-42 glib-2.0 gobject-2.0)
else()
    # Use pkg-config for native builds
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(VIPS REQUIRED IMPORTED_TARGET vips-cpp)
    add_library(vips ALIAS PkgConfig::VIPS)
endif()

# Add source files
add_executable(${PROJECT_NAME} src/main.cpp)

# Find zlib for gzip compression
find_package(ZLIB REQUIRED)

# Link libraries
target_link_libraries(${PROJECT_NAME} PRIVATE vips ZLIB::ZLIB)

# Windows-specific settings
if(WIN32)
    target_link_libraries(${PROJECT_NAME} PRIVATE ws2_32)
endif()

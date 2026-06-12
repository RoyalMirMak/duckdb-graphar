cmake_minimum_required(VERSION 3.20)

set(TARGET_NAME duckdb_graphar)
set(EXTENSION_NAME ${TARGET_NAME}_extension)
set(LOADABLE_EXTENSION_NAME ${TARGET_NAME}_loadable_extension)
set(EXTENSION_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR} CACHE STRING "Extension root directory")

project(${TARGET_NAME})

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(UNIX AND NOT APPLE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -static-libstdc++ -static-libgcc")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static-libstdc++ -static-libgcc")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -static-libstdc++ -static-libgcc")
endif()

# Include dependency paths set by Makefile (ARROW_ROOT, GRAPHAR_ROOT)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/extension_deps.cmake")
    include("${CMAKE_CURRENT_SOURCE_DIR}/third_party/extension_deps.cmake")
endif()

message(STATUS "My roots: ${ARROW_ROOT} ${GRAPHAR_ROOT}")

# Add paths to CMAKE_PREFIX_PATH for find_package
if(ARROW_ROOT)
    list(APPEND CMAKE_PREFIX_PATH ${ARROW_ROOT})
endif()
if(GRAPHAR_ROOT)
    list(APPEND CMAKE_PREFIX_PATH ${GRAPHAR_ROOT})
endif()

# Find required packages
find_package(Arrow REQUIRED CONFIG)
find_package(ArrowDataset REQUIRED CONFIG)
find_package(ArrowAcero REQUIRED CONFIG)
find_package(Parquet REQUIRED CONFIG)
find_package(graphar REQUIRED CONFIG)

# Collect extension sources
file(GLOB_RECURSE EXTENSION_SOURCES CONFIGURE_DEPENDS "${EXTENSION_ROOT_DIR}/src/*.cpp")

# Set include directories BEFORE building
# This ensures GraphAr and Arrow headers are found during compilation
include_directories(
    ${GRAPHAR_ROOT}/include
    ${ARROW_ROOT}/include
    ${EXTENSION_ROOT_DIR}/include
)

# Build static extension
message(STATUS "Building static extension")
build_static_extension(${TARGET_NAME} ${EXTENSION_SOURCES})

# Build loadable extension
message(STATUS "Building loadable extension")
build_loadable_extension(${TARGET_NAME} " " ${EXTENSION_SOURCES})

# Link libraries to loadable extension
# Only link graphar_shared to avoid duplicate symbols
target_link_libraries(${LOADABLE_EXTENSION_NAME} PRIVATE
    graphar::graphar_shared
)

# Set visibility for loadable extension to hide internal symbols
if(UNIX AND NOT APPLE)
    set_target_properties(${LOADABLE_EXTENSION_NAME} PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
    )
endif()

# Install static extension
install(TARGETS ${EXTENSION_NAME}
        EXPORT "${DUCKDB_EXPORT_SET}"
        LIBRARY DESTINATION "${INSTALL_LIB_DIR}"
        ARCHIVE DESTINATION "${INSTALL_LIB_DIR}")

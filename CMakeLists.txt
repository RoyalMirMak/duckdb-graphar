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
    # Temp fix dublicate arrow on linux
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--allow-multiple-definition")
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/third_party/extension_deps.cmake")
    include("${CMAKE_CURRENT_SOURCE_DIR}/third_party/extension_deps.cmake")
endif()

message("My roots: ${ARROW_ROOT} ${GRAPHAR_ROOT}")
if(ARROW_ROOT)
    list(APPEND CMAKE_PREFIX_PATH ${ARROW_ROOT})
endif()

if(GRAPHAR_ROOT)
    list(APPEND CMAKE_PREFIX_PATH ${GRAPHAR_ROOT})
endif()

find_package(Arrow REQUIRED CONFIG)
find_package(ArrowDataset REQUIRED CONFIG)
find_package(ArrowAcero REQUIRED CONFIG)
find_package(Parquet REQUIRED CONFIG)

find_package(graphar REQUIRED CONFIG)

# Include directories are now handled in config/CMakeLists.txt
# This file is intentionally minimal - the actual build logic is in extension_config.cmake

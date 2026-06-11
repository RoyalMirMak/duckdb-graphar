# =============================================
# Build Targets
# =============================================
file(GLOB_RECURSE EXTENSION_SOURCES CONFIGURE_DEPENDS "${EXTENSION_ROOT_DIR}/src/*.cpp")
set(PARAMETERS "-warnings")

# FIX 1: Enforce C++20 so template instantiations align
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(EXTENSION_STATIC_BUILD ON CACHE BOOL "Build extensions with static DuckDB")

log_stage("Building static extension")
build_static_extension(duckdb_graphar ${EXTENSION_SOURCES})
log_done()

log_stage("Building loadable extension")
build_loadable_extension(duckdb_graphar ${PARAMETERS} ${EXTENSION_SOURCES})
log_done()

set(DEPS_INSTALL_DIR ${CMAKE_BINARY_DIR}/_deps)
set(ARROW_INSTALL_DIR ${DEPS_INSTALL_DIR}/arrow-install)
set(GRAPHAR_INSTALL_DIR ${DEPS_INSTALL_DIR}/graphar-install)
set(GRAPHAR_SOURCE_DIR ${DEPS_INSTALL_DIR}/graphar-prefix/src)

# FIX 2: Correct GraphAr Yaml includes via Generator Expressions
set(EXTENSION_INCLUDES
    $<BUILD_INTERFACE:${EXTENSION_ROOT_DIR}/include>
    $<BUILD_INTERFACE:${GRAPHAR_INSTALL_DIR}/include>
    $<BUILD_INTERFACE:${GRAPHAR_SOURCE_DIR}/graphar/cpp/thirdparty>
    $<BUILD_INTERFACE:${EXTENSION_ROOT_DIR}/build/_deps/graphar-prefix/src/graphar/cpp/thirdparty>
    $<BUILD_INTERFACE:${EXTENSION_ROOT_DIR}/third_party/graphar/src/cpp/thirdparty>
    $<BUILD_INTERFACE:${duckdb_SOURCE_DIR}/src/include>
    $<BUILD_INTERFACE:${arrow_SOURCE_DIR}/cpp/src>
    $<BUILD_INTERFACE:${ARROW_INSTALL_DIR}/include>
)

target_include_directories(duckdb_graphar_extension PUBLIC ${EXTENSION_INCLUDES} $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_include_directories(duckdb_graphar_loadable_extension PUBLIC ${EXTENSION_INCLUDES} $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

set(EXT_LIBS
    arrow::arrow_shared
    graphar::graphar_shared)

if (NOT APPLE)
    # FIX 3: Add --allow-multiple-definition uniquely for the Ubuntu GUI/GNU Linker
    list(APPEND EXT_LIBS "-Wl,--disable-new-dtags" "-Wl,--allow-multiple-definition") 
endif()

target_link_libraries(duckdb_graphar_extension
    duckdb_static
    ${EXT_LIBS}
)

target_link_libraries(duckdb_graphar_loadable_extension
    ${EXT_LIBS}
)

# =============================================
# Installation
# =============================================
log_stage("Installing...")
set(INSTALL_LIB_DIR "${CMAKE_INSTALL_LIBDIR}" CACHE PATH "Library installation directory")

install(
  TARGETS duckdb_graphar_extension
  EXPORT "${DUCKDB_EXPORT_SET}"
  LIBRARY DESTINATION "${INSTALL_LIB_DIR}"
  ARCHIVE DESTINATION "${INSTALL_LIB_DIR}")

install(TARGETS duckdb_graphar_loadable_extension
    LIBRARY DESTINATION ${INSTALL_LIB_DIR}
)

install(DIRECTORY include/ DESTINATION include
    FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
)
log_done()

if(ENABLE_UNIT_TESTS)
    log_stage("Building tests of extension...")
    add_subdirectory(${EXTENSION_ROOT_DIR}/tests tests)
    log_done()
endif()
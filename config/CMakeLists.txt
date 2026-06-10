# =============================================
# Build Targets
# =============================================

file(GLOB_RECURSE EXTENSION_SOURCES CONFIGURE_DEPENDS "${EXTENSION_ROOT_DIR}/src/*.cpp")

set(PARAMETERS "-warnings")
set(EXTENSION_STATIC_BUILD ON CACHE BOOL "Build extensions with static DuckDB")

# Detect build scenario and set paths accordingly
if(DEFINED ENV{GRAPHAR_ROOT} OR GRAPHAR_ROOT)
    # Makefile build: dependencies are in third_party/
    if(GRAPHAR_ROOT)
        set(GRAPHAR_INSTALL_DIR ${GRAPHAR_ROOT})
    else()
        set(GRAPHAR_INSTALL_DIR $ENV{GRAPHAR_ROOT})
    endif()
    if(ARROW_ROOT)
        set(ARROW_INSTALL_DIR ${ARROW_ROOT})
    else()
        set(ARROW_INSTALL_DIR $ENV{ARROW_ROOT})
    endif()
    set(GRAPHAR_SOURCE_DIR ${EXTENSION_ROOT_DIR}/third_party/graphar/src)
    set(ARROW_SOURCE_DIR ${EXTENSION_ROOT_DIR}/third_party/arrow/src)
else()
    # FetchContent build (DuckDB's internal build): dependencies are in _deps/
    set(DEPS_INSTALL_DIR ${CMAKE_BINARY_DIR}/_deps)
    set(ARROW_INSTALL_DIR ${DEPS_INSTALL_DIR}/arrow-install)
    set(GRAPHAR_INSTALL_DIR ${DEPS_INSTALL_DIR}/graphar-install)
    set(GRAPHAR_SOURCE_DIR ${DEPS_INSTALL_DIR}/graphar-prefix/src)
    set(ARROW_SOURCE_DIR ${DEPS_INSTALL_DIR}/arrow-prefix/src)
endif()

# Define includes BEFORE build macros
set(EXTENSION_INCLUDES
    ${EXTENSION_ROOT_DIR}/include
    ${GRAPHAR_INSTALL_DIR}/include
    ${GRAPHAR_SOURCE_DIR}/graphar/cpp/thirdparty
    ${duckdb_SOURCE_DIR}/src/include
    ${arrow_SOURCE_DIR}/cpp/src
    ${ARROW_INSTALL_DIR}/include
)

# Apply includes BEFORE build macros so compiler can find headers
include_directories(${EXTENSION_INCLUDES})

# NOW build the extensions
log_stage("Building static extension")
build_static_extension(duckdb_graphar ${EXTENSION_SOURCES})
log_done()

log_stage("Building loadable extension")
build_loadable_extension(duckdb_graphar ${PARAMETERS} ${EXTENSION_SOURCES})
log_done()

set(EXT_LIBS
    arrow::arrow_shared
    graphar::graphar_shared)

if (NOT APPLE)
    list(APPEND EXT_LIBS "-Wl,--disable-new-dtags") # Use rpath for ubuntu build
endif()

# NOTE: duckdb_graphar_extension should NOT link against duckdb_static
# The build_static_extension() macro already handles DuckDB linkage internally.
# Linking against duckdb_static here causes duplicate symbol errors when the
# extension is statically linked into DuckDB.
target_link_libraries(duckdb_graphar_extension
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

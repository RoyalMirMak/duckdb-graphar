# =============================================
# Build Targets
# =============================================

# Add these lines right here at the top!
# 1. Force C++20 across ALL of DuckDB to prevent ODR/COMDAT mismatches
set(CMAKE_CXX_STANDARD 20 CACHE STRING "Force C++20 for DuckDB globally" FORCE)

# 2. Globally inject Linux linker fixes so that libduckdb.so actually receives them
if(UNIX AND NOT APPLE)
    add_compile_options("-static-libstdc++" "-static-libgcc")
    add_link_options("-static-libstdc++" "-static-libgcc" "-Wl,--allow-multiple-definition")
endif()

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

# =============================================
# Link Libraries
# =============================================
set(EXT_LIBS
    Arrow::arrow_static
    graphar)

if (NOT APPLE)
    list(APPEND EXT_LIBS "-Wl,--disable-new-dtags") # Use rpath for ubuntu build
    
    # THE FIX: Inject the duplicate forgiveness flag directly into the library list.
    # This guarantees DuckDB's custom macros cannot strip it out, and it places
    # the flag in the exact correct order for the Linux linker.
    list(APPEND EXT_LIBS "-Wl,--allow-multiple-definition")
    
    # If the above still complains, you can also hide the duplicates from propagating using this standard DuckDB extension flag:
    list(APPEND EXT_LIBS "-Wl,--exclude-libs,ALL") 
endif()

# NOTE: duckdb_graphar_extension should NOT link against duckdb_static
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

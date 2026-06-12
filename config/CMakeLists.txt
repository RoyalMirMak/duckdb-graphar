# =============================================
# Build Configuration for duckdb_graphar extension
# =============================================

# CRITICAL: EXTENSION_STATIC_BUILD must be OFF to prevent duckdb_static from being linked
# into the loadable extension, which causes duplicate symbol errors on Linux.
# DuckDB symbols are resolved at dlopen time from the host process.
set(EXTENSION_STATIC_BUILD OFF CACHE BOOL "Build extensions with static DuckDB" FORCE)

# Define paths (ARROW_ROOT and GRAPHAR_ROOT are set by Makefile via third_party/extension_deps.cmake)
if(ARROW_ROOT AND GRAPHAR_ROOT)
    # Building via Makefile (CI or local make)
    set(ARROW_INSTALL_DIR ${ARROW_ROOT})
    set(GRAPHAR_INSTALL_DIR ${GRAPHAR_ROOT})
else()
    # Direct CMake build (fallback)
    set(DEPS_INSTALL_DIR ${CMAKE_BINARY_DIR}/_deps)
    set(ARROW_INSTALL_DIR ${DEPS_INSTALL_DIR}/arrow-install)
    set(GRAPHAR_INSTALL_DIR ${DEPS_INSTALL_DIR}/graphar-install)
endif()

# =============================================
# Linking strategy (AFTER build, targets exist)
# =============================================

# Static extension: intentionally no extra link libraries here.
# This target produces a .a archive that is later unpacked into libduckdb.so by
# DuckDB's own build. Adding ANY dependency here bakes their symbols into the
# archive's object files and creates duplicates when libduckdb.so is assembled.
target_link_libraries(duckdb_graphar_extension)

# Loadable extension: link only graphar_shared.
# - graphar_shared already embeds or links Arrow internally
# - Do NOT link duckdb_static: DuckDB symbols come from host process at dlopen
# - -Wl,--disable-new-dtags makes RPATH take precedence over LD_LIBRARY_PATH
# - CXX_VISIBILITY_PRESET=hidden hides extension's own symbols, preventing ODR violations
if (APPLE)
    target_link_libraries(duckdb_graphar_loadable_extension
        graphar::graphar_shared
    )
    set_target_properties(duckdb_graphar_loadable_extension PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
    )
else()
    target_link_libraries(duckdb_graphar_loadable_extension
        graphar::graphar_shared
        -Wl,--disable-new-dtags
    )
    set_target_properties(duckdb_graphar_loadable_extension PROPERTIES
        CXX_VISIBILITY_PRESET hidden
        VISIBILITY_INLINES_HIDDEN ON
    )
endif()

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

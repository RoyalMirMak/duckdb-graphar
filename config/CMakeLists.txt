# =============================================
# Build Targets
# =============================================

file(GLOB_RECURSE EXTENSION_SOURCES CONFIGURE_DEPENDS "${EXTENSION_ROOT_DIR}/src/*.cpp")

set(PARAMETERS "-warnings")
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

set(EXTENSION_INCLUDES
    $<BUILD_INTERFACE:${EXTENSION_ROOT_DIR}/include>
    $<BUILD_INTERFACE:${GRAPHAR_INSTALL_DIR}/include>
    $<BUILD_INTERFACE:${GRAPHAR_SOURCE_DIR}/graphar/cpp/thirdparty>
    $<BUILD_INTERFACE:${duckdb_SOURCE_DIR}/src/include>
    $<BUILD_INTERFACE:${arrow_SOURCE_DIR}/cpp/src>
    $<BUILD_INTERFACE:${ARROW_INSTALL_DIR}/include>
)

# PRIVATE: these includes are only needed to compile this extension's own sources.
# PUBLIC would propagate them transitively into DuckDB's own targets.
target_include_directories(duckdb_graphar_extension PRIVATE ${EXTENSION_INCLUDES} $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)
target_include_directories(duckdb_graphar_loadable_extension PRIVATE ${EXTENSION_INCLUDES} $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

# ---- Arrow dependency strategy ------------------------------------------------
#
# Problem 1 — DuckDB symbols (LogicalType::VARCHAR etc.) duplicated:
#   The loadable extension (.duckdb_extension) is a shared library that is dlopen'd
#   into a running DuckDB process. That process already has all DuckDB symbols live.
#   If we link duckdb_static into the loadable .so, GNU ld sees the same symbols from
#   both the extension's own .o files (which #include duckdb headers and therefore get
#   the inline/constexpr statics compiled in) AND from libduckdb_static.a — two
#   definitions → link error on Linux. The fix: do NOT link duckdb_static into the
#   loadable extension. Its DuckDB symbols are resolved at dlopen time.
#
# Problem 2 — Arrow symbols duplicated (libarrow.a linked twice):
#   graphar::graphar_shared transitively pulls in libarrow.a (it was built against
#   static Arrow). When we also list arrow::arrow_shared (or any Arrow static target),
#   the same Arrow .o files end up on the link line twice. The fix: link only
#   graphar::graphar_shared for the loadable target; graphar already carries Arrow
#   inside it. For the static extension archive we don't link anything — it is only
#   compiled, not linked (the final link happens when DuckDB assembles libduckdb.so).
#
# -------------------------------------------------------------------------------

# Static extension: intentionally no extra link libraries here.
# This target produces a .a archive that is later unpacked into libduckdb.so by
# DuckDB's own build. Adding ANY dependency here (duckdb_static, arrow, graphar)
# bakes their symbols into the archive's object files and creates duplicates when
# libduckdb.so is assembled. Include paths above are sufficient for compilation.
target_link_libraries(duckdb_graphar_extension)

# Loadable extension: link only graphar_shared.
# - graphar_shared already embeds or links Arrow internally, so we must NOT also
#   pass any Arrow target — that would cause libarrow.a to appear twice on the
#   link command (once via graphar's INTERFACE and once directly).
# - Do NOT link duckdb_static: DuckDB symbols come from the host process at dlopen.
# - -Wl,--disable-new-dtags makes the RPATH take precedence over LD_LIBRARY_PATH,
#   which is needed so the extension finds its bundled graphar/arrow at runtime.
if (APPLE)
    target_link_libraries(duckdb_graphar_loadable_extension
        graphar::graphar_shared
    )
else()
    target_link_libraries(duckdb_graphar_loadable_extension
        graphar::graphar_shared
        -Wl,--disable-new-dtags
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
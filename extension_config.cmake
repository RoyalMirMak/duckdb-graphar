# Configuration for the DuckDB 'duckdb_graphar' extension.

# Include dependency paths set by Makefile (ARROW_ROOT, GRAPHAR_ROOT)
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/third_party/extension_deps.cmake")
    include("${CMAKE_CURRENT_LIST_DIR}/third_party/extension_deps.cmake")
endif()

# Set include paths with GraphAr and Arrow
set(GRAPHAR_INCLUDE_PATH "${GRAPHAR_ROOT}/include")
set(ARROW_INCLUDE_PATH "${ARROW_ROOT}/include")
set(EXTENSION_INCLUDE_PATH "${CMAKE_CURRENT_LIST_DIR}/include")

duckdb_extension_load(duckdb_graphar
    INCLUDE_DIR "${GRAPHAR_INCLUDE_PATH};${ARROW_INCLUDE_PATH};${EXTENSION_INCLUDE_PATH}"
    SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}"
    LOAD_TESTS
)

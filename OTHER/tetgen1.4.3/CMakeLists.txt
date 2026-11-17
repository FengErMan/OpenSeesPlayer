
add_library(tet STATIC tetgen.cxx predicates.cxx)

# [MinGW/GCC compatibility, 2026-11-17] GCC 13+ diagnoses legacy pointer to
# integer casts in bundled tetgen 1.4.3 as errors. Keep this relaxation scoped
# to tetgen and GNU; it lets the upstream code compile without changing it.
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  target_compile_options(tet PRIVATE -fpermissive)
endif()

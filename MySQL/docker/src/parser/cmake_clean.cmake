file(REMOVE_RECURSE
  "parser_entry"
  "parser_entry.pdb"
  "parser_entry.cc.o"
  "parser_entry.cc.i"
  "parser_entry.cc.s"
)

# Per-language clean rules from dependency scanning.
foreach(lang CXX)
  include(cmake_clean_${lang}.cmake OPTIONAL)
endforeach()


#include "../include/ast.h"
#include "sql/sql_ir_define.h"
#include "../include/mutate.h"
#include "../include/utils.h"
#include "../parser/parser_entry.h"
#include "../include/ir_wrapper.h"
#include "../oracle/mysql_oracle.h"
#include "../oracle/mysql_norec.h"

#include <fstream>
#include <iostream>
#include <ostream>
#include <string>

using namespace std;

IRWrapper ir_wrapper;

namespace Color {
enum Code {
  FG_RED = 31,
  FG_GREEN = 32,
  FG_BLUE = 34,
  FG_DEFAULT = 39,
  BG_RED = 41,
  BG_GREEN = 42,
  BG_BLUE = 44,
  BG_DEFAULT = 49
};
class Modifier {
  Code code;

public:
  Modifier(Code pCode) : code(pCode) {}
  friend std::ostream &operator<<(std::ostream &os, const Modifier &mod) {
    return os << "\033[" << mod.code << "m";
  }
};
} // namespace Color

Color::Modifier RED(Color::FG_RED);
Color::Modifier DEF(Color::FG_DEFAULT);

Mutator mutator;
class IR;

IR* test_parse(string &query) {

  vector<IR*> v_ir;

  int ret = run_parser(query, v_ir);
  // exec_query_command_entry(query, v_ir);

  if (v_ir.size() == 0 || ret != 0) {
    cerr << RED << "parse failed" << DEF << endl;
    return NULL;
  }

  cerr << "Current stmt ir size is: " << v_ir.size() << "\n\n\n";

  IR *root = v_ir.back();

  mutator.debug(root, 0);

  string tostring = root->to_string();
  if (tostring.size() <= 0) {
    cerr << RED << "tostring failed" << DEF << endl;
    root->deep_drop();
    return NULL;
  }
  cout << "tostring: >" << tostring << "<" << endl;
  return root;
}

bool try_validate_query(IR* cur_root) {
  /*
  pre_transform, post_transform and validate()
  */
  cerr << "\n\n\nRunning try_validate_query: \n\n";

  /*
  pre_transform, post_transform and validate()
  */

  mutator.pre_validate(); // Reset global variables for query sequence.

  ir_wrapper.set_ir_root(cur_root);
  vector<IR*> all_stmt_vec = ir_wrapper.get_stmt_ir_vec();

  for (IR* cur_trans_stmt : all_stmt_vec) {
    cerr << "\n\n\n\n\n\n\nCur stmt: " << cur_trans_stmt -> to_string() << "\n\n\n";
    if(!mutator.validate(cur_trans_stmt, true)) { // is_debug_info == true;
      cerr << "Error: g_mutator.validate returns errors. \n\n\n";
    } else {
      cout << "Validate passing: " << cur_trans_stmt->to_string() << "\n\n\n";
    }
    mutator.correct_insert_stmt(cur_trans_stmt);
  }

  // Clean up allocated resource.
  // post_trans_vec are being appended to the IR tree. Free up cur_root should take care of them.

  string validity = cur_root->to_string();
  if (validity.size() <= 0) {
    cerr << RED << "validate failed" << DEF << endl;
    cur_root->deep_drop();
    return false;
  }

  vector<string> valid_split = string_splitter(validity, ';');
  cout << "validate: >\n";
  for (string str : valid_split) {
    cout << str << ";\n";
  }
  cout << "<\n\n\n";

  cur_root->deep_drop();

  return true;

}

int main(int argc, char *argv[]) {
  parser_init("test-parser");

  if (argc != 2) {

    cout << "./test-parser sql-query-file" << endl;
    return -1;
  }

  // yydebug = 1;

  mutator.init("");

  string input(argv[1]);
  ifstream input_test(input);
  string line;

  vector<IR*> stmt_ir_vec;

  while (getline(input_test, line)) {

    if (line.find_first_of("--") == 0)
      continue;

    trim_string(line);

    if (line.size() == 0)
      continue;

    cout << "----------------------------------------" << endl;
    cout << ">>>>>>>>>>>" << line << "<\n";

    IR* cur_root = test_parse(line);
    if (cur_root == NULL) {
      cout << "Parsing failed. Ignored. \n";
      continue;
    }

    IR* cur_stmt = ir_wrapper.get_first_stmt_from_root(cur_root)->deep_copy();
    cerr << cur_stmt->to_string() << "\n\n\n";
    stmt_ir_vec.push_back(cur_stmt);

    cur_root->deep_drop();
  }

  IR* ir_root = ir_wrapper.reconstruct_ir_with_stmt_vec(stmt_ir_vec);
  // mutator.debug(ir_root, 0);

  if (!ir_root) {
    cerr << "Reconstructed ir_root is NULL!!!. Return NULL";
    return;
  }

  for (IR* ir : stmt_ir_vec) {
    ir->deep_drop();
  }

  mutator.p_oracle = new SQL_NOREC();
  mutator.p_oracle->ir_wrapper = ir_wrapper;

  cerr << "To_string: " << ir_root->to_string() << "\n\n\n";

  IR* root_extract = ir_root->deep_copy();
  string tmp = mutator.extract_struct(root_extract);
  root_extract->deep_drop();

  cerr << "Extract struct: " << tmp << "\n\n\n";

  // mutator.debug(ir_root);

  cerr << "\n\n\n";

  mutator.init_library();

  // Ignore validation right now. Will fix later.
  try_validate_query(ir_root);

  return 0;
}

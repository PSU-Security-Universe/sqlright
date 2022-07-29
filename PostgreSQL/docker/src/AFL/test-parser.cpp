#include "../include/ast.h"
#include "../include/define.h"
#include "../include/mutate.h"
#include "../include/utils.h"
#include "../oracle/postgres_oracle.h"
#include "../oracle/postgres_norec.h"
#include "../oracle/postgres_tlp.h"

#include <fstream>
#include <iostream>
#include <ostream>
#include <string>

extern int base_yydebug;

using namespace std;

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
SQL_ORACLE* p_oracle;

IR* test_parse(string &query) {

  vector<IR *> v_ir = mutator.parse_query_str_get_ir_set(query);
  if (v_ir.size() <= 0) {
    cerr << RED << "parse failed" << DEF << endl;
    return NULL;
  }

  IR *root = v_ir.back();

  mutator.debug(root, 0);

  string tostring = root->to_string();
  if (tostring.size() <= 0) {
    cerr << RED << "tostring failed" << DEF << endl;
    root->deep_drop();
    return NULL;
  }
  cout << "tostring: >" << tostring << "<" << endl;

  IR* root_ext_struct = root->deep_copy();
  string structure = mutator.extract_struct(root_ext_struct);
  if (structure.size() <= 0) {
    cerr << RED << "extract failed" << DEF << endl;
    root->deep_drop();
    root_ext_struct->deep_drop();
    return NULL;
  }
  cout << "structur: >" << structure << "<" << endl;
  root_ext_struct->deep_drop();
  
  IR* cur_root = root->deep_copy();
  root->deep_drop();
  return cur_root;
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

  p_oracle->init_ir_wrapper(cur_root);
  vector<IR*> all_stmt_vec = p_oracle->ir_wrapper.get_stmt_ir_vec();

  for (IR* cur_trans_stmt : all_stmt_vec) {
    cerr << "\n\n\n\n\n\n\nCur stmt: " << cur_trans_stmt -> to_string() << "\n\n\n";
    if(!mutator.validate(cur_trans_stmt, true)) { // is_debug_info == true;
      cerr << "Error: g_mutator.validate returns errors. \n\n\n";
    } else {
      cout << "Validate passing: " << cur_trans_stmt->to_string() << "\n\n\n";
    }
  }

  // Clean up allocated resource. 
  // post_trans_vec are being appended to the IR tree. Free up cur_root should take care of them.

  string validity = cur_root->to_string();
  if (validity.size() <= 0) {
    cerr << RED << "validate failed" << DEF << endl;
    cur_root->deep_drop();
    return false;
  }
  cout << "validate: >" << validity << "<" << endl;

  cur_root->deep_drop();

  return true;
  
}

int main(int argc, char *argv[]) {

  if (argc != 2) {

    cout << "./test-parser sql-query-file" << endl;
    return -1;
  }

  base_yydebug = 1;

  mutator.init("");

  string input(argv[1]);
  ifstream input_test(input);
  string line;

  p_oracle = new SQL_NOREC();

  mutator.set_p_oracle(p_oracle);
  p_oracle->set_mutator(&mutator);

  IR* root = NULL;

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
    if (root == NULL) {
      root = cur_root;
      // cout << "Save to root. \n\n\n";
    } else {
      IR* cur_stmt = p_oracle->ir_wrapper.get_first_stmt_from_root(cur_root);
      p_oracle->ir_wrapper.set_ir_root(root);
      p_oracle->ir_wrapper.append_stmt_at_end(cur_stmt->deep_copy());
      // cout << "Appended stmts. \n\n\n";
      // cout << "Cur to_string is: " << root->to_string() << "\n\n\n";
      cur_root->deep_drop();
    }
  }
  // if (root) root->deep_drop();

  // cout << "\n\n\n At the end of the parsing, we get to_string: \n" << root->to_string() << "\n\n\n";

  mutator.init_library();

  // Ignore validation right now. Will fix later. 
  try_validate_query(root);

  return 0;
}

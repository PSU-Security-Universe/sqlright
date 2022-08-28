#include "../include/mutator.h"
#include "../include/ast.h"
#include "../include/define.h"
#include "../include/utils.h"

#include "../parser/bison_parser.h"
#include "../parser/flex_lexer.h"

#include "../oracle/sqlite_tlp.h"
#include "../oracle/sqlite_index.h"
#include "../oracle/sqlite_likely.h"
#include "../oracle/sqlite_norec.h"
#include "../oracle/sqlite_oracle.h"
#include "../oracle/sqlite_rowid.h"
#include "../AFL/debug.h"

#include <sys/resource.h>
#include <sys/time.h>

#include <algorithm>
#include <assert.h>
#include <cfloat>
#include <climits>
#include <cstdio>
#include <deque>
#include <fstream>

using namespace std;

vector<string> Mutator::value_libary;
vector<string> Mutator::used_value_libary;
map<string, vector<string>> Mutator::m_tables;   // Table name to column name mapping.
map<string, vector<string>> Mutator::m_tables_with_tmp;   // Table name to column name mapping.
map<string, vector<string>> Mutator::m_table2index;   // Table name to index mapping.
vector<string> Mutator::v_table_names;  // All saved table names
vector<string> Mutator::v_table_names_single; // All used table names in one query statement.
vector<string> Mutator::v_create_table_names_single; // All created table names in the current query statement.
vector<string> Mutator::v_alias_names_single; // All alias name local to one query statement.
map<string, vector<string>> Mutator::m_table2alias_single;   // Table name to alias mapping.

/* Created table/view names, that is valid to only the single query stmts.
** Such as table created in WITH clause.
*/
vector<string> Mutator::v_create_table_names_single_with_tmp;
vector<string> Mutator::v_create_column_names_single_with_tmp;

IR *Mutator::deep_copy_with_record(const IR *root, const IR *record) {

  IR *left = NULL, *right = NULL, *copy_res;

  if (root->left_)
    left = deep_copy_with_record(root->left_, record);
  if (root->right_)
    right = deep_copy_with_record(root->right_, record);

  if (root->op_ != NULL)
    copy_res = new IR(
        root->type_,
        OP3(root->op_->prefix_, root->op_->middle_, root->op_->suffix_), left,
        right, root->f_val_, root->str_val_, root->mutated_times_);
  else
    copy_res = new IR(root->type_, NULL, left, right, root->f_val_,
                      root->str_val_, root->mutated_times_);

  copy_res->id_type_ = root->id_type_;

  if (root == record && record != NULL) {
    this->record_ = copy_res;
  }

  return copy_res;
}

bool Mutator::check_node_num(IR *root, unsigned int limit) {

  auto v_statements = extract_statement(root);
  bool is_good = true;

  for (auto stmt : v_statements) {
    // cerr << "For current query stmt: " << root->to_string() << endl;
    // cerr << calc_node(stmt) << endl;
    if (calc_node(stmt) > limit) {
      is_good = false;
      break;
    }
  }

  return is_good;
}

vector<string *> Mutator::mutate_all(vector<IR *> &v_ir_collector, u64& total_mutate_gen_num, u64& total_mutate_gen_failed) {
  vector<string *> res;
  set<unsigned long> res_hash;
  IR *root = v_ir_collector[v_ir_collector.size() - 1];

  // p_oracle->mark_all_valid_node(v_ir_collector);

  for (auto old_ir : v_ir_collector) {
    total_mutate_gen_num++;
    if (old_ir == root || old_ir->type_ == kProgram  ||
        old_ir->is_node_struct_fixed)
      {
        // cerr << "Aboard old_ir because it is root or kStatement, or node_struct_fixed. "
        //      << "v_ir_collector.size(): " << v_ir_collector.size() << ", "
        //      << "In func: Mutator::mutate_all(); \n";
        total_mutate_gen_failed++;
        continue;
      }

    vector<IR*> v_mutated_ir;

    if (
      old_ir->type_ == kStatementList
      // old_ir->type_ == kSelectCoreList ||
      // old_ir->type_ == kSelectCore
    ) {

      if (old_ir->type_ == kStatementList) {v_mutated_ir = mutate_stmtlist(root);} // They are all root(kProgram)!!!
      // else if (old_ir->type_ == kSelectCore || old_ir->type_ == kSelectCoreList) {
        // v_mutated_ir = mutate_selectcorelist(root, old_ir);
      // }
      // else {continue;}

      for (IR* mutated_ir : v_mutated_ir) {

        string tmp = mutated_ir->to_string();

        unsigned tmp_hash = hash(tmp);
        if (res_hash.find(tmp_hash) != res_hash.end()) {
          mutated_ir->deep_drop();
          // cerr << "Aboard old_ir because tmp_hash being saved before. "
          //      << "In func: Mutator::mutate_all(); \n";
          continue;
        }

        // cerr << "Currently mutating (stmtlist). After mutation, the generated str is: " << tmp << "\n\n\n";

        string *new_str = new string(tmp);
        res_hash.insert(tmp_hash);
        res.push_back(new_str);

        mutated_ir->deep_drop();

      }

    } else {
      v_mutated_ir = mutate(old_ir);

      for (auto new_ir : v_mutated_ir) {
        // total_mutate_gen_num++;

        if (!root->swap_node(old_ir, new_ir)) {
          new_ir->deep_drop();
          // total_mutate_gen_failed++;
          continue;
        }

        if (!check_node_num(root, 300)) {
          root->swap_node(new_ir, old_ir);
          new_ir->deep_drop();
          // total_mutate_gen_failed++;
          continue;
        }

        string tmp = root->to_string();
        unsigned tmp_hash = hash(tmp);
        if (res_hash.find(tmp_hash) != res_hash.end()) {
          root->swap_node(new_ir, old_ir);
          new_ir->deep_drop();
          // total_mutate_gen_failed++;
          continue;
        }

        string *new_str = new string(tmp);
        res_hash.insert(tmp_hash);
        res.push_back(new_str);

        root->swap_node(new_ir, old_ir);
        new_ir->deep_drop();
      }
    }
  }

  return res;
}

vector<IR *> Mutator::parse_query_str_get_ir_set(const string &query_str) {
  vector<IR *> ir_set;

  Program *p_strip_sql = parser(query_str.c_str());
  if (p_strip_sql == NULL)
    return ir_set;

  try {
    IR *root_ir = p_strip_sql->translate(ir_set);
  } catch (...) {
    p_strip_sql->deep_delete();

    for (auto ir : ir_set)
      ir->drop();

    ir_set.clear();
    return ir_set;
  }

  int unique_id_for_node = 0;
  for (auto ir : ir_set)
    ir->uniq_id_in_tree_ = unique_id_for_node++;

  p_strip_sql->deep_delete();
  return ir_set;
}

int Mutator::get_ir_libary_2D_hash_kStatement_size() {
  return this->ir_libary_2D_hash_[kStatement].size();
}

void Mutator::init(string f_testcase, string f_common_string, string pragma) {

  ifstream input_test(f_testcase);
  string line;

  // init lib from multiple sql
  while (getline(input_test, line)) {

    vector<IR *> v_ir = parse_query_str_get_ir_set(line);
    if (v_ir.size() <= 0) {
      cerr << "failed to parse: " << line << endl;
      continue;
    }

    string strip_sql = extract_struct(v_ir.back());
    v_ir.back()->deep_drop();
    v_ir.clear();

    v_ir = parse_query_str_get_ir_set(strip_sql);
    if (v_ir.size() <= 0) {
      cerr << "failed to parse after extract_struct:" << endl
           << line << endl
           << strip_sql << endl;
      continue;
    }

    add_all_to_library(v_ir.back());
    v_ir.back()->deep_drop();
  }

  // init utils::m_tables
  vector<string> v_tmp = {"haha1", "haha2", "haha3"};
  v_table_names.insert(v_table_names.end(), v_tmp.begin(), v_tmp.end());
  m_tables["haha1"] = {"fuzzing_column0_1", "fuzzing_column1_1",
                       "fuzzing_column2_1"};
  m_tables["haha2"] = {"fuzzing_column0_2", "fuzzing_column1_2",
                       "fuzzing_column2_2"};
  m_tables["haha3"] = {"fuzzing_column0_3", "fuzzing_column1_3",
                       "fuzzing_column2_3"};

  // init value_libary
  vector<string> value_lib_init = {std::to_string(0),
                                   std::to_string((unsigned long)LONG_MAX),
                                   std::to_string((unsigned long)ULONG_MAX),
                                   std::to_string((unsigned long)CHAR_BIT),
                                   std::to_string((unsigned long)SCHAR_MIN),
                                   std::to_string((unsigned long)SCHAR_MAX),
                                   std::to_string((unsigned long)UCHAR_MAX),
                                   std::to_string((unsigned long)CHAR_MIN),
                                   std::to_string((unsigned long)CHAR_MAX),
                                   std::to_string((unsigned long)MB_LEN_MAX),
                                   std::to_string((unsigned long)SHRT_MIN),
                                   std::to_string((unsigned long)INT_MIN),
                                   std::to_string((unsigned long)INT_MAX),
                                   std::to_string((unsigned long)SCHAR_MIN),
                                   std::to_string((unsigned long)SCHAR_MIN),
                                   std::to_string((unsigned long)UINT_MAX),
                                   std::to_string((unsigned long)FLT_MAX),
                                   std::to_string((unsigned long)DBL_MAX),
                                   std::to_string((unsigned long)LDBL_MAX),
                                   std::to_string((unsigned long)FLT_MIN),
                                   std::to_string((unsigned long)DBL_MIN),
                                   std::to_string((unsigned long)LDBL_MIN),
                                   "0",
                                   "10",
                                   "100"};
  value_libary.insert(value_libary.begin(), value_lib_init.begin(),
                      value_lib_init.end());

  string_libary.push_back("x");
  string_libary.push_back("v0");
  string_libary.push_back("v1");

  ifstream input_pragma("./pragma");
  string s;
  cout << "start init pragma" << endl;
  while (getline(input_pragma, s)) {
    if (s.empty())
      continue;
    auto pos = s.find('=');
    if (pos == string::npos)
      continue;

    string k = s.substr(0, pos - 1);
    string v = s.substr(pos + 2);
    if (find(cmds_.begin(), cmds_.end(), k) == cmds_.end())
      cmds_.push_back(k);
    m_cmd_value_lib_[k].push_back(v);
  }

  relationmap[id_table_alias_name] = id_top_table_name;
  relationmap[id_column_name] = id_top_table_name;
  relationmap[id_table_name] = id_top_table_name;
  relationmap[id_index_name] = id_top_table_name;
  relationmap[id_create_column_name] = id_create_table_name;
  relationmap[id_pragma_value] = id_pragma_name;
  relationmap[id_create_index_name] = id_create_table_name;
  relationmap[id_create_column_name_with_tmp]  = id_create_table_name_with_tmp;
  relationmap[id_trigger_name]  = id_top_table_name;
  relationmap[id_top_column_name]  = id_top_table_name;
  cross_map[id_top_table_name] = id_create_table_name;
  relationmap_alternate[id_create_column_name] = id_top_table_name;
  relationmap_alternate[id_create_index_name] = id_top_table_name;
  return;
}

vector<IR *> Mutator::mutate_stmtlist(IR *root) {
  IR* cur_root = nullptr;
  vector<IR *> res_vec;

  if (root == nullptr) {return res_vec;}

  // For strategy_delete
  cur_root = root->deep_copy();
  p_oracle->ir_wrapper.set_ir_root(cur_root);

  int rov_idx = get_rand_int(p_oracle->ir_wrapper.get_stmt_num());
  p_oracle->ir_wrapper.remove_stmt_at_idx_and_free(rov_idx);
  res_vec.push_back(cur_root);

  // For strategy_replace
  cur_root = root->deep_copy();
  p_oracle->ir_wrapper.set_ir_root(cur_root);

  vector<IR*> ori_stmt_list = p_oracle->ir_wrapper.get_stmt_ir_vec();
  IR* rep_old_ir = ori_stmt_list[get_rand_int(ori_stmt_list.size())];

  IR * new_stmt_ir = NULL;
  /* Get new insert statement. However, do not insert kSelectStatement */
  while (new_stmt_ir == NULL) {
    new_stmt_ir = get_from_libary_with_type(kStatement);
    if (new_stmt_ir == nullptr || new_stmt_ir->left_ == nullptr) {
      cur_root->deep_drop();
      return res_vec;
    }
    if (new_stmt_ir->left_->type_ == kSelectStatement) {
      new_stmt_ir->deep_drop();
      new_stmt_ir = NULL;
    }
    continue;
  }

  IR* new_stmt_ir_tmp = new_stmt_ir->left_->deep_copy();  // kStatement -> specific_stmt_type
  new_stmt_ir->deep_drop();
  new_stmt_ir = new_stmt_ir_tmp;

  // cerr << "Replacing rep_old_ir: " << rep_old_ir->to_string() << " to: " << new_stmt_ir->to_string() << ". \n\n\n";

  if(!p_oracle->ir_wrapper.replace_stmt_and_free(rep_old_ir, new_stmt_ir)){
    new_stmt_ir->deep_drop();
    cur_root->deep_drop();
    return res_vec;
  }
  res_vec.push_back(cur_root);

  // For strategy_insert
  cur_root = root->deep_copy();
  p_oracle->ir_wrapper.set_ir_root(cur_root);

  int insert_pos = get_rand_int(p_oracle->ir_wrapper.get_stmt_num());

  /* Get new insert statement. However, do not insert kSelectStatement */
  new_stmt_ir = NULL;
  while (new_stmt_ir == NULL) {
    new_stmt_ir = get_from_libary_with_type(kStatement);
    if (new_stmt_ir == nullptr || new_stmt_ir->left_ == nullptr) {
      cur_root->deep_drop();
      return res_vec;
    }
    if (new_stmt_ir->left_->type_ == kSelectStatement) {
      new_stmt_ir->deep_drop();
      new_stmt_ir = NULL;
    }
    continue;
  }
  new_stmt_ir_tmp = new_stmt_ir->left_->deep_copy();  // kStatement -> specific_stmt_type
  new_stmt_ir->deep_drop();
  new_stmt_ir = new_stmt_ir_tmp;

  // cerr << "Inserting stmt: " << new_stmt_ir->to_string() << "\n\n\n";

  if(!p_oracle->ir_wrapper.append_stmt_after_idx(new_stmt_ir, insert_pos)) {
    new_stmt_ir->deep_drop();
    cur_root->deep_drop();
    return res_vec;
  }
  res_vec.push_back(cur_root);

  return res_vec;

}

vector<IR *> Mutator::mutate_selectcorelist(IR* ir_root, IR *old_ir) {
  vector<IR*> res_vec;

  IR* cur_stmt = this->p_oracle->ir_wrapper.get_stmt_ir_from_child_ir(old_ir);
  vector<IR*> ori_stmt_vec = this->p_oracle->ir_wrapper.get_stmt_ir_vec(ir_root);
  int stmt_idx = 0;
  for (IR* ori_stmt_ir : ori_stmt_vec) {
    if (cur_stmt == ori_stmt_ir) break;
    stmt_idx++;
  }
  if (stmt_idx >= ori_stmt_vec.size()) {
    cerr << "Error: Cannot find the selectcore chosen stmt in the ir_root. Func: Mutator::mutate_selectcorelist(). \n";
    vector<IR*> tmp; return tmp;
  }

  // For strategy_delete
  IR* cur_root = ir_root->deep_copy();
  cur_stmt = this->p_oracle->ir_wrapper.get_stmt_ir_vec(cur_root)[stmt_idx];
  int num_selectcore = this->p_oracle->ir_wrapper.get_num_selectcore(cur_stmt);
  this->p_oracle->ir_wrapper.remove_selectcore_clause_at_idx_and_free(cur_stmt, get_rand_int(num_selectcore));
  res_vec.push_back(cur_root);

  // For strategy_replace
  cur_root = ir_root->deep_copy();
  cur_stmt = this->p_oracle->ir_wrapper.get_stmt_ir_vec(cur_root)[stmt_idx];
  num_selectcore = this->p_oracle->ir_wrapper.get_num_selectcore(cur_stmt);

  IR* new_selectcore_ir = get_from_libary_with_type(kSelectCore);
  if (new_selectcore_ir == nullptr) {
    cur_root->deep_drop();
    return res_vec;
  }
  string set_oper = "";
  switch (get_rand_int(4)) {
    case 0: set_oper = "UNION";
    case 1: set_oper = "UNION ALL";
    case 2: set_oper = "INTERSECT";
    case 3: set_oper = "EXCEPT";
  }
  int rep_idx = get_rand_int(num_selectcore);
  this->p_oracle->ir_wrapper.append_selectcore_clause_after_idx(cur_stmt, new_selectcore_ir, set_oper, rep_idx);
  this->p_oracle->ir_wrapper.remove_selectcore_clause_at_idx_and_free(cur_stmt, rep_idx);
  res_vec.push_back(cur_root);


  // For strategy_insert
  cur_root = ir_root->deep_copy();
  cur_stmt = this->p_oracle->ir_wrapper.get_stmt_ir_vec(cur_root)[stmt_idx];
  num_selectcore = this->p_oracle->ir_wrapper.get_num_selectcore(cur_stmt);
  new_selectcore_ir = get_from_libary_with_type(kSelectCore);
  if (new_selectcore_ir == nullptr) {
    cur_root->deep_drop();
    return res_vec;
  }
  set_oper = "";
  switch (get_rand_int(4)) {
    case 0: set_oper = "UNION";
    case 1: set_oper = "UNION ALL";
    case 2: set_oper = "INTERSECT";
    case 3: set_oper = "EXCEPT";
  }
  int ins_idx = get_rand_int(num_selectcore);
  this->p_oracle->ir_wrapper.append_selectcore_clause_after_idx(cur_stmt, new_selectcore_ir, set_oper, ins_idx);
  res_vec.push_back(cur_root);

  return res_vec;
}


vector<IR *> Mutator::mutate(IR *input) {
  vector<IR *> res;

  // if(!lucky_enough_to_be_mutated(input->mutated_times_)){
  //     return res; // return a empty set if the IR is not mutated
  // }
  IR* tmp_input = NULL;

  tmp_input = strategy_delete(input);
  if (tmp_input != NULL)
    {res.push_back(tmp_input);}

  tmp_input = strategy_insert(input);
  if (tmp_input != NULL)
    {res.push_back(tmp_input);}

  tmp_input = strategy_replace(input);
  if (tmp_input != NULL)
    {res.push_back(tmp_input);}

  // may do some simple filter for res, like removing some duplicated cases

  input->mutated_times_ += res.size();
  for (auto i : res) {
    if (i == NULL)
      continue;
    i->mutated_times_ = input->mutated_times_;
  }
  return res;
}

void Mutator::pre_validate() {
  // Reset components that is local to the one query sequence.
  reset_counter();
  reset_database();
  return;
}

vector<IR*> Mutator::pre_fix_transform(IR * root, vector<STMT_TYPE>& stmt_type_vec) {

  p_oracle->init_ir_wrapper(root);
  vector<IR*> all_trans_vec;
  vector<IR*> all_statements_vec = p_oracle->ir_wrapper.get_stmt_ir_vec();

  // cerr << "In func: Mutator::pre_fix_transform(IR * root, vector<STMT_TYPE>& stmt_type_vec), we have all_statements_vec size(): "
  //     << all_statements_vec.size() << "\n\n\n";

  for (IR* cur_stmt : all_statements_vec) {
    /* Identify oracle related statements. Ready for transformation. */
    bool is_oracle_select = false, is_oracle_normal = false;
    if (p_oracle->is_oracle_normal_stmt(cur_stmt)) {is_oracle_normal = true; stmt_type_vec.push_back(ORACLE_NORMAL);}
    else if (p_oracle->is_oracle_select_stmt(cur_stmt)) {is_oracle_select = true; stmt_type_vec.push_back(ORACLE_SELECT);}
    else {stmt_type_vec.push_back(NOT_ORACLE);}

    /* Apply pre_fix_transformation functions. */
    IR* trans_IR = nullptr;
    if (is_oracle_normal) {
      trans_IR = p_oracle->pre_fix_transform_normal_stmt(cur_stmt); // Deep_copied
    } else if (is_oracle_select) {
      trans_IR = p_oracle->pre_fix_transform_select_stmt(cur_stmt); // Deep_copied
    }
    /* If no pre_fix_transformation is needed, directly use the original cur_root. */
    if (trans_IR == nullptr ){
      trans_IR = cur_stmt->deep_copy();
    }
    all_trans_vec.push_back(trans_IR);
  }

  return all_trans_vec;
}

vector<vector<vector<IR*>>> Mutator::post_fix_transform(vector<IR*>& all_pre_trans_vec, vector<STMT_TYPE>& stmt_type_vec) {
  int total_run_count = p_oracle->get_mul_run_num();
  vector<vector<vector<IR*>>> all_trans_vec_all_run;
  for (int run_count = 0; run_count < total_run_count; run_count++){
    all_trans_vec_all_run.push_back(this->post_fix_transform(all_pre_trans_vec, stmt_type_vec, run_count)); // All deep_copied.
  }
  return all_trans_vec_all_run;
}

vector<vector<IR*>> Mutator::post_fix_transform(vector<IR*>& all_pre_trans_vec, vector<STMT_TYPE>& stmt_type_vec, int run_count) {
  // Apply post_fix_transform functions.
  vector<vector<IR*>> all_post_trans_vec;
  vector<int> v_stmt_to_rov;
  for (int i = 0; i < all_pre_trans_vec.size(); i++) { // Loop through across statements.
    IR* cur_pre_trans_ir = all_pre_trans_vec[i];
    vector<IR*> post_trans_stmt_vec;
    assert(cur_pre_trans_ir != nullptr);

    bool is_oracle_normal = false, is_oracle_select = false;
    if (stmt_type_vec[i] == ORACLE_SELECT) {is_oracle_select = true;}
    else if (stmt_type_vec[i] == ORACLE_NORMAL) {is_oracle_normal = true;}

    if (is_oracle_normal) {
      // cerr << "Debug: For cur_pre_trans_ir: " << cur_pre_trans_ir->to_string() << ", oracle_normal. \n\n\n";
      post_trans_stmt_vec = p_oracle->post_fix_transform_normal_stmt(cur_pre_trans_ir, run_count); // All deep_copied
    } else if (is_oracle_select) {
      // cerr << "Debug: For cur_pre_trans_ir: " << cur_pre_trans_ir->to_string() << ", oracle_SELECT. \n\n\n";
      post_trans_stmt_vec = p_oracle->post_fix_transform_select_stmt(cur_pre_trans_ir, run_count); // All deep_copied
    } else {
      // cerr << "Debug: For cur_pre_trans_ir: " << cur_pre_trans_ir->to_string() << ", NOT. \n\n\n";
      post_trans_stmt_vec.push_back(cur_pre_trans_ir->deep_copy());
    }

    // if (post_trans_stmt_vec.size() == 0){
    //   post_trans_stmt_vec.push_back(cur_pre_trans_ir->deep_copy());
    //   post_trans_stmt_vec.push_back(cur_pre_trans_ir->deep_copy());
    //   // continue;
    // }
    if (post_trans_stmt_vec.size() > 0) {
      all_post_trans_vec.push_back(post_trans_stmt_vec);
    } else {
      v_stmt_to_rov.push_back(i);
    }
  }

  vector<STMT_TYPE> new_stmt_type_vec;
  for (int i = 0; i < stmt_type_vec.size(); i++) {
    if (find(v_stmt_to_rov.begin(), v_stmt_to_rov.end(), i) != v_stmt_to_rov.end()) {
      continue;
    }
    new_stmt_type_vec.push_back(stmt_type_vec[i]);
  }
  stmt_type_vec = new_stmt_type_vec;

  return all_post_trans_vec;
}

/* Handle and fix one single query statement. */
bool Mutator::validate(IR* cur_trans_stmt, bool is_debug_info) {

  if (cur_trans_stmt == nullptr) {return false;}
  bool res = true;
  /* Fill in concret values into the query. */
  vector<vector<IR*>> ordered_all_subquery_ir;

  fix_preprocessing(cur_trans_stmt, relationmap, ordered_all_subquery_ir);

  // Debug
  // cerr << "After Mutator::fix_preprocessing, we have ordered_all_subquery_ir.size(): " << ordered_all_subquery_ir.size() << "\n\n\n";

  res = fix_dependency(cur_trans_stmt, ordered_all_subquery_ir, is_debug_info) && res;
  fix(cur_trans_stmt);

  this->resolve_drop_statement(cur_trans_stmt, is_debug_info);
  this->resolve_alter_statement(cur_trans_stmt, is_debug_info);

  return res;
}

bool Mutator::finalize_transform(IR* root, vector<vector<IR*>> all_post_trans_vec) {
  if (root == NULL) {return false;}
  p_oracle->init_ir_wrapper(root);
  for (vector<IR*> post_trans_vec : all_post_trans_vec) {
  /* Append the transformed statements into the IR tree. */
    int idx_offset = 0; // Consider the already inserted transformed statements.
    for (int i = 1; i < post_trans_vec.size(); i++) { // Start from idx=1, the first element is the original stmt.
      int cur_trans_idx = p_oracle->ir_wrapper.get_stmt_idx(post_trans_vec[0]);
      if (cur_trans_idx == -1) {
        cerr << "Error: cannot find the current statement in the IR tree! Abort finalize_transform() function. \n";
        // Error.
        return false;
      }
      p_oracle->ir_wrapper.append_stmt_after_idx(post_trans_vec[i], cur_trans_idx + idx_offset);
      idx_offset++;
    }
  }
  return true;
}

pair<string, string> Mutator::ir_to_string(IR* root, vector<vector<IR*>> all_post_trans_vec, const vector<STMT_TYPE>& stmt_type_vec) {
  // Final step, IR_to_string function.
  string output_str_mark, output_str_no_mark;
  for (int i = 0; i < all_post_trans_vec.size(); i++) { // Loop between different statements.
    vector<IR*> post_trans_vec = all_post_trans_vec[i];
    bool is_oracle_select = false;
    if (stmt_type_vec[i] == ORACLE_SELECT) {is_oracle_select = true;}
    int count = 0;
    int trans_count = 0;
    for (IR* cur_trans_stmt : post_trans_vec) {  // Loop between different transformations.
      string tmp = cur_trans_stmt->to_string();
      if (is_oracle_select) {
        output_str_mark += "SELECT 'BEGIN VERI " + to_string(count) + "'; \n";
        output_str_mark  += tmp + "; \n";
        output_str_mark += "SELECT 'END VERI " + to_string(count) + "'; \n";
        if (trans_count == 0)
          {output_str_no_mark += tmp + "; \n";}
        count++;
      } else {
        output_str_mark += tmp + "; \n";
        if (trans_count == 0)
          {output_str_no_mark += tmp + "; \n";}
      }
      trans_count++;
    }
  }
  pair<string, string> output_str_pair =  make_pair(output_str_mark, output_str_no_mark);
  return output_str_pair;
}

// find tree node whose identifier type can be handled
//
// NOTE: identifier type is different from IR type
//
static void collect_ir(IR *root, set<IDTYPE> &type_to_fix,
                       vector<IR *> &ir_to_fix) {
  auto idtype = root->id_type_;

  if (root->left_) {
    collect_ir(root->left_, type_to_fix, ir_to_fix);
  }

  if (type_to_fix.find(idtype) != type_to_fix.end()) {
    ir_to_fix.push_back(root);
  }

  if (root->right_) {
    collect_ir(root->right_, type_to_fix, ir_to_fix);
  }
}

static vector<IR*> search_mapped_ir_in_stmt(IR *ir, IDTYPE idtype) {
  // Find the root for the current statement.
  IR* cur_ir = ir;
  while (cur_ir->parent_ != nullptr) {
    if (cur_ir->type_ == kStatement) {
      break;
    }
    cur_ir = cur_ir->parent_;
  }

  deque<IR *> to_search = {cur_ir};
  vector<IR* > res;

  while (to_search.empty() != true) {
    auto node = to_search.front();
    to_search.pop_front();

    if (node->id_type_ == idtype)
      {res.push_back(node);}

    if (node->left_)
      to_search.push_back(node->left_);
    if (node->right_)
      to_search.push_back(node->right_);
  }

  return res;
}

// propagate relationship between subqueries. The logic is correct
//
// graph.second relies on graph.first
// crossmap.first relies on crossmap.second
//
// so we should propagate the dependency via
// graph.second -> graph.first = crossmap.first -> crossmap.second
//
// This function only consult cross_map, thus only care about [id_top_table_name] -> [id_create_table_name] across statements.
void cross_stmt_map(map<IR *, set<IR *>> &graph, map<IR *, set<IR *>> &cross_graph, vector<IR *> &ir_to_fix,
                    map<IDTYPE, IDTYPE> &cross_map) {
  for (auto m : cross_map) {
    vector<IR *> value;
    vector<IR *> key;

    // Why searching for graph/cross_graph for saved matched type?
    for (auto &k : cross_graph) { // graph is local, thus is always empty. Only cross_graph save all the cross statements' IR.
      if (k.first->id_type_ == m.first) {
        key.push_back(k.first);
      }
    }

    for (auto &k : ir_to_fix) {
      if (k->id_type_ == m.second) {
        value.push_back(k);
      }
    }

    if (key.empty())
      return;
    for (auto val : value) {
      graph[key[get_rand_int(key.size())]].insert(val);
      cross_graph[key[get_rand_int(key.size())]].insert(val);
    }
  }
}

// randomly build connection between top_table_name and table_name
//
// top_table_name does not rely on others, while table_name relies on some
// top_table_name
//
// Local to one single statement.
void toptable_map(map<IR *, set<IR *>> &graph, vector<IR *> &ir_to_fix,
                  vector<IR *> &toptable) {
  vector<IR *> tablename;
  for (auto ir : ir_to_fix) {
    if (ir->id_type_ == id_table_name) {
      tablename.push_back(ir);
    } else if (ir->id_type_ == id_top_table_name) {
      toptable.push_back(ir);
    }
  }
  if (toptable.empty())
    return;
  for (auto k : tablename) {
    auto r = get_rand_int(toptable.size());
    graph[toptable[r]].insert(k);
  }
}

string Mutator::remove_node_from_tree_by_index(string oracle_query,
                                               int remove_index) {

  vector<IR *> tree = parse_query_str_get_ir_set(oracle_query);
  IR *root = tree[tree.size() - 1];
  deque<IR *> bfs = {root};
  string result = "";

  int current_index = 0;
  while (bfs.empty() != true) {
    auto node = bfs.front();
    bfs.pop_front();

    if (current_index == remove_index) {
      root->detach_node(node);
      result = root->to_string();
      root->deep_drop();
      return result;
    }
    current_index++;

    if (node->left_)
      bfs.push_back(node->left_);

    if (node->right_)
      bfs.push_back(node->right_);
  }

  return result;
}

set<string> Mutator::get_minimize_string_from_tree(string oracle_query) {
  set<string> res;
  vector<IR *> irtree = parse_query_str_get_ir_set(oracle_query);

  for (int i = 0; i < irtree.size(); ++i) {
    string new_string = remove_node_from_tree_by_index(oracle_query, i);
    // vector<IR *> irset = parse_query_str_get_ir_set(new_string);
    // if (irset.size() == 0)
    //   continue ;

    res.insert(new_string);
    // cout << "new string " << i << " : " << new_string.c_str() << endl;
  }
  return res;
}

vector<IR *> Mutator::extract_statement(IR *root) {
  vector<IR *> res;
  deque<IR *> bfs = {root};

  while (bfs.empty() != true) {
    auto node = bfs.front();
    bfs.pop_front();

    if (node->type_ == kStatement)
      res.push_back(node);
    if (node->left_)
      bfs.push_back(node->left_);
    if (node->right_)
      bfs.push_back(node->right_);
  }

  return res;
}

// find all subqueries (SELECT statement)
//
// find all SelectCore subtree, and save them in the returned vector
// save the mapping from the subtree address to subtree into 2nd arg
//
vector<IR *> Mutator::cut_subquery(IR *cur_stmt, TmpRecord &m_save) {

  vector<IR *> res;
  vector<IR *> v_statements{cur_stmt};

  // Debug
  // cerr << "In func: Mutator::cut_subquery, we have current v_statements: " << v_statements[0]->to_string() << "\n";
  // cerr << "In func: Mutator::cut_subquery, after getting and reverse v_statements, we get v_statements.size(): "
  //      << v_statements.size() << "\n";

  for (auto &stmt : v_statements) {
    deque<IR *> q_bfs = {stmt};
    res.push_back(stmt);

    while (!q_bfs.empty()) {
      auto cur = q_bfs.front();
      q_bfs.pop_front();

      if (cur->left_) {
        q_bfs.push_back(cur->left_);
        if (cur->left_->type_ == kSelectStatement) {
          res.push_back(cur->left_);
          m_save[cur] = make_pair(0, cur->left_);
          cur->detach_node(cur->left_);
        }
      }

      if (cur->right_) {
        q_bfs.push_back(cur->right_);
        if (cur->right_->type_ == kSelectStatement) {
          res.push_back(cur->right_);
          m_save[cur] = make_pair(1, cur->right_);
          cur->detach_node(cur->right_);
        }
      }
    }
  }
  return res;
}


// Recover the subqueries, which were disconnected before.
bool Mutator::add_back(TmpRecord &m_save) {

  for (auto &i : m_save) {

    IR *parent = i.first;
    int is_right = i.second.first;
    IR *child = i.second.second;

    if (is_right)
      parent->update_right(child);
    else
      parent->update_left(child);
  }

  return true;
}

// build the dependency graph between names, for example, the column name
// should belong to one column of one already created table. The dependency
// is denfined in the "relationmap" global variable
//
// The result is a map, where the value is a set of IRs, which are dependents
// of the key
void
Mutator::fix_preprocessing(IR *root, map<IDTYPE, IDTYPE> &relationmap,
                                vector<vector<IR*>> &ordered_all_subquery_ir) {

  map<IR *, set<IR *>> graph;
  TmpRecord m_save;
  set<IDTYPE> type_to_fix;

  for (auto &iter : relationmap) {
    type_to_fix.insert(iter.first);
    type_to_fix.insert(iter.second);
  }

  for (auto &iter : relationmap_alternate) {
    type_to_fix.insert(iter.first);
    type_to_fix.insert(iter.second);
  }

  vector<IR *> subqueries = cut_subquery(root, m_save);
  /*
  ** The original order of the subqueries are from outer statement to inner statement.
  ** We change the order so it should be from parent to child subqueries.
  */
  // reverse(subqueries.begin(), subqueries.end());

  // cerr << "In Mutator::fix_preprocessing, we have subqueries.size(): " << subqueries.size() << "\n";

  for (IR *subquery : subqueries) {
    vector<IR *> ir_to_fix;
    collect_ir(subquery, type_to_fix, ir_to_fix);
    ordered_all_subquery_ir.push_back(ir_to_fix);
  }
  add_back(m_save);
  return;
}

IR *Mutator::strategy_delete(IR *cur) {
  assert(cur);
  MUTATESTART

  DOLEFT
  res = cur->deep_copy();
  if (res->left_ != NULL)
    res->left_->deep_drop();
  res->update_left(NULL);

  DORIGHT
  res = cur->deep_copy();
  if (res->right_ != NULL)
    res->right_->deep_drop();
  res->update_right(NULL);

  DOBOTH
  res = cur->deep_copy();
  if (res->left_ != NULL)
    res->left_->deep_drop();
  if (res->right_ != NULL)
    res->right_->deep_drop();
  res->update_left(NULL);
  res->update_right(NULL);

  MUTATEEND
}

IR *Mutator::strategy_insert(IR *cur) {

  assert(cur);

  if (cur->type_ == kStatementList) {
    auto new_right = get_from_libary_with_left_type(cur->type_);
    if (new_right != NULL) {
      auto res = cur->deep_copy();
      auto new_res = new IR(kStatementList, OPMID(";"), res, new_right);
      return new_res;
    }
  }

  if (cur->right_ == NULL && cur->left_ != NULL) {
    auto left_type = cur->left_->type_;
    auto new_right = get_from_libary_with_left_type(left_type);
    if (new_right != NULL) {
      auto res = cur->deep_copy();
      res->update_right(new_right);
      return res;
    }
  }

  else if (cur->right_ != NULL && cur->left_ == NULL) {
    auto right_type = cur->right_->type_;
    auto new_left = get_from_libary_with_right_type(right_type);
    if (new_left != NULL) {
      auto res = cur->deep_copy();
      res->update_left(new_left);
      return res;
    }
  }

  return get_from_libary_with_type(cur->type_);
}

IR *Mutator::strategy_replace(IR *cur) {
  assert(cur);

  MUTATESTART

  DOLEFT
  res = cur->deep_copy();
  if (res->left_ == NULL){
    res->deep_drop();
    return NULL;
  }

  auto new_node = get_from_libary_with_type(res->left_->type_);

  if (new_node != NULL) {
    if (res->left_ != NULL) {
      new_node->id_type_ = res->left_->id_type_;
    }
  } else { // new_node == NULL
    res->deep_drop();
    return NULL;
  }
  if (res->left_ != NULL)
    res->left_->deep_drop();
  res->update_left(new_node);

  DORIGHT
  res = cur->deep_copy();
  if (res->right_ == NULL) {
    res->deep_drop();
    return NULL;
  }

  auto new_node = get_from_libary_with_type(res->right_->type_);
  if (new_node != NULL) {
    if (res->right_ != NULL) {
      new_node->id_type_ = res->right_->id_type_;
    }
  } else { // new_node == NULL
    res->deep_drop();
    return NULL;
  }
  if (res->right_ != NULL)
    res->right_->deep_drop();
  res->update_right(new_node);

  DOBOTH
  res = cur->deep_copy();
  if (res->left_ == NULL || res->right_ == NULL) {
    res->deep_drop();
    return NULL;
  }

  auto new_left = get_from_libary_with_type(res->left_->type_);
  auto new_right = get_from_libary_with_type(res->right_->type_);

  if (new_left != NULL) {
    if (res->left_ != NULL) {
      new_left->id_type_ = res->left_->id_type_;
    }
  } else { // new_left == NULL
    if (new_right != NULL) {
      new_right->deep_drop();
    }
    res->deep_drop();
    return NULL;
  }

  if (new_right != NULL) {
    if (res->right_ != NULL) {
      new_right->id_type_ = res->right_->id_type_;
    }
  } else { // new_right == NULL
    if (new_left != NULL) {
      new_left->deep_drop();
    }
    res->deep_drop();
    return NULL;
  }

  if (res->left_)
    res->left_->deep_drop();
  if (res->right_)
    res->right_->deep_drop();
  res->update_left(new_left);
  res->update_right(new_right);

  MUTATEEND

  return res;
}

bool Mutator::lucky_enough_to_be_mutated(unsigned int mutated_times) {
  if (get_rand_int(mutated_times + 1) < LUCKY_NUMBER) {
    return true;
  }
  return false;
}

IR *Mutator::get_from_libary_with_type(IRTYPE type_) {
  /* Given a data type, return a randomly selected prevously seen IR node that
     matched the given type. If nothing has found, return an empty
     kStringLiteral.
  */

  vector<IR *> current_ir_set;
  IR *current_ir_root;
  vector<pair<string *, int>> &all_matching_node = real_ir_set[type_];
  IR *return_matched_ir_node = NULL;

  if (all_matching_node.size() > 0) {
    /* Pick a random matching node from the library. */
    int random_idx = get_rand_int(all_matching_node.size());
    std::pair<string *, int> &selected_matched_node =
        all_matching_node[random_idx];
    string *p_current_query_str = selected_matched_node.first;
    int unique_node_id = selected_matched_node.second;

    /* Reconstruct the IR tree. */
    current_ir_set = parse_query_str_get_ir_set(*p_current_query_str);
    if (current_ir_set.size() <= 0) {
      // cerr << "Error: with_type_ Parsing the saved string failed. str: " << *p_current_query_str << " !!!" << "\n\n\n";
      return NULL;
    }
    current_ir_root = current_ir_set.back();

    /* Retrive the required node, deep copy it, clean up the IR tree and return.
     */
    IR *matched_ir_node = current_ir_set[unique_node_id];
    if (matched_ir_node != NULL) {
      if (matched_ir_node->type_ != type_) {
        current_ir_root->deep_drop();
        // cerr << "Error: with_type_ Column type mismatched!!!" << "\n\n\n";
        return NULL;
      }
      // return_matched_ir_node = matched_ir_node->deep_copy();
      return_matched_ir_node = matched_ir_node;
      current_ir_root->detach_node(return_matched_ir_node);
    }

    current_ir_root->deep_drop();

    if (return_matched_ir_node != NULL) {
      // cerr << "\n\n\nSuccessfuly with_type: with string: " << return_matched_ir_node->to_string() << endl;
      // cerr << "Retunning with_type_ ir_type: " << get_string_by_ir_type(type_) << " with node: " << return_matched_ir_node->to_string() << "\n\n\n";
      return return_matched_ir_node;
    }
  }

  return NULL;
}

IR *Mutator::get_from_libary_with_left_type(IRTYPE type_) {
  /* Given a left_ type, return a randomly selected prevously seen right_ node
     that share the same parent. If nothing has found, return NULL.
  */

  vector<IR *> current_ir_set;
  IR *current_ir_root;
  vector<pair<string *, int>> &all_matching_node = left_lib_set[type_];
  IR *return_matched_ir_node = NULL;

  if (all_matching_node.size() > 0) {
    /* Pick a random matching node from the library. */
    int random_idx = get_rand_int(all_matching_node.size());
    std::pair<string *, int> &selected_matched_node =
        all_matching_node[random_idx];
    string *p_current_query_str = selected_matched_node.first;
    int unique_node_id = selected_matched_node.second;

    /* Reconstruct the IR tree. */
    current_ir_set = parse_query_str_get_ir_set(*p_current_query_str);
    if (current_ir_set.size() <= 0) {
      // cerr << "Error: Parsing the saved string failed. str: " << *p_current_query_str << " !!!" << "\n\n\n";
      return NULL;
    }
    current_ir_root = current_ir_set.back();

    /* Retrive the required node, deep copy it, clean up the IR tree and return.
     */
    IR *matched_ir_node = current_ir_set[unique_node_id];
    if (matched_ir_node != NULL) {
      if (matched_ir_node->left_->type_ != type_) {
        current_ir_root->deep_drop();
        // cerr << "Error: Column type mismatched!!!" << "\n\n\n";
        return NULL;
      }
      // return_matched_ir_node = matched_ir_node->right_->deep_copy();;  // Not
      // returnning the matched_ir_node itself, but its right_ child node!
      return_matched_ir_node = matched_ir_node->right_;
      current_ir_root->detach_node(return_matched_ir_node);
    }

    current_ir_root->deep_drop();

    if (return_matched_ir_node != NULL) {
      // cerr << "Retunning ir_type: " << get_string_by_ir_type(type_) << " with node: " << return_matched_ir_node->to_string() << "\n\n\n";
      return return_matched_ir_node;
    }
  } else {
    // cerr << "Error: Cannot find saved lib with type_ " << get_string_by_ir_type(type_) << "\n\n\n";
  }

  return NULL;
}

IR *Mutator::get_from_libary_with_right_type(IRTYPE type_) {
  /* Given a right_ type, return a randomly selected prevously seen left_ node
     that share the same parent. If nothing has found, return NULL.
  */

  vector<IR *> current_ir_set;
  IR *current_ir_root;
  vector<pair<string *, int>> &all_matching_node = right_lib_set[type_];
  IR *return_matched_ir_node = NULL;

  if (all_matching_node.size() > 0) {
    /* Pick a random matching node from the library. */
    std::pair<string *, int> &selected_matched_node =
        all_matching_node[get_rand_int(all_matching_node.size())];
    string *p_current_query_str = selected_matched_node.first;
    int unique_node_id = selected_matched_node.second;

    /* Reconstruct the IR tree. */
    current_ir_set = parse_query_str_get_ir_set(*p_current_query_str);
    if (current_ir_set.size() <= 0) {
      // cerr << "Error: Parsing the saved string failed. str: " << *p_current_query_str << " !!!" << "\n\n\n";
      return NULL;
    }
    current_ir_root = current_ir_set.back();

    /* Retrive the required node, deep copy it, clean up the IR tree and return.
     */
    IR *matched_ir_node = current_ir_set[unique_node_id];
    if (matched_ir_node != NULL) {
      if (matched_ir_node->right_->type_ != type_) {
        current_ir_root->deep_drop();
        // cerr << "Error: Column type mismatched!!!" << "\n\n\n";
        return NULL;
      }
      // return_matched_ir_node = matched_ir_node->left_->deep_copy();  // Not
      // returnning the matched_ir_node itself, but its left_ child node!
      return_matched_ir_node = matched_ir_node->left_;
      current_ir_root->detach_node(return_matched_ir_node);
    }

    current_ir_root->deep_drop();

    if (return_matched_ir_node != NULL) {
      // cerr << "Retunning ir_type: " << get_string_by_ir_type(type_) << " with node: " << return_matched_ir_node->to_string() << "\n\n\n";
      return return_matched_ir_node;
    }
  } else {
    // cerr << "Error: Cannot find saved lib with type_ " << get_string_by_ir_type(type_) << "\n\n\n";
  }

  return NULL;
}

unsigned long Mutator::get_library_size() {
  unsigned long res = 0;

  for (auto &i : real_ir_set) {
    res += 1;
  }

  for (auto &i : left_lib_set) {
    res += 1;
  }

  for (auto &i : right_lib_set) {
    res += 1;
  }

  return res;
}

bool Mutator::is_stripped_str_in_lib(string stripped_str) {
  stripped_str = extract_struct(stripped_str);
  unsigned long str_hash = hash(stripped_str);
  if (stripped_string_hash_.find(str_hash) != stripped_string_hash_.end())
    return true;
  stripped_string_hash_.insert(str_hash);
  return false;
}

static bool isEmpty(string &str) {

  for (char &c : str)
    if (!isspace(c) && c != '\n' && c != '\0')
      return false;

  return true;
}

/* add_to_library supports only one stmt at a time,
 * add_all_to_library is responsible to split the
 * the current IR tree into single query stmts.
 * This function is not responsible to free the input IR tree.
 */
void Mutator::add_all_to_library(IR *ir, const vector<int> &explain_diff_id,
                                 const ALL_COMP_RES &all_comp_res) {

  add_all_to_library(ir->to_string(), explain_diff_id, all_comp_res);
}

/*  Save an interesting query stmt into the mutator library.
 *
 *   The uniq_id_in_tree_ should be, more idealy, being setup and kept unchanged
 * once an IR tree has been reconstructed. However, there are some difficulties
 * there. For example, how to keep the uniqueness and the fix order of the
 * unique_id_in_tree_ for each node in mutations. Therefore, setting and
 * checking the uniq_id_in_tree_ variable in every nodes of an IR tree are only
 * done when necessary by calling this funcion and
 * get_from_library_with_[_,left,right]_type. We ignore this unique_id_in_tree_
 * in other operations of the IR nodes. The unique_id_in_tree_ is setup based on
 * the order of the ir_set vector, returned from Program*->translate(ir_set).
 *
 */

void Mutator::add_all_to_library(string whole_query_str,
                                 const vector<int> &explain_diff_id,
                                 const ALL_COMP_RES &all_comp_res) {

  if (isEmpty(whole_query_str))
    return;

  int i = 0; // For counting oracle valid stmt IDs.

  vector<string> queries_vector = string_splitter(whole_query_str, ';');
  for (auto current_query : queries_vector) {

    trim_string(current_query);
    current_query += ";";

    // check the validity of the IR here
    // The unique_id_in_tree_ variable are being set inside the parsing func.
    vector<IR *> ir_set = parse_query_str_get_ir_set(current_query);
    if (ir_set.size() == 0)
      continue;

    IR *root = ir_set.back();
    IR* cur_stmt = root->left_->left_->left_; // kProgram -> kStatementList -> kStatement -> specific_statement_type_

    if (p_oracle->is_oracle_select_stmt(cur_stmt)) {

      // if (all_comp_res.v_res.size() > i) {
      //   if (all_comp_res.v_res[i].comp_res == ORA_COMP_RES::Error ||
      //   all_comp_res.v_res[i].comp_res == ORA_COMP_RES::IGNORE) {
      //     ++i;
      //     // cerr << "Ignoring: " << i << current_query << endl;
      //     continue;
      //   }
      // }

      if (std::find(explain_diff_id.begin(), explain_diff_id.end(), i) !=
          explain_diff_id.end()) {
        // cerr << "Saving with statement: " << i << current_query << endl;
        add_to_valid_lib(root, current_query, true);
      } else {
        // cerr << "Saving with statement: " << i << current_query << endl;
        add_to_valid_lib(root, current_query, false);
      }
      ++i; // For counting oracle valid stmt IDs.
    } else {
      add_to_library(root, current_query);
    }

    root->deep_drop();
  }
}

void Mutator::add_to_valid_lib(IR *ir, string &select,
                               const bool is_explain_diff) {

  unsigned long p_hash = hash(select);

  if (oracle_select_hash.find(p_hash) != oracle_select_hash.end())
    return;

  oracle_select_hash[p_hash] = true;

  string *new_select = new string(select);

  all_query_pstr_set.insert(new_select);
  all_valid_pstr_vec.push_back(new_select);

  if (is_explain_diff && use_cri_val)
    all_cri_valid_pstr_vec.push_back(new_select);

  // if (this->dump_library) {
  //   std::ofstream f;
  //   f.open("./oracle-select", std::ofstream::out | std::ofstream::app);
  //   f << *new_select << endl;
  //   f.close();
  // }

  add_to_library_core(ir, new_select);

  return;
}

void Mutator::add_to_library(IR *ir, string &query) {

  if (query == "")
    return;

  NODETYPE p_type = ir->type_;
  unsigned long p_hash = hash(query);

  if (ir_libary_2D_hash_[p_type].find(p_hash) !=
      ir_libary_2D_hash_[p_type].end()) {
    /* query not interesting enough. Ignore it and clean up. */
    return;
  }
  ir_libary_2D_hash_[p_type].insert(p_hash);

  string *p_query_str = new string(query);
  all_query_pstr_set.insert(p_query_str);
  // all_valid_pstr_vec.push_back(p_query_str);

  // if (this->dump_library) {
  //   std::ofstream f;
  //   f.open("./normal-lib", std::ofstream::out | std::ofstream::app);
  //   f << *p_query_str << endl;
  //   f.close();
  // }

  add_to_library_core(ir, p_query_str);

  // get_memory_usage();  // Debug purpose.

  return;
}

void Mutator::add_to_library_core(IR *ir, string *p_query_str) {
  /* Save an interesting query stmt into the mutator library. Helper function
   * for Mutator::add_to_library();
   */

  if (*p_query_str == "")
    return;

  int current_unique_id = ir->uniq_id_in_tree_;
  bool is_skip_saving_current_node = false; //

  NODETYPE p_type = ir->type_;
  NODETYPE left_type = kEmpty, right_type = kEmpty;

  unsigned long p_hash = hash(ir->to_string());
  if (p_type != kProgram && ir_libary_2D_hash_[p_type].find(p_hash) !=
                                ir_libary_2D_hash_[p_type].end()) {
    /* current node not interesting enough. Ignore it and clean up. */
    return;
  }
  if (p_type != kProgram)
    ir_libary_2D_hash_[p_type].insert(p_hash);

  // Update with_lib.
  if (!is_skip_saving_current_node)
    real_ir_set[p_type].push_back(
        std::make_pair(p_query_str, current_unique_id));

  // Update right_lib, left_lib
  if (ir->right_ && ir->left_ && !is_skip_saving_current_node) {
    left_type = ir->left_->type_;
    right_type = ir->right_->type_;
    left_lib_set[left_type].push_back(std::make_pair(
        p_query_str, current_unique_id)); // Saving the parent node id. When
                                          // fetching, use current_node->right.
    right_lib_set[right_type].push_back(std::make_pair(
        p_query_str, current_unique_id)); // Saving the parent node id. When
                                          // fetching, use current_node->left.
  }

  if (this->dump_library) {

    std::ofstream f;
    f.open("./append-core", std::ofstream::out | std::ofstream::app);
    f << *p_query_str << " node_id: " << current_unique_id << endl;
    f.close();
  }

  if (ir->left_) {
    add_to_library_core(ir->left_, p_query_str);
  }

  if (ir->right_) {
    add_to_library_core(ir->right_, p_query_str);
  }

  return;
}

void Mutator::get_memory_usage() {

  static unsigned long old_use = 0;

  std::ofstream f;
  // f.rdbuf()->pubsetbuf(0, 0);
  f.open("./memlog.txt", std::ofstream::out);

  struct rusage usage;
  getrusage(RUSAGE_SELF, &usage);

  unsigned long use = usage.ru_maxrss * 1024;

  // if (use - old_use < 1024 * 1024)
  //   return;

  f << "-------------------------------------\n";
  f << "memory use:  " << use << "\n";
  old_use = use;

  unsigned long total_size = 0;

  // unsigned long size_2D_hash = 0;
  // for (auto &i : ir_libary_2D_hash_)
  //   size_2D_hash += i.second.size() * 8;
  // f << "2D hash size:" << size_2D_hash
  //      << "\t - " << size_2D_hash * 1.0 / use << "\n";
  // total_size += size_2D_hash;

  // unsigned long size_2D = 0;
  // for(auto &i: ir_libary_2D_)
  //   size_2D += i.second.size() * 8;
  // f << "2D size:     " << size_2D
  //      << "\t - " << size_2D * 1.0 / use << "\n";
  // total_size += size_2D;

  // unsigned long size_left = 0;
  // for(auto &i: left_lib)
  //   size_left += i.second.size() * 8;;
  // f << "left size:   " << size_left
  //      << "\t - " << size_left * 1.0 / use << "\n";
  // total_size += size_left;

  // unsigned long size_right = 0;
  // for(auto &i: right_lib)
  //   size_right += i.second.size();
  // f << "right size:  " << size_right
  //      << "\t - " << size_right * 1.0 / use << "\n";
  // total_size += size_right;

  unsigned long size_value = 0;
  for (auto &v : value_libary)
    size_value += v.size();
  f << "value size:   " << size_value << "\t - " << size_value * 1.0 / use
    << "\n";
  total_size += size_value;

  unsigned long size_m_tables = 0;
  for (auto &i : m_tables)
    for (auto &j : i.second)
      size_m_tables += j.capacity();
  ;
  f << "m_tables size:" << size_m_tables << "\t - " << size_m_tables * 1.0 / use
    << "\n";
  total_size += size_m_tables;

  unsigned long size_v_table_names = 0;
  for (auto &i : v_table_names)
    size_v_table_names += i.capacity();
  ;
  f << "v_tbl size:   " << size_v_table_names << "\t - "
    << size_v_table_names * 1.0 / use << "\n";
  total_size += size_v_table_names;

  unsigned long size_string_libary = 0;
  for (auto &i : string_libary)
    size_string_libary += i.capacity();
  f << "str lib size :" << size_string_libary << "\t - "
    << size_string_libary * 1.0 / use << "\n";
  total_size += size_string_libary;

  unsigned long size_real_ir_set_str_libary = 0;
  for (auto i : all_query_pstr_set)
    size_real_ir_set_str_libary += i->capacity() + 8;
  f << "all_query_pstr_set size :" << size_real_ir_set_str_libary << "\t - "
    << size_real_ir_set_str_libary * 1.0 / use << "\n";
  total_size += size_real_ir_set_str_libary;

  f << "total size:  " << total_size << "\t - " << total_size * 1.0 / use
    << "\n";

  f.close();
}

unsigned long Mutator::hash(const string &sql) {
  return fuzzing_hash(sql.c_str(), sql.size());
}

unsigned long Mutator::hash(IR *root) { return this->hash(root->to_string()); }

void Mutator::debug(IR *root, unsigned level) {

  for (unsigned i = 0; i < level; i++)
    cout << " ";

  cout << get_string_by_ir_type(root->type_) << ": "
       << get_string_by_id_type(root->id_type_) << ": "<< root->to_string() << endl;

  if (root->left_)
    debug(root->left_, level + 1);
  if (root->right_)
    debug(root->right_, level + 1);
}

Mutator::~Mutator() {
  // cout << "HERE" << endl;

  for (auto iter : all_query_pstr_set) {
    delete iter;
  }
}

// void Mutator::fix_one(map<IR *, set<IR *>> &graph, IR *fixed_key,
//                       set<IR *> &visited) {
//   if (fixed_key->id_type_ == id_create_table_name) {
//     string tablename = fixed_key->str_val_;
//     auto &colums = m_tables[tablename];
//     auto &indices = m_table2index[tablename];
//     for (auto &val : graph[fixed_key]) {
//       if (val->id_type_ == id_create_column_name) {
//         string new_column = gen_id_name();
//         colums.push_back(new_column);
//         val->str_val_ = new_column;
//         visited.insert(val);
//       } else if (val->id_type_ == id_top_table_name) {
//         val->str_val_ = tablename;
//         visited.insert(val);
//         fix_one(graph, val, visited);
//       }
//     }
//   } else if (fixed_key->id_type_ == id_top_table_name) {
//     string tablename = fixed_key->str_val_;
//     auto &colums = m_tables[tablename];
//     auto &indices = m_table2index[tablename];
//     auto &alias= m_table2alias_single[tablename];

//     for (auto &val : graph[fixed_key]) {

//       switch (val->id_type_) {
//       case id_table_alias_name: {
//         string new_alias = gen_alias_name();
//         alias.push_back(new_alias);
//         val->str_val_ = new_alias;
//         visited.insert(val);
//         break;
//       }
//       default: break;
//       }

//     }

//     for (auto &val : graph[fixed_key]) {

//       switch (val->id_type_) {

//       case id_column_name: {
//         // We created alias for every table name. So when we get top column name
//         // from mappings, we need to prepend the corresponding alias to the
//         // column name. for example:
//         //  CREATE TABLE v0 ( v1 INT );
//         //  SELECT * FROM v0 AS A, v0 AS B WHERE A.v1 = 1337;
//         // we need to generate prepend 'A' or 'B' to 'v1' to avoid ambiguous
//         // name.

//         // Changed it to IR only modifications.
//         val->str_val_ = vector_rand_ele(colums);

//         IR* opt_alias_ir = fixed_key->parent_->parent_->right_;  // identifier -> ktablename -> parent_ -> kOptTableAliasAs
//         if (opt_alias_ir != nullptr &&
//             opt_alias_ir->op_ != nullptr &&
//             (opt_alias_ir->type_ == kOptTableAlias || opt_alias_ir->type_ == kOptTableAliasAs) &&
//             opt_alias_ir->op_->prefix_ == "AS")
//           {
//             if(opt_alias_ir->left_ != nullptr && opt_alias_ir->left_->left_ != nullptr) {  // kOptTableAliasAs -> kTableAlias ->  identifier.
//               val->str_val_ = opt_alias_ir->left_->left_->str_val_ + "." + val->str_val_;
//             }
//         }

//         visited.insert(val);
//         break;
//       }

//       case id_table_name: {
//         val->str_val_ = tablename;
//         visited.insert(val);
//         break;
//       }

//       case id_create_index_name: {
//         string new_index = gen_id_name();
//         // cout << "index name: " << new_index << endl;
//         indices.push_back(new_index);
//         val->str_val_ = new_index;
//         visited.insert(val);
//         break;
//       }

//       case id_create_column_name: {
//         string new_column = gen_id_name();
//         colums.push_back(new_column);
//         val->str_val_ = new_column;
//         visited.insert(val);
//         break;
//       }
//       }
//     }
//   }
// }

// relationmap[id_table_alias_name] = id_top_table_name;
// relationmap[id_column_name] = id_top_table_name;
// relationmap[id_table_name] = id_top_table_name;
// relationmap[id_index_name] = id_top_table_name;
// relationmap[id_create_column_name] = id_create_table_name;
// relationmap[id_pragma_value] = id_pragma_name;
// relationmap[id_create_index_name] = id_create_table_name;
// cross_map[id_top_table_name] = id_create_table_name;
// relationmap_alternate[id_create_column_name] = id_top_table_name;
// relationmap_alternate[id_create_index_name] = id_top_table_name;
//
bool Mutator::fix_dependency(IR *root,
                        vector<vector<IR *>> &ordered_all_subquery_ir, bool is_debug_info) {
  set<IR *> visited;
  reset_database_single_stmt();
  string cur_pragma_key = "";

  if (is_debug_info) {
    cerr << "Trying to fix_dependency on stmt: " << root->to_string() << ". \n\n\n";
  }

  /* Loop through the subqueries. From the most parent query to the most child query. (In the same query statement. )*/
  for (vector<IR*>& ordered_ir : ordered_all_subquery_ir) {

    /* First loop through all ir_to_fix, resolve all id_create_table_name and id_table_alias_name. */
    for (auto ir : ordered_ir) {
      if (visited.find(ir) != visited.end()) {continue;}

      /* This identifier_ is a naming placeholder that hold the newly defined table name.
      ** Can be used in CREATE TABLE statement.
      */
      if (ir->id_type_ == id_create_table_name) {
        ir->str_val_ = gen_id_name();
        v_create_table_names_single.push_back(ir->str_val_);
        visited.insert(ir);
        if (is_debug_info) {
          cerr << "Dependency: In id_create_table_name, we created v_table_name: " << ir->str_val_ << "\n\n\n";
        }
        /* Take care of the alias, if any. We will not save this alias into the lib, as using just id_create_table_name(with alias) will most likely resulted in errors. */
        IR* alias_ir = p_oracle->ir_wrapper.get_alias_iden_from_tablename_iden(ir);
        if (alias_ir != nullptr && alias_ir->id_type_ == id_table_alias_name) {
          string new_alias_str = gen_alias_name();
          alias_ir->str_val_ = new_alias_str;
          visited.insert(alias_ir);
          if (is_debug_info) {
            cerr << "Dependency: In id_create_table_name, we save alias_name: " << new_alias_str << ". \n\n\n";
          }
        }
      } else if (ir->id_type_ == id_create_table_name_with_tmp) {
        /* This is a newly created name used in the WITH clause.
        ** WITH clause defined tmp names, used by only the one statement.
        ** Thus, we only save this table_name in this single statement, don't save it into v_table_names or m_tables.
        */
        ir->str_val_ = gen_id_name();
        v_create_table_names_single_with_tmp.push_back(ir->str_val_);
        visited.insert(ir);
        if (is_debug_info) {
          cerr << "Dependency: In id_create_table_name_with_tmp, we created table_name_tmp: " << ir->str_val_ << "\n\n\n";
        }
      }

      else if (ir->id_type_ == id_trigger_name) {
        ir->str_val_ = gen_column_name();
        visited.insert(ir);
        if (is_debug_info) {
          cerr << "Dependency: Generated trigger name: " << ir->str_val_ << "\n\n\n";
        }
      }
    }

    /* Second loop, resolve all id_top_table_name, id_table_alias_name. */
    for (auto ir : ordered_ir) {
      if (visited.find(ir) != visited.end()) {continue;}

      IRTYPE cur_stmt_type = p_oracle->ir_wrapper.get_cur_stmt_type(ir);

      if (ir->id_type_ == id_top_table_name) {
        /* This is the place to reference prevous defined table names. Used in FROM clause etc. */
        if (v_table_names.size() != 0 || v_create_table_names_single.size() != 0 || v_create_table_names_single_with_tmp.size() != 0) {

          /* In 3/10 chances, we use the table name defined in the WITH clause. */
          if (is_debug_info) {
            cerr << "Dependency: v_create_table_names_single_with_tmp.size() is: " << v_create_table_names_single_with_tmp.size() << "\n\n\n";
          }
          if (v_create_table_names_single_with_tmp.size() != 0 && cur_stmt_type != kUpdateStatement && get_rand_int(100) < 100) {
            // IR* with_clause_ir = p_oracle->ir_wrapper.find_closest_node_exclude_child(ir, kWithClause);
            // if (is_debug_info) {
            //   if (with_clause_ir != NULL) {
            //     cerr << "Dependency: Found kWithClause: " << with_clause_ir->to_string() << "\n\n\n";
            //   }
            // }
            // vector<IR*> all_with_table_name_declared = p_oracle->ir_wrapper.get_table_ir_in_with_clause(with_clause_ir);
            // if (is_debug_info) {
            //   cerr << "Dependency: found all_with_table_name_declared: \n";
            //   for (IR* cur_iter: all_with_table_name_declared) {
            //     cerr << "Dependency: found: " << cur_iter->to_string() << "\n";
            //   }
            // }
            // if (all_with_table_name_declared.size() != 0) {
            //   ir->str_val_ = all_with_table_name_declared[get_rand_int(all_with_table_name_declared.size())]->left_->str_val_;
            // } else {
              if (is_debug_info) {
                cerr << "Dependency Error: Cannot find the create_table_names_single_with_tmp inside the kWithClause. \n\n\n";
              }
              ir->str_val_ = v_create_table_names_single_with_tmp[get_rand_int(v_create_table_names_single_with_tmp.size())];
            // }
            // v_table_names_single.push_back(ir->str_val_);
            visited.insert(ir);
            if (is_debug_info) {
              cerr << "Dependency: In id_top_table_name, we used v_create_table_names_single: " << ir->str_val_ << ". \n\n\n";
            }

          /* If not using table_name defined in the WITH clause, then we randomly pick one table that is previsouly defined. */
          } else if (v_table_names.size()) {
            ir->str_val_ = v_table_names[get_rand_int(v_table_names.size())];
            v_table_names_single.push_back(ir->str_val_);
            visited.insert(ir);

          /*
          ** If we cannot find any previously defined table_names,
          ** well, this is unexpected. see if we have table_names that is just defined in this stmt.
          */
          } else {
            ir->str_val_ = v_create_table_names_single[get_rand_int(v_create_table_names_single.size())];
            v_table_names_single.push_back(ir->str_val_);  /* Should we expose it to v_table_name_single? */
            visited.insert(ir);
          }

          if (is_debug_info) {
            cerr << "Dependency: In id_top_table_name, we used table_name: " << ir->str_val_ << ". \n\n\n";
          }

          /* Take care of the alias, if any.  */
          IR* alias_ir = p_oracle->ir_wrapper.get_alias_iden_from_tablename_iden(ir);
          if (alias_ir != nullptr && alias_ir->id_type_ == id_table_alias_name) {
            string new_alias_str = gen_alias_name();
            alias_ir->str_val_ = new_alias_str;
            v_alias_names_single.push_back(new_alias_str);
            m_table2alias_single[ir->str_val_].push_back(new_alias_str);
            visited.insert(alias_ir);

            if (is_debug_info) {
              cerr << "Dependency: In id_top_table_name, for table_name: " << ir->str_val_ << ", we generate alias name: " << new_alias_str << ". \n\n\n";
            }
          }
        } else {  // if (v_table_names.size() != 0 || v_create_table_names_single.size() != 0 || v_create_table_names_single_with_tmp.size() != 0)
          if (is_debug_info) {
            cerr << "Dependency Error: In id_top_table_name, couldn't find any v_table_names saved. \n\n\n";
          }
          ir->str_val_ = gen_table_name();
          continue;
        }
      }
    }

    /* Third loop, resolve id_table_name */
    for (auto ir : ordered_ir) {
      if (visited.find(ir) != visited.end()) {continue;}

      IRTYPE cur_stmt_type = p_oracle->ir_wrapper.get_cur_stmt_type(ir);

      if (ir->id_type_ == id_table_name) {
        /* id_table_name is used in the actual operations, for example, the table_names in the WHERE clause.
        ** Normally, if we encounter id_table_name, there have been id_top_table_name defined in the FROM clause etc.
        */
        if (is_debug_info) {
          cerr << "Dependency: v_create_table_names_single_with_tmp.size() is: " << v_create_table_names_single_with_tmp.size() << "\n\n\n";
        }
        if (v_create_table_names_single_with_tmp.size() != 0 && cur_stmt_type != kUpdateStatement && get_rand_int(100) < 100) {
          /* In 3/10 chances, we use the table name defined in the WITH clause. */
          // IR* with_clause_ir = p_oracle->ir_wrapper.find_closest_node_exclude_child(ir, kWithClause);
          // if (is_debug_info) {
          //   if (with_clause_ir != NULL) {
          //     cerr << "Dependency: Found kWithClause: " << with_clause_ir->to_string() << "\n\n\n";
          //   }
          // }
          // vector<IR*> all_with_table_name_declared = p_oracle->ir_wrapper.get_table_ir_in_with_clause(with_clause_ir);
          // if (is_debug_info) {
          //     cerr << "Dependency: found all_with_table_name_declared: \n";
          //     for (IR* cur_iter: all_with_table_name_declared) {
          //       cerr << "Dependency: found: " << cur_iter->to_string() << "\n";
          //     }
          //   }
          // if (all_with_table_name_declared.size() != 0) {
          //   ir->str_val_ = all_with_table_name_declared[get_rand_int(all_with_table_name_declared.size())]->left_->str_val_;
          // } else {
            // if (is_debug_info) {
            //   cerr << "Dependency Error: Cannot find the create_table_names_single_with_tmp inside the kWithClause. \n\n\n";
            // }
            ir->str_val_ = v_create_table_names_single_with_tmp[get_rand_int(v_create_table_names_single_with_tmp.size())];
          // }
          // v_table_names_single.push_back(ir->str_val_);
          visited.insert(ir);
          if (is_debug_info) {
            cerr << "Dependency: In id_table_name, we used v_create_table_names_single_with_tmp: " << ir->str_val_ << ". \n\n\n";
          }
        } else if (v_table_names_single.size() != 0 ) {
          /* Check whether there are previous defined id_top_table_name. */
          string tablename_str = v_table_names_single[get_rand_int(v_table_names_single.size())];
          ir->str_val_ = tablename_str;
          visited.insert(ir);
          if (is_debug_info) {
            cerr << "Dependency: In id_table_name, we used v_table_names_single: " << ir->str_val_ << ". \n\n\n";
          }
        } else if (v_table_names.size() != 0) {
          /* Well, this is unexpected. No id_top_table_name defined.
          ** Then, we have to fetched table_name defined in the previous statment.
          */
          string tablename_str = v_table_names[get_rand_int(v_table_names.size())];
          ir->str_val_ = tablename_str;
          v_table_names_single.push_back(tablename_str);
          visited.insert(ir);
          if (is_debug_info) {
            cerr << "Dependency: In id_table_name, while v_table_name_single is empty, we used table_name: " << ir->str_val_ << ". \n\n\n";
          }
        } else if (v_create_table_names_single.size() != 0) {
          /* This is unexpected.
          ** If cannot find any table name defined before. Then see if we can find newly created table_name in this specific stmt.
          */
          string tablename_str = v_create_table_names_single[get_rand_int(v_create_table_names_single.size())];
          ir->str_val_ = tablename_str;
          v_table_names_single.push_back(tablename_str);
          visited.insert(ir);
          if (is_debug_info) {
            cerr << "Dependency: In id_table_name, while v_table_name_single is empty, we used table_name: " << ir->str_val_ << ". \n\n\n";
          }
        }
        else {
          /* :-( Well, we found nothing for id_table_name. Give up. Generate a new one, and fill in. Most likely a semantic error in the SQL. */
          if (is_debug_info) {
            cerr << "Dependency Error: In id_table_name, couldn't find any v_table_names, v_table_name_single and v_create_table_name_single saved. \n\n\n";
          }
          ir->str_val_ = gen_table_name();
          continue;
        }
      }
    }

    /* Fourth loop, resolve id_create_index_name, id_create_column_name */
    for (auto ir : ordered_ir) {
      if (visited.find(ir) != visited.end()) {continue;}

      /* There is only one case of id_create_index_name, that is in the CREATE INDEX statement. */
      if (ir->id_type_ == id_create_index_name) {
        if (v_create_table_names_single.size() == 0 && v_table_names_single.size() == 0) {
          if (is_debug_info) {
            cerr << "Dependency Error: id_create_index_name, couldn't find any v_table_name saved. \n\n\n";
          }
          ir->str_val_ = gen_index_name();
          continue;
        }
        /* Find the table_name that we want to create index for. */
        string tablename_str = "";
        if (v_create_table_names_single.size() > 0) {
          tablename_str = v_create_table_names_single[get_rand_int(v_create_table_names_single.size())];
        } else {
          tablename_str = v_table_names_single[get_rand_int(v_table_names_single.size())];
        }
        string new_indexname_str = gen_index_name();
        ir->str_val_ = new_indexname_str;
        m_table2index[tablename_str].push_back(new_indexname_str);
        visited.insert(ir);

        if (is_debug_info) {
          cerr << "Dependency: In id_create_index_name, saved index name: " << new_indexname_str << " for table: " << tablename_str << ". \n\n\n";
        }
      }

      if (ir->id_type_ == id_create_column_name || ir->id_type_ == id_create_column_name_with_tmp || ir->id_type_ == id_top_column_name ) {
        if (v_create_table_names_single.size() == 0 && v_table_names_single.size() == 0 && v_create_table_names_single_with_tmp.size() == 0) {
          if (is_debug_info) {
            cerr << "Dependency Error: id_create_column_name, couldn't find any v_table_name saved. \n\n\n";
          }
          ir->str_val_ = gen_column_name();
          continue;
        }

        /* Find the table_name that we want to create columns for. */
        string tablename_str = "";
        bool is_with_clause = false;
        /* Column named defined in the WITH clause. These column name is tmp. Will remove immediately after this stmt ends.
        ** Thus, we create them, but do not save into m_tables.
        */
        if (ir->id_type_ == id_create_column_name_with_tmp) {
          if (v_create_table_names_single_with_tmp.size() == 0) {
            if (is_debug_info) {
              cerr << "Dependency Error: id_create_column_name_with_tmp, cannot find any id_create_table_name_with_tmp saved. \n\n\n";
              ir->str_val_ = gen_column_name();
              continue;
            }
          }
          is_with_clause = true;
        }
        /* Normal create column stmt. Find table name using v_create_table_names_single.
        ** Most of the time, one CREATE TABLE statement or ALTER stmt only have one table name defined.
        ** Thus using v_create_table_names_single should be fine.
        */
        else if (v_create_table_names_single.size() > 0) {
          tablename_str = v_create_table_names_single[get_rand_int(v_create_table_names_single.size())];
        }
        /* If we cannot find any newly created table_names, then check the table_names used in this stmt.
        ** Could happens in ALTER stmt.
        */
        else {
          tablename_str = v_table_names_single[get_rand_int(v_table_names_single.size())];
        }

        /* This is a special case for using column. We can directly fill in random defined column_name. Mostly for debug purpose. */
        if (ir->id_type_ == id_top_column_name && v_table_names.size() != 0) {
          string random_tablename_str = vector_rand_ele(v_table_names);
          vector<string> random_column_vec = m_tables[random_tablename_str];
          if (random_column_vec.size() != 0) {
            ir->str_val_ = vector_rand_ele(random_column_vec);
            if (tablename_str != "." && !is_str_empty(ir->str_val_) ) {
              m_tables[tablename_str].push_back(ir->str_val_);
            }
          } else {
            /* Cannot find any saved column name. Changed to create_column_name.  */
            ir->id_type_ = id_create_column_name;
          }
        }

        /* For actual id_create_column_name, used in most create table or alter statements. */
        string new_columnname_str = gen_column_name();
        ir->str_val_ = new_columnname_str;

        /* Save the WITH clause created column name into a tmp vector. This column name can be used directly without referencing its table names in the current query. */
        if (is_with_clause) {
          v_create_column_names_single_with_tmp.push_back(new_columnname_str);
        }
        else {
        /* In normal column name creation. Just append it to the m_tables for future statements usage. */
          m_tables[tablename_str].push_back(new_columnname_str);
        }

        if (is_debug_info) {
          cerr << "Dependency: In id_create_column_name, created column name: " << new_columnname_str << " for table: " << tablename_str << ". \n\n\n";
        }

        visited.insert(ir);
      }
    }

    /* Fifth loop, resolve id_column_name, id_index_name, id_pragma_value. */
    for (auto ir : ordered_ir) {
      if (visited.find(ir) != visited.end()) {continue;}

      IRTYPE cur_stmt_type = p_oracle->ir_wrapper.get_cur_stmt_type(ir);

      if (ir->id_type_ == id_column_name) {
        if (v_table_names_single.size() == 0 && v_create_table_names_single.size() == 0 && v_create_column_names_single_with_tmp.size() == 0) {
          if (is_debug_info) {
            cerr << "Dependency Error: for id_column_name, couldn't find any v_table_name_single saved. \n\n\n";
          }
          string random_tablename_str = vector_rand_ele(v_table_names);
          vector<string> random_column_vec = m_tables[random_tablename_str];
          if (random_column_vec.size() != 0) {
            ir->str_val_ = vector_rand_ele(random_column_vec);
          } else {
            ir->str_val_ = gen_column_name();
          }
          continue;
        }

        /* Special handling for the UPDATE stmt.
        ** We cannot use alias.column name in the UPDATE stmt.
        ** Thus, we have to manually fetch which table_name we are referring to,
        ** and updates the column name based on the table_name mentioned.
        */
        if (cur_stmt_type == kUpdateStatement) {
          IR* update_stmt_node = p_oracle->ir_wrapper.get_stmt_ir_from_child_ir(ir);
          IR* qualified_table_name_ = update_stmt_node->left_->left_->left_->left_->right_;

          IR* table_name_ir = qualified_table_name_->left_->left_;
          string cur_choosen_table_name = table_name_ir->left_->str_val_;
          vector<string>& column_name_vec = m_tables[cur_choosen_table_name];
          if (column_name_vec.size() != 0) {
            ir->str_val_ = column_name_vec[get_rand_int(column_name_vec.size())];
            if (is_debug_info) {
              cerr << "Dependency: Special handling for UPDATE stmt. Received table_name: " << cur_choosen_table_name
                   << " Return: " << ir->str_val_ << " for id_column_name. \n\n\n";
            }
          } else {
            if (is_debug_info) {
              cerr << "Dependency Error: Special handling for UPDATE stmt. Cannot find m_table column for: " << cur_choosen_table_name << " \n\n\n";
            }
          }
        }

        /* 1/5 chances, pick column_names from WITH clause directly. */
        if (is_debug_info) {
          cerr << "Dependency: Getting cur_stmt_type: " << get_string_by_ir_type(cur_stmt_type) << " \n\n\n";
        }

        /* Do not use column name defined in WITH clause, in the UPDATE or ALTER stmt. */
        if (
              (
                v_create_column_names_single_with_tmp.size() != 0 &&
                cur_stmt_type != kAlterStatement &&
                cur_stmt_type != kUpdateStatement &&
                get_rand_int(100) < 30
              ) ||
              (
                v_table_names_single.size() == 0 && v_create_table_names_single.size() == 0
              )
          ) {
          ir->str_val_ = v_create_column_names_single_with_tmp[get_rand_int(v_create_column_names_single_with_tmp.size())];
          continue;
        }

        string tablename_str;
        if (v_table_names_single.size() != 0) {
          tablename_str = v_table_names_single[get_rand_int(v_table_names_single.size())];
        } else {
          tablename_str = v_create_table_names_single[get_rand_int(v_create_table_names_single.size())];
        }

        if (
          p_oracle->ir_wrapper.get_cur_stmt_type(ir) == kCreateVirtualTableStatement ||
          p_oracle->ir_wrapper.get_cur_stmt_type(ir) == kCreateTriggerStatement
        ) {
          tablename_str = v_table_names[get_rand_int(v_table_names.size())];
        }

        vector<string> &matched_columnname_vec = m_tables[tablename_str];
        vector<string> &matched_aliasname_vec = m_table2alias_single[tablename_str];
        if (matched_aliasname_vec.size() != 0 && matched_columnname_vec.size() != 0) {
          string aliasname_str = matched_aliasname_vec[get_rand_int(matched_aliasname_vec.size())];
          string column_str = matched_columnname_vec[get_rand_int(matched_columnname_vec.size())];
          if (is_debug_info) {
            cerr << "Dependency: Getting cur_stmt_type: " << get_string_by_ir_type(cur_stmt_type) << " \n\n\n";
          }
          /* Added alias_name before the column_name. Only for SelectStmt. */
          if (cur_stmt_type == kSelectStatement) {
            // if (get_rand_int(100) < 1) {
            //   ir->str_val_ = aliasname_str + ".ROWID";
            // } else {
              ir->str_val_ = aliasname_str + "." + column_str;
            // }
          }
          else {
            {ir->str_val_ = column_str;}
          }

          if (is_debug_info) {
            cerr << "Dependency: For id_column_name, we used: " << ir->str_val_ << ". \n\n\n";
          }

          visited.insert(ir);
        } else if (matched_columnname_vec.size() != 0) {
          string column_str = matched_columnname_vec[get_rand_int(matched_columnname_vec.size())];
          if (is_debug_info) {
            cerr << "Dependency: Getting cur_stmt_type: " << get_string_by_ir_type(cur_stmt_type) << " \n\n\n";
          }
          /* If cannot find alias name for the table, directly add table_name before the column_name. Only for SelectStmt. */
          if (cur_stmt_type == kSelectStatement) {
            // if (get_rand_int(100) < 1) {
            //   ir->str_val_ = tablename_str + ".ROWID";
            // } else {
              ir->str_val_ = tablename_str + "." + column_str;
            // }
          }
          else {
            {ir->str_val_ = column_str;}
          }
          if (is_debug_info) {
            cerr << "Dependency: For id_column_name, we used: " << ir->str_val_ << ". \n\n\n";
          }

          visited.insert(ir);
        } else { // Cannot find matched column for table.
          if (is_debug_info) {
            cerr << "Dependency Error: for id_column_name, couldn't find any matched_columnname_vec saved. \n\n\n";
          }
          string random_tablename_str = vector_rand_ele(v_table_names);
          vector<string> random_column_vec = m_tables[random_tablename_str];
          if (random_column_vec.size() != 0) {
            ir->str_val_ = vector_rand_ele(random_column_vec);
          } else {
            ir->str_val_ = gen_column_name();
          }
          continue;
        }
      }

      if (ir->id_type_ == id_index_name) {
        if (v_table_names_single.size() == 0 ) {
          if (is_debug_info) {
            cerr << "Dependency Error: for id_index_name, couldn't find any v_table_name_single saved. \n\n\n";
          }
          string random_tablename_str = vector_rand_ele(v_table_names);
          vector<string> random_index_vec = m_table2index[random_tablename_str];
          if (random_index_vec.size() != 0) {
            ir->str_val_ = vector_rand_ele(random_index_vec);
          } else {
            ir->str_val_ = gen_column_name();
          }
          continue;
        }

        string tablename_str = v_table_names_single[get_rand_int(v_table_names_single.size())];
        if (m_table2index.find(tablename_str) == m_table2index.end()) {
          if (is_debug_info) {
            cerr << "Dependency Error: In id_index_name, cannot find index for table name: " << tablename_str << ". \n\n\n";
          }
          string random_tablename_str = vector_rand_ele(v_table_names);
          vector<string> random_index_vec = m_table2index[random_tablename_str];
          if (random_index_vec.size() != 0) {
            ir->str_val_ = vector_rand_ele(random_index_vec);
          } else {
            ir->str_val_ = gen_column_name();
          }
          continue;
        }

        vector<string> &matched_indexname_vec = m_table2index[tablename_str];
        vector<string> &matched_aliasname_vec = m_table2alias_single[tablename_str];
        if (matched_aliasname_vec.size() != 0 && matched_indexname_vec.size() != 0) {
          string aliasname_str = matched_aliasname_vec[get_rand_int(matched_aliasname_vec.size())];
          string index_str = matched_indexname_vec[get_rand_int(matched_indexname_vec.size())];
          if (is_debug_info) {
            cerr << "Dependency: Getting cur_stmt_type: " << get_string_by_ir_type(cur_stmt_type) << " \n\n\n";
          }
          if (cur_stmt_type != kUpdateStatement && cur_stmt_type != kAlterStatement)
            {ir->str_val_ = aliasname_str + "." + index_str;}
          else {
            {ir->str_val_ = index_str;}
          }
          if (is_debug_info) {
            cerr << "Dependency: For id_index_name, we used: " << ir->str_val_ << ". \n";
          }
          visited.insert(ir);
        } else if (matched_indexname_vec.size() != 0) {
          string index_str = matched_indexname_vec[get_rand_int(matched_indexname_vec.size())];
          if (is_debug_info) {
            cerr << "Dependency: Getting cur_stmt_type: " << get_string_by_ir_type(cur_stmt_type) << " \n\n\n";
          }
          if (cur_stmt_type != kUpdateStatement && cur_stmt_type != kAlterStatement)
            {ir->str_val_ = tablename_str + "." + index_str;}
          else {
            {ir->str_val_ = index_str;}
          }
          if (is_debug_info) {
            cerr << "Dependency: For id_index_name, we used: " << ir->str_val_ << ". \n";
          }
          visited.insert(ir);
        } else { // Cannot find matched index for table.
          if (is_debug_info) {
            cerr << "Dependency Error: for id_index_name, couldn't find any matched_indexname_vec saved. \n\n\n";
          }
          string random_tablename_str = vector_rand_ele(v_table_names);
          vector<string> random_index_vec = m_table2index[random_tablename_str];
          if (random_index_vec.size() != 0) {
            ir->str_val_ = vector_rand_ele(random_index_vec);
          } else {
            ir->str_val_ = gen_column_name();
          }
          continue;
        }

      }

      /* Fixing for the id_pragma_name. */
      if (ir->id_type_ == id_pragma_name) {
        int lib_size = cmds_.size();
        if (lib_size != 0) {
          ir->str_val_ = cmds_[get_rand_int(lib_size)];
          cur_pragma_key = ir->str_val_;
        }
      }

      if (ir->id_type_ == id_pragma_value) {
        if (m_cmd_value_lib_[cur_pragma_key].size() != 0) {
          string value = vector_rand_ele(m_cmd_value_lib_[cur_pragma_key]);
          if (!value.compare("_int_")) {
            if (value_libary.size() != 0) {
              ir->str_val_ = value_libary[get_rand_int(value_libary.size())];
            } else {
              ir->str_val_ = to_string(get_rand_int(100));
            }
          } else if (!value.compare("_empty_")) {
            ir->str_val_ = "";
          } else if (!value.compare("_boolean_")) {
            if (get_rand_int(2) == 0)
              {ir->str_val_ = "false";}
            else
              {ir->str_val_ = "true";}
          } else {
            ir->str_val_ = value;
          }
        } else {
          ir->str_val_ = to_string(get_rand_int(10));
        }
      }
    }
  } // for (vector<IR*>& ordered_ir : ordered_all_subquery_ir)

  v_table_names.insert(v_table_names.end(), v_create_table_names_single.begin(), v_create_table_names_single.end());

   /* Loop through the subqueries again. This loop is for logging dependency information. */
  for (vector<IR*>& ordered_ir : ordered_all_subquery_ir) {

    /* First loop: Resolve column mappings for kCreateViewStatement. */
    for (auto ir : ordered_ir) {
      if (ir ->id_type_ != id_create_table_name) {
        continue;
      }
      /* Check whether we are in the CreateViewStatement. If yes, save the column mapping. */
      IR* cur_ir = ir;
      bool is_in_create_view = false;
      while (cur_ir != nullptr) {
        if (cur_ir->type_ == kStatement) {
          break;
        }
        if (cur_ir->type_ == kCreateViewStatement) {
          is_in_create_view = true;
          break;
        }
        cur_ir = cur_ir->parent_;
      }
      if (!is_in_create_view) {
        continue;
      }

      // Added column mapping for CREATE TABLE/VIEW... v0 AS SELECT... statement.
      if (ordered_all_subquery_ir.size() > 1) {
        // id_column_name should be in the subqueries and already been resolved in the previous loop.
        vector<IR*> all_mentioned_column_vec = search_mapped_ir_in_stmt(ir, id_column_name);
        for (IR* cur_men_column_ir : all_mentioned_column_vec) {
          string cur_men_column_str = cur_men_column_ir->str_val_;
          if (findStringIn(cur_men_column_str, ".")) {
            cur_men_column_str = string_splitter(cur_men_column_str, '.')[1];
          }
          m_tables[ir->str_val_].push_back(cur_men_column_str);
          if (is_debug_info) {
            cerr << "Dependency: For table/view: " << ir->str_val_ << ", map with column: " << cur_men_column_str << ". \n\n\n";
          }
        }
        if (all_mentioned_column_vec.size() == 0) { // For CREATE VIEW x AS SELECT * FROM v0;
          vector<IR*> all_mentioned_tablename = search_mapped_ir_in_stmt(ir, id_top_table_name);
          for (IR* cur_men_tablename_ir : all_mentioned_tablename) {
            string cur_men_tablename_str = cur_men_tablename_ir->str_val_;
            const vector<string>& cur_men_column_vec = m_tables[cur_men_tablename_str];
            for (const string& cur_men_column_str : cur_men_column_vec) {
              vector<string>& cur_m_table  = m_tables[ir->str_val_];
              if (std::find(cur_m_table.begin(), cur_m_table.end(), cur_men_column_str) == cur_m_table.end()) {
                m_tables[ir->str_val_].push_back(cur_men_column_str);
                if (is_debug_info) {
                  cerr << "Dependency: For table/view: " << ir->str_val_ << ", map with column: " << cur_men_column_str << ". \n\n\n";
                }
              }
            }
          }
          all_mentioned_tablename = search_mapped_ir_in_stmt(ir, id_table_name);
          for (IR* cur_men_tablename_ir : all_mentioned_tablename) {
            string cur_men_tablename_str = cur_men_tablename_ir->str_val_;
            const vector<string>& cur_men_column_vec = m_tables[cur_men_tablename_str];
            for (const string& cur_men_column_str : cur_men_column_vec) {
              vector<string>& cur_m_table  = m_tables[ir->str_val_];
              if (std::find(cur_m_table.begin(), cur_m_table.end(), cur_men_column_str) == cur_m_table.end()) {
                m_tables[ir->str_val_].push_back(cur_men_column_str);
                if (is_debug_info) {
                  cerr << "Dependency: For table/view: " << ir->str_val_ << ", map with column: " << cur_men_column_str << ". \n\n\n";
                }
              }
            }
          }
        }
      }
    } // for (auto ir : ordered_ir)
  } // for (vector<IR*>& ordered_ir : ordered_all_subquery_ir)

  if (is_debug_info) {
    cerr << "After fixing: " << root->to_string() << " \n\n\n";
  }

  return true;
}

/* tranverse ir in the order: _right ==> root ==> left_ */

string Mutator::fix(IR *root) {

  string res = "";
  _fix(root, res);
  trim_string(res);

  /*
  ** For debugging purpose, avoid root->to_string() generates a different string from _fix()
  ** The string is identical for the latest commit. However, we cannot guarantee this for kPragmaStatement.
  ** We don't handle and save changes for kPragmaStatement in _fix() and to_string().
  */
  string ir_to_str = root->to_string();
  trim_string(ir_to_str);
  if (res != ir_to_str && !findStringIn(res, "PRAGMA") && !findStringIn(ir_to_str, "PRAGMA")) {
    ofstream error_output;
    error_output.open("./fatal_log.txt");
    error_output << "Error: ir_to_string is not the same as the string generated from _fix. \n";
    error_output << "res: \n" << res << endl;
    error_output << "ir_to_string: \n" << ir_to_str << endl;
    error_output.close();
    FATAL("Error: ir_to_string is not the same as the string generated from _fix. \n\
          _fix() str: %s, to_string() str: %s .\n", res.c_str(), ir_to_str.c_str());
  }

  return res;
}

void Mutator::_fix(IR *root, string &res) {

  auto *right_ = root->right_, *left_ = root->left_;
  auto *op_ = root->op_;
  auto type_ = root->type_;
  auto str_val_ = root->str_val_;
  auto f_val_ = root->f_val_;
  auto int_val_ = root->int_val_;
  auto id_type_ = root->id_type_;

  if (type_ == kIdentifier && id_type_ == id_database_name) {

    res += "main";
    root->str_val_ = "main";
    return;
  }

  if (type_ == kIdentifier && id_type_ == id_schema_name) {

    res += "sqlite_master";
    root->str_val_ = "sqlite_master";
    return;
  }

  // TODO:: not being handled for now.
  if (type_ == kPragmaStatement) {

    string key = "";
    int lib_size = cmds_.size();
    if (lib_size != 0) {
      key = cmds_[get_rand_int(lib_size)];
      res += ("PRAGMA " + key);
    } else
      return;

    int value_size = m_cmd_value_lib_[key].size();
    string value = m_cmd_value_lib_[key][get_rand_int(value_size)];
    if (!value.compare("_int_")) {
      value = string("=") + value_libary[get_rand_int(value_libary.size())];
    } else if (!value.compare("_empty_")) {
      value = "";
    } else if (!value.compare("_boolean_")) {
      if (get_rand_int(2) == 0)
        value = "=false";
      else
        value = "=true";
    } else {
      value = "=" + value;
    }
    if (!value.empty())
      res += value + ";";
    return;
  }

  if (type_ == kFilePath || type_ == kOptOrderType || type_ == kColumnType ||
      type_ == kSetOperator || type_ == kOptJoinType || type_ == kOptDistinct ||
      type_ == kNullLiteral) {
    res += str_val_;
    return;
  }

  if (type_ == kStringLiteral) {
    string s;
    /* 2/3 chances, uses already seen string. */
    if (used_string_library.size() != 0 && get_rand_int(3) < 2 ) {
        s = used_string_library[get_rand_int(used_string_library.size())];
    } else {
        s = string_libary[get_rand_int(string_libary.size())];
    }
    res += "'" + s + "'";
    root->str_val_ = "'" + s + "'";
    return;
  }

  if (type_ == kNumericLiteral) {
    string s;
    /* 2/3 chances, uses already seen value. */
    if (used_value_libary.size() != 0 && get_rand_int(3) < 2) {
        s = used_value_libary[get_rand_int(used_value_libary.size())];
    } else {
        s = value_libary[get_rand_int(value_libary.size())];
    }
    used_value_libary.push_back(s);
    res += s;
    root->str_val_ = s;
    return;
  }

  if (type_ == kconst_str) {
    auto s = string_libary[get_rand_int(string_libary.size())];
    res += s;
    root->str_val_ = s;
    return;
  }

  if (!str_val_.empty()) {
    res += str_val_;
    return;
  }

  if (op_ && op_->prefix_) {
    res += op_->prefix_;
    res += " ";
  }

  if (left_) {
    _fix(left_, res);
    res += " ";
  }

  if (op_ && op_->middle_) {
    res += op_->middle_;
    res += " ";
  }

  if (right_) {
    _fix(right_, res);
    res += " ";
  }

  if (op_ && op_->suffix_)
    res += op_->suffix_;

  return;
}

void Mutator::resolve_drop_statement(IR* cur_trans_stmt, bool is_debug_info){
  IRTYPE stmt_type = this->p_oracle->ir_wrapper.get_cur_stmt_type(cur_trans_stmt);
  if (stmt_type == kDropTableStatement || stmt_type == kDropViewStatement) {
    vector<IR*> drop_tablename_vec = search_mapped_ir_in_stmt(cur_trans_stmt, id_table_name);
    for (IR* drop_table_ir : drop_tablename_vec) {
      string drop_table_str = drop_table_ir->str_val_;
      m_tables.erase(drop_table_str);
      m_table2index.erase(drop_table_str);
      v_table_names.erase(std::remove(v_table_names.begin(), v_table_names.end(), drop_table_str), v_table_names.end());
      if (is_debug_info) {
        cerr << "Dependency: In resolve_drop_statement, removing table_name: " << drop_table_str << " from v_table_names. \n\n\n";
      }
    }
  }
  else if (stmt_type == kDropIndexStatement) {
    vector<IR*> drop_indexname_vec = search_mapped_ir_in_stmt(cur_trans_stmt, id_index_name);
    for (IR* drop_indexname_ir : drop_indexname_vec) {
      string drop_indexname_str = drop_indexname_ir->str_val_;
      for (auto iter = m_table2index.begin(); iter != m_table2index.end(); iter++) {
        vector<string>& table2index_vec = iter->second;
        table2index_vec.erase(std::remove(table2index_vec.begin(), table2index_vec.end(), drop_indexname_str), table2index_vec.end());
        if (is_debug_info) {
        cerr << "Dependency: In resolve_drop_statement, removing index: " << drop_indexname_str << " from table2index_vec. \n\n\n";
        }
      }
    }
  }
}

void Mutator::resolve_alter_statement(IR* cur_trans_stmt, bool is_debug_info) {
  if (cur_trans_stmt->type_ != kAlterStatement) {return;}

  IR* cur_ir = cur_trans_stmt;
  while (!(cur_ir->op_ != nullptr && cur_ir->op_->middle_ != NULL)) {
    cur_ir = cur_ir->left_;
  }
  IROperator* op_ = cur_ir->op_;

  // RENAME tables.
  if (strcmp(op_->middle_, "RENAME TO") == 0){
    IR* tablename_from_ir;
    if (cur_ir->left_->right_ != nullptr) {tablename_from_ir = cur_ir->left_->right_;}
    else {tablename_from_ir = cur_ir->left_->left_;}
    string tablename_from_str = tablename_from_ir->str_val_;

    IR* tablename_to_ir;
    if (cur_ir->right_->right_ != nullptr) {tablename_to_ir = cur_ir->right_->right_;}
    else {tablename_from_ir = cur_ir->right_->left_;}
    string tablename_to_str = tablename_from_ir->str_val_;

    for (string& saved_tablename : v_table_names) {
      if (saved_tablename == tablename_from_str) {saved_tablename = tablename_to_str;}
    }
    for (auto iter = m_tables.begin(); iter != m_tables.end(); iter++) {
      if (iter->first == tablename_from_str) {
        m_tables[tablename_to_str] = iter->second;
        m_tables.erase(tablename_from_str);
        break;
      }
    }
    for (auto iter = m_table2index.begin(); iter != m_table2index.end(); iter++) {
      if (iter->first == tablename_from_str) {
        m_table2index[tablename_to_str] = iter->second;
        m_table2index.erase(tablename_from_str);
        break;
      }
    }
    if (is_debug_info) {
      cerr << "Dependency: In resolve_alter_statement, altering table_name: " << tablename_from_str <<  " to " << tablename_to_str << "\n\n\n";
    }
    return;
  }

  // RNAME columns
  if (strcmp(op_->middle_, "TO") == 0) {
    IR* tablename_ir = cur_ir->left_->left_->left_;
    if (cur_ir->right_ != nullptr) {tablename_ir = cur_ir->right_;}
    else {tablename_ir = cur_ir->left_;}
    string tablename_str = tablename_ir->str_val_;

    IR* columnname_to_ir = cur_ir->right_;
    if (columnname_to_ir->right_ != nullptr || columnname_to_ir->str_val_ == "*" || columnname_to_ir->left_ == nullptr) {return;}  // Semantic error
    string columnname_to_str = columnname_to_ir->left_->str_val_;

    IR* columnname_from_ir = cur_ir->left_->right_;
    if (columnname_from_ir->right_ != nullptr || columnname_from_ir->str_val_ == "*" || columnname_from_ir->left_ == nullptr) {return;}  // Semantic error
    string columnname_from_str = columnname_from_ir->left_->str_val_;

    for (auto iter = m_tables.begin(); iter != m_tables.end(); iter++) {
      vector<string>& table2column_vec = iter->second;
      for (string& cur_column_str : table2column_vec) {
        if (cur_column_str == columnname_from_str) {
          cur_column_str = columnname_to_str;
        }
      }
    }
    if (is_debug_info) {
      cerr << "Dependency: In resolve_alter_statement, altering column_name: " << columnname_from_str <<  " to " << columnname_to_str << "\n\n\n";
    }
    return;
  }

  // ADD columns.
  if (strcmp(op_->middle_, "ADD") == 0) {
    IR* tablename_ir = cur_ir->left_;
    if (cur_ir->right_->right_ != nullptr) {tablename_ir = cur_ir->right_;}
    else {tablename_ir = cur_ir->left_;}
    string tablename_str = tablename_ir->str_val_;

    IR* columnname_ir = cur_ir->get_parent()->right_->left_->left_;
    string columnname_str = columnname_ir->str_val_;

    m_tables[tablename_str].push_back(columnname_str);
    if (is_debug_info) {
      cerr << "Dependency: In resolve_alter_statement, adding column_name: " << columnname_str << "\n\n\n";
    }

    return;
  }

  // DROP columns.
  if (strcmp(op_->middle_, "DROP") == 0) {
    IR* tablename_ir = cur_ir->left_;
    if (cur_ir->right_ != nullptr) {tablename_ir = cur_ir->right_;}
    else {tablename_ir = cur_ir->left_;}
    string tablename_str = tablename_ir->str_val_;

    IR* columnname_ir = cur_ir->get_parent()->right_;
    if (columnname_ir->right_ != nullptr || columnname_ir->str_val_ == "*" || columnname_ir->left_ == nullptr) {return;}  // Semantic error
    string columnname_from_str = columnname_ir->left_->str_val_;
    string columnname_str = columnname_ir->str_val_;

    vector<string>& table2column_vec = m_tables[tablename_str];
    table2column_vec.erase(std::remove(table2column_vec.begin(), table2column_vec.end(), columnname_str), table2column_vec.end());

    if (is_debug_info) {
      cerr << "Dependency: In resolve_alter_statement, dropping column_name: " << columnname_str << "\n\n\n";
    }

    return;
  }
  return;

}


unsigned int Mutator::calc_node(IR *root) {
  unsigned int res = 0;
  if (root->left_)
    res += calc_node(root->left_);
  if (root->right_)
    res += calc_node(root->right_);

  return res + 1;
}

string Mutator::extract_struct(string query) {

  vector<IR *> original_ir_tree = parse_query_str_get_ir_set(query);

  string res = "";

  if (original_ir_tree.size() > 0) {

    IR *root = original_ir_tree[original_ir_tree.size() - 1];
    res = extract_struct(root);
    root->deep_drop();
  }

  return res;
}

string Mutator::extract_struct(IR *root) {

  string res = "";
  _extract_struct(root, res);
  trim_string(res);
  return res;
}

void Mutator::_extract_struct(IR *root, string &res) {

  static int counter = 0;
  auto *right_ = root->right_, *left_ = root->left_;
  auto *op_ = root->op_;
  auto type_ = root->type_;
  auto str_val_ = root->str_val_;

  if (root->id_type_ == id_pragma_name || root->id_type_ == id_pragma_value || root->id_type_ == id_collation_name) {
      res += str_val_;
      return;
  }

  if (type_ == kColumnName && str_val_ == "*") {
    res += str_val_;
    return;
  }

  if (type_ == kOptOrderType || type_ == kNullLiteral || type_ == kColumnType ||
      type_ == kSetOperator || type_ == kOptJoinType || type_ == kOptDistinct) {
    res += str_val_;
    return;
  }

  if (root->id_type_ != id_whatever && root->id_type_ != id_module_name) {
    res += "y";
    root->str_val_ = "y";
    return;
  }

  if (type_ == kStringLiteral) {
    string str_val = str_val_;
    str_val.erase(std::remove(str_val.begin(), str_val.end(), '\''),
                  str_val.end());
    str_val.erase(std::remove(str_val.begin(), str_val.end(), '"'),
                  str_val.end());
    string magic_string = magic_string_generator(str_val);
    unsigned long h = hash(magic_string);
    if (string_libary_hash_.find(h) == string_libary_hash_.end()) {

      string_libary.push_back(magic_string);
      string_libary_hash_.insert(h);
    }
    res += "'y'";
    root->str_val_ = "'y'";
    return;
  }

  if (type_ == kNumericLiteral) {
    unsigned long h = hash(root->str_val_);
    if (value_library_hash_.find(h) == value_library_hash_.end()) {
      value_libary.push_back(root->str_val_);
      value_library_hash_.insert(h);
    }
    res += "10";
    root->str_val_ = "10";
    return;
  }

  if (type_ == kFilePath) {
    res += "'file_name'";
    root->str_val_ = "'file_name'";
    return;
  }

  if (!str_val_.empty()) {
    res += str_val_;
    return;
  }

  if (op_ && op_->prefix_) {
    res += op_->prefix_;
    res += " ";
  }

  if (left_) {
    _extract_struct(left_, res);
    res += " ";
  }

  if (op_ && op_->middle_) {
    res += op_->middle_;
    res += " ";
  }

  if (right_) {
    _extract_struct(right_, res);
    res += " ";
  }

  if (op_ && op_->suffix_) {
    res += op_->suffix_;
  }

  return;
}

void Mutator::add_new_table(IR *root, string &table_name) {

  if (root->left_ != NULL)
    add_new_table(root->left_, table_name);

  if (root->right_ != NULL)
    add_new_table(root->right_, table_name);

  // add to table_name_lib_
  if (root->type_ == kTableName) {
    if (root->operand_num_ == 1) {
      table_name = root->left_->str_val_;
    } else if (root->operand_num_ == 2) {
      table_name = root->left_->str_val_ + "." + root->right_->str_val_;
    }
  }

  // add to column_name_lib_
  if (root->type_ == kColumnDef) {
    auto tmp = root->left_;
    if (tmp->type_ == kIdentifier) {
      if (!table_name.empty() && !tmp->str_val_.empty())
        ;
      m_tables[table_name].push_back(tmp->str_val_);
      if (find(v_table_names.begin(), v_table_names.end(), table_name) !=
          v_table_names.end())
        v_table_names.push_back(table_name);
    }
  }
}

void Mutator::reset_database() {
  m_tables.clear();
  v_table_names.clear();
  m_table2index.clear();
  m_table2alias_single.clear();
  v_table_names_single.clear();
  v_create_table_names_single.clear();
  v_alias_names_single.clear();

  m_tables_with_tmp.clear();
  v_create_table_names_single_with_tmp.clear();
  v_create_column_names_single_with_tmp.clear();

  used_string_library.clear();
  used_value_libary.clear();
}

void Mutator::reset_database_single_stmt() {
  v_table_names_single.clear();
  v_create_table_names_single.clear();
  v_alias_names_single.clear();
  m_table2alias_single.clear();

  m_tables_with_tmp.clear();
  v_create_table_names_single_with_tmp.clear();
  v_create_column_names_single_with_tmp.clear();
}


Program *Mutator::parser(const char *query) {

  yyscan_t scanner;
  YY_BUFFER_STATE state;

  if (hsql_lex_init(&scanner)) return NULL;

  state = hsql__scan_string(query, scanner);

  Program *p = new Program();
  int ret = hsql_parse(p, scanner);

  hsql__delete_buffer(state, scanner);
  hsql_lex_destroy(scanner);
  if (ret != 0) {
    p->deep_delete();
    return NULL;
  }

  return p;
}

// Return use_temp or not.
bool Mutator::get_valid_str_from_lib(string &ori_oracle_select) {
  /* For 1/2 chance, grab one query from the oracle library, and return.
   * For 1/2 chance, take the template from the p_oracle and return.
   */
  bool is_succeed = false;

  while (!is_succeed) { // Potential dead loop. Only escape through return.
    bool use_temp = false;
    int query_method = get_rand_int(2);
    if (all_valid_pstr_vec.size() > 0 && query_method < 1) {
      /* Pick the query from the lib, pass to the mutator. */
      if (use_cri_val && all_cri_valid_pstr_vec.size() > 0 &&
          get_rand_int(3) < 2) {
        ori_oracle_select = *(all_cri_valid_pstr_vec[get_rand_int(
            all_cri_valid_pstr_vec.size())]);
      } else {
        ori_oracle_select =
            *(all_valid_pstr_vec[get_rand_int(all_valid_pstr_vec.size())]);
      }
      if (ori_oracle_select == "" ||
          !p_oracle->is_oracle_select_stmt_str(ori_oracle_select))
        {continue;}
      use_temp = false;
    } else {
      /* Pick the query from the template, pass to the mutator. */
      ori_oracle_select = p_oracle->get_temp_valid_stmts();
      use_temp = true;
    }

    trim_string(ori_oracle_select);
    return use_temp;
  }
  fprintf(stderr, "*** FATAL ERROR: Unexpected code execution in the "
                  "Mutator::get_valid_str_from_lib function. \n");
  fflush(stderr);
  abort();
}

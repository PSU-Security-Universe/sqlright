#include "../include/mutate.h"
#include "../include/ast.h"
#include "../include/define.h"
#include "../include/utils.h"

#include "../include/relopt_generator.h"

#include "../oracle/postgres_norec.h"
#include "../oracle/postgres_oracle.h"

#include "../AFL/debug.h"

#include "../parser/parser_for_sqlright.h"
#include <sys/resource.h>
#include <sys/time.h>

#include <algorithm>
#include <assert.h>
#include <cfloat>
#include <climits>
#include <cstdio>
#include <deque>
#include <fstream>
#include <algorithm>
#include <string>
#include <iostream>
#define _NON_REPLACE_

using namespace std;

set<IR *> Mutator::visited;  // Already validated/fixed node. Avoid multiple fixing. 
map<string, vector<string>> Mutator::m_tables;   // Table name to column name mapping. 
map<string, vector<string>> Mutator::m_table2index;   // Table name to index mapping. 
vector<string> Mutator::v_table_names;  // All saved table names
vector<string> Mutator::v_table_names_single; // All used table names in one query statement. 
vector<string> Mutator::v_create_table_names_single; // All table names just created in the current stmt. 
vector<string> Mutator::v_alias_names_single; // All alias name local to one query statement.  
map<string, vector<string>> Mutator::m_table2alias_single;   // Table name to alias mapping.
map<string, COLTYPE> Mutator::m_column2datatype;   // Column name mapping to column type. 0 means unknown, 1 means numerical, 2 means character_type_, 3 means boolean_type_.
vector<string> Mutator::v_column_names_single; // All used column names in one query statement. Used to confirm literal type.
vector<string> Mutator::v_table_name_follow_single;  // All used table names follow type in one query stmt.
vector<string> Mutator::v_statistics_name; // All statistic names defined in the current stmt.
vector<string> Mutator::v_sequence_name; // All sequence names defined in the current SQL.
vector<string> Mutator::v_view_name; // All saved view names.
vector<string> Mutator::v_constraint_name; // All constraint names defined in the current SQL.
vector<string> Mutator::v_foreign_table_name; // All foreign table names defined inthe current SQL.
vector<string> Mutator::v_create_foreign_table_names_single; // All foreign table names created in the current SQL.

map<IRTYPE, vector<pair<string, DEF_ARG_TYPE>>> Mutator::m_reloption;
vector<string> Mutator::v_sys_column_name;
vector<string> Mutator::v_sys_catalogs_name;

vector<string> Mutator::v_aggregate_func;
vector<string> Mutator::v_table_with_partition_name;

vector<string> Mutator::v_saved_reloption_str;

vector<int> Mutator::v_int_literals;
vector<double> Mutator::v_float_literals;
vector<string> Mutator::v_string_literals;

//#define GRAPHLOG

IR *Mutator::deep_copy_with_record(const IR *root, const IR *record) {
  IR *left = NULL, *right = NULL, *copy_res;

  if (root->left_)
    left = deep_copy_with_record(root->left_, record);
  if (root->right_)
    right = deep_copy_with_record(root->right_, record);

  if (root->op_)
    copy_res = new IR(root->type_,
               OP3(root->op_->prefix_, root->op_->middle_, root->op_->suffix_),
               left, right, root->float_val_, root->str_val_, root->name_,
               root->mutated_times_, root->scope_, root->data_flag_);
  else
    copy_res = new IR(root->type_, NULL, left, right, root->float_val_,
                      root->str_val_, root->name_, root->mutated_times_,
                      root->scope_, root->data_flag_);

  copy_res->data_type_ = root->data_type_;

  if (root == record && record != NULL) {
    this->record_ = copy_res;
  }

  return copy_res;
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

  // // For strategy_replace
  // cur_root = root->deep_copy();
  // p_oracle->ir_wrapper.set_ir_root(cur_root);

  // vector<IR*> ori_stmt_list = p_oracle->ir_wrapper.get_stmt_ir_vec();
  // IR* rep_old_ir = ori_stmt_list[get_rand_int(ori_stmt_list.size())];

  // IR * new_stmt_ir = NULL;
  // /* Get new insert statement. However, do not insert kSelectStatement */
  // int trial = 0;
  // while (new_stmt_ir == NULL) {
  //   new_stmt_ir = get_from_libary_with_type(kStmt);
  //   if (new_stmt_ir == nullptr || new_stmt_ir->left_ == nullptr) {
  //     // cerr << "kStmt is empty;\n\n\n";
  //     cur_root->deep_drop();
  //     goto STMTLIST_INSERT;
  //   }
  //   if (new_stmt_ir->left_->type_ == kSelectStmt) {
  //     // cerr << "Getting Select Stmt;\n\n\n";
  //     new_stmt_ir->deep_drop();
  //     new_stmt_ir = NULL;
  //   }
  //   trial++;
  //   if (trial > 100) {
  //     cur_root->deep_drop();
  //     goto STMTLIST_INSERT;
  //   }
  //   continue;
  // }

  // IR* new_stmt_ir_tmp;
  // new_stmt_ir_tmp = new_stmt_ir->left_->deep_copy();  // kStatement -> specific_stmt_type
  // new_stmt_ir->deep_drop();
  // new_stmt_ir = new_stmt_ir_tmp;

  // // cerr << "Replacing rep_old_ir: " << rep_old_ir->to_string() << " to: " << new_stmt_ir->to_string() << ". \n\n\n";

  // p_oracle->ir_wrapper.set_ir_root(cur_root);
  // if(!p_oracle->ir_wrapper.replace_stmt_and_free(rep_old_ir, new_stmt_ir)){
  //   new_stmt_ir->deep_drop();
  //   cur_root->deep_drop();
  //   return res_vec;
  // }
  // res_vec.push_back(cur_root);

  // For strategy_insert
// STMTLIST_INSERT:
  cur_root = root->deep_copy();
  p_oracle->ir_wrapper.set_ir_root(cur_root);

  int insert_pos = get_rand_int(p_oracle->ir_wrapper.get_stmt_num());

  /* Get new insert statement. However, do not insert kSelectStatement */
  IR* new_stmt_ir = NULL;
  while (new_stmt_ir == NULL) {
    new_stmt_ir = get_from_libary_with_type(kStmt);
    if (new_stmt_ir == nullptr || new_stmt_ir->left_ == nullptr) {
      // cerr << "kStmt is empty;\n\n\n";
      cur_root->deep_drop();
      return res_vec;
    }
    if (new_stmt_ir->left_->type_ == kSelectStmt) {
      // cerr << "Getting Select Stmt;\n\n\n";
      new_stmt_ir->deep_drop();
      new_stmt_ir = NULL;
    }
    continue;
  }
  IR* new_stmt_ir_tmp = new_stmt_ir->left_->deep_copy();  // kStatement -> specific_stmt_type
  new_stmt_ir->deep_drop();
  new_stmt_ir = new_stmt_ir_tmp;

  // cerr << "Inserting stmt: " << new_stmt_ir->to_string() << "\n\n\n";

  p_oracle->ir_wrapper.set_ir_root(cur_root);
  if(!p_oracle->ir_wrapper.append_stmt_at_idx(new_stmt_ir, insert_pos)) {
    new_stmt_ir->deep_drop();
    cur_root->deep_drop();
    return res_vec;
  }
  res_vec.push_back(cur_root);

  return res_vec;

}



vector<IR *> Mutator::mutate_all(IR* ori_ir_root, IR* ir_to_mutate, u64& total_mutate_failed, u64& total_mutate_num) {

  IR *root = ori_ir_root;
  vector<IR*> res;
  vector<IR*> v_mutated_ir;

  // debug(ori_ir_root, 0);

  // cerr << "Inside mutate_all; \n\n\n";

  if (ir_to_mutate->get_ir_type() == kParseToplevel) return res;
  
  /* For mutating kStmtList only */
  if (ir_to_mutate->get_ir_type() == kStmtmulti) {
    // cerr << "Inside kStmtList; \n\n\n";
    v_mutated_ir = mutate_stmtlist(root);
    // cerr << "Mutating stmt_list, getting size: " << v_mutated_ir.size() << "\n\n\n";
    for (IR* mutated_ir : v_mutated_ir) {

        string tmp = mutated_ir->to_string();

        unsigned tmp_hash = hash(tmp);
        if (global_hash_.find(tmp_hash) != global_hash_.end()) {
          mutated_ir->deep_drop();
          // cerr << "Aboard old_ir because tmp_hash being saved before. "
          //      << "In func: Mutator::mutate_all(); \n";
          continue;
        }
        // cerr << "Currently mutating (stmtlist). After mutation, the generated str is: " << mutated_ir->to_string() << "\n\n\n";
        global_hash_.insert(tmp_hash);
        res.push_back(mutated_ir);
    }

    return res;
  }

  // cerr << "Inside rest; \n\n\n";
  // else, for mutating single IR node. 

  v_mutated_ir = mutate(ir_to_mutate);

  for (IR* new_ir : v_mutated_ir) {
    total_mutate_num++;
    if (!root->swap_node(ir_to_mutate, new_ir)) {
      new_ir->deep_drop();
      total_mutate_failed++;
      continue;
    }

    string tmp = root->to_string();

    /* Check whether the mutated IR is the same as before */
    unsigned tmp_hash = hash(tmp);
    if (global_hash_.find(tmp_hash) != global_hash_.end()) {
      root->swap_node(new_ir, ir_to_mutate);
      new_ir->deep_drop();
      total_mutate_failed++;
      continue;
    }
    global_hash_.insert(tmp_hash);

    /* Mutate successful. Save the mutation and recover the original ir_tree */
    res.push_back(root->deep_copy());
    root->swap_node(new_ir, ir_to_mutate);
    new_ir->deep_drop();
  }

  return res;
}

void Mutator::add_ir_to_library(IR *cur) {
  extract_struct(cur);
  cur = deep_copy(cur);
  add_ir_to_library_no_deepcopy(cur);
  return;
}

void Mutator::add_ir_to_library_no_deepcopy(IR *cur) {
  if (cur->left_)
    add_ir_to_library_no_deepcopy(cur->left_);
  if (cur->right_)
    add_ir_to_library_no_deepcopy(cur->right_);

  auto type = cur->type_;
  auto h = hash(cur);
  if (find(ir_library_hash_[type].begin(), ir_library_hash_[type].end(), h) !=
      ir_library_hash_[type].end())
    return;

  ir_library_hash_[type].insert(h);
  ir_library_[type].push_back(cur);

  return;
}

void Mutator::init_common_string(string filename) {
  common_string_library_.push_back("DO_NOT_BE_EMPTY");
  if (filename != "") {
    ifstream input_string(filename);
    string s;

    while (getline(input_string, s)) {
      common_string_library_.push_back(s);
    }
  }
}

void Mutator::init_data_library_2d(string filename) {
  ifstream input_file(filename);
  string s;

  cout << "[*] init data_library_2d: " << filename << endl;
  while (getline(input_file, s)) {
    vector<string> v_strbuf;
    auto prev_pos = -1;
    for (int i = 0; i < 3; i++) {
      auto pos = s.find(" ", prev_pos + 1);
      v_strbuf.push_back(s.substr(prev_pos + 1, pos - prev_pos - 1));
      prev_pos = pos;
    }
    v_strbuf.push_back(s.substr(prev_pos + 1, s.size() - prev_pos - 1));

    auto data_type1 = get_datatype_by_string(v_strbuf[0]);
    auto data_type2 = get_datatype_by_string(v_strbuf[2]);
    g_data_library_2d_[data_type1][v_strbuf[1]][data_type2].push_back(
        v_strbuf[3]);
  }

  return;
}

void Mutator::init_data_library(string filename) {
  ifstream input_file(filename);
  string s;

  cout << "[*] init data_library: " << filename << endl;
  while (getline(input_file, s)) {
    auto pos = s.find(" ");
    if (pos == string::npos)
      continue;
    auto data_type = get_datatype_by_string(s.substr(0, pos));
    auto v = s.substr(pos + 1, s.size() - pos - 1);
    g_data_library_[data_type].push_back(v);
  }

  return;
}

inline void Mutator::init_value_library() {
  if (value_library_.size() != 0) {
    return;
  }
  vector<unsigned long> value_lib_init = {0,
                                          (unsigned long)LONG_MAX,
                                          (unsigned long)ULONG_MAX,
                                          (unsigned long)CHAR_BIT,
                                          (unsigned long)SCHAR_MIN,
                                          (unsigned long)SCHAR_MAX,
                                          (unsigned long)UCHAR_MAX,
                                          (unsigned long)CHAR_MIN,
                                          (unsigned long)CHAR_MAX,
                                          (unsigned long)MB_LEN_MAX,
                                          (unsigned long)SHRT_MIN,
                                          (unsigned long)INT_MIN,
                                          (unsigned long)INT_MAX,
                                          (unsigned long)SCHAR_MIN,
                                          (unsigned long)SCHAR_MIN,
                                          (unsigned long)UINT_MAX,
                                          (unsigned long)FLT_MAX,
                                          (unsigned long)DBL_MAX,
                                          (unsigned long)LDBL_MAX,
                                          (unsigned long)FLT_MIN,
                                          (unsigned long)DBL_MIN,
                                          (unsigned long)LDBL_MIN};

  value_library_.insert(value_library_.begin(), value_lib_init.begin(),
                        value_lib_init.end());

  return;
}

void Mutator::init_ir_library(string filename) {
  ifstream input_file(filename);
  string line;

  cout << "[*] init ir_library: " << filename << endl;
  while (getline(input_file, line)) {
    if (line.empty())
      continue;

    IR* res = raw_parser(line.c_str(), RAW_PARSE_DEFAULT); // RAW_PARSE_DEFAULT = 0
    if (res == NULL) {
      continue;
    }

    add_ir_to_library(res);
    deep_delete(res);
  }
  return;
}

// void Mutator::init_safe_generate_type(string filename) {
//   ifstream input_file(filename);
//   string line;

//   cout << "[*] init safe generate type: " << filename << endl;
//   while (getline(input_file, line)) {
//     if (line.empty())
//       continue;
//     auto node_type = get_irtype_by_string("k" + line);
//     safe_generate_type_.insert(node_type);
//   }
// }

void Mutator::init_library() {

  // init value_library_
  init_value_library();


  if (not_mutatable_types_.size() == 0) {
    float_types_.insert({kFloatLiteral});
    int_types_.insert(kIntLiteral);
    string_types_.insert(kStringLiteral);

    relationmap_[kDataColumnName][kDataTableName] = kRelationSubtype;
    relationmap_[kDataPragmaValue][kDataPragmaKey] = kRelationSubtype;
    relationmap_[kDataTableName][kDataTableName] = kRelationElement;
    relationmap_[kDataColumnName][kDataColumnName] = kRelationElement;

    split_stmt_types_.insert(kStmt);
    split_substmt_types_.insert({kSelectNoParens});

    not_mutatable_types_.insert({kParseToplevel, kStmtlist, kStmt, kCreateStmt,
                                 kDropStmt, kCreateTableStmt, kCreateIndexStmt,
                                 kCreateViewStmt, kDropIndexStmt, kDropTableStmt,
                                 kDropViewStmt, kSelectStmt, kUpdateStmt,
                                 kInsertStmt, kAlterStmt, kReindexStmt});
  }


  // Initialize the common_string_library();
  common_string_library_.push_back("HELLO");
  common_string_library_.push_back("WORLD");
  common_string_library_.push_back("test");
  common_string_library_.push_back("files");
  common_string_library_.push_back("music");
  common_string_library_.push_back("score");
  common_string_library_.push_back("green");
  common_string_library_.push_back("red");
  common_string_library_.push_back("right");
  common_string_library_.push_back("left");
  common_string_library_.push_back("plot");
  common_string_library_.push_back("cov");
  common_string_library_.push_back("bug");
  common_string_library_.push_back("sample");

  // Initialize the storage parameters from the CREATE TABLE stmt.

  vector<pair<string, DEF_ARG_TYPE>> storage_parameter_pair;
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("fillfactor", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("toast_tuple_target", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("parallel_workers", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_enabled", DEF_ARG_TYPE::boolean));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("vacuum_index_cleanup", DEF_ARG_TYPE::on_off_auto));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("vacuum_truncate", DEF_ARG_TYPE::boolean));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_vacuum_threshold", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_vacuum_scale_factor", DEF_ARG_TYPE::floating_point));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_vacuum_insert_threshold", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_vacuum_insert_scale_factor", DEF_ARG_TYPE::floating_point));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_analyze_scale_factor", DEF_ARG_TYPE::floating_point));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_vacuum_cost_delay", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_vacuum_cost_limit", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_freeze_min_age", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_freeze_max_age", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_multixact_freeze_min_age", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_multixact_freeze_max_age", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("autovacuum_multixact_freeze_table_age", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("log_autovacuum_min_duration", DEF_ARG_TYPE::integer));
  storage_parameter_pair.push_back(pair<string, DEF_ARG_TYPE> ("user_catalog_table", DEF_ARG_TYPE::boolean));

  this->m_reloption[kCreateStmt] = storage_parameter_pair;

  /* added the supported aggregate functons.  */
  this->v_aggregate_func.push_back("SUM");
  this->v_aggregate_func.push_back("COUNT");
  this->v_aggregate_func.push_back("MAX");
  this->v_aggregate_func.push_back("MIN");
  this->v_aggregate_func.push_back("AVG");


  /* Added default column type for Postgres */
  this->v_sys_column_name.push_back("oid");
  this->v_sys_column_name.push_back("tableoid");
  this->v_sys_column_name.push_back("xmin");
  this->v_sys_column_name.push_back("cmin");
  this->v_sys_column_name.push_back("xmax");
  this->v_sys_column_name.push_back("cmax");
  this->v_sys_column_name.push_back("ctid");

  this->v_sys_catalogs_name.push_back("pg_aggregate");
  this->v_sys_catalogs_name.push_back("g_am");
  this->v_sys_catalogs_name.push_back("g_amop");
  this->v_sys_catalogs_name.push_back("g_amproc");
  this->v_sys_catalogs_name.push_back("g_attrdef");
  this->v_sys_catalogs_name.push_back("g_attribute");
  this->v_sys_catalogs_name.push_back("g_authid");
  this->v_sys_catalogs_name.push_back("g_auth_members");
  this->v_sys_catalogs_name.push_back("pg_cast");
  this->v_sys_catalogs_name.push_back("pg_class");
  this->v_sys_catalogs_name.push_back("pg_collation");
  this->v_sys_catalogs_name.push_back("pg_constraint");
  this->v_sys_catalogs_name.push_back("pg_conversion");
  this->v_sys_catalogs_name.push_back("pg_database");
  this->v_sys_catalogs_name.push_back("pg_db_role_setting");
  this->v_sys_catalogs_name.push_back("pg_default_acl");
  this->v_sys_catalogs_name.push_back("pg_depend");
  this->v_sys_catalogs_name.push_back("pg_description");
  this->v_sys_catalogs_name.push_back("pg_enum");
  this->v_sys_catalogs_name.push_back("pg_event_trigger");
  this->v_sys_catalogs_name.push_back("pg_extension");
  this->v_sys_catalogs_name.push_back("pg_foreign_data_wrapper");
  this->v_sys_catalogs_name.push_back("pg_foreign_server");
  this->v_sys_catalogs_name.push_back("pg_foreign_table");
  this->v_sys_catalogs_name.push_back("pg_index");
  this->v_sys_catalogs_name.push_back("pg_inherits");
  this->v_sys_catalogs_name.push_back("pg_init_privs");
  this->v_sys_catalogs_name.push_back("pg_language");
  this->v_sys_catalogs_name.push_back("pg_largeobject");
  this->v_sys_catalogs_name.push_back("pg_largeobject_metadata");
  this->v_sys_catalogs_name.push_back("pg_namespace");
  this->v_sys_catalogs_name.push_back("pg_opclass");
  this->v_sys_catalogs_name.push_back("pg_operator");
  this->v_sys_catalogs_name.push_back("pg_opfamily");
  this->v_sys_catalogs_name.push_back("pg_partitioned_table");
  this->v_sys_catalogs_name.push_back("pg_policy");
  this->v_sys_catalogs_name.push_back("pg_proc");
  this->v_sys_catalogs_name.push_back("pg_publication");
  this->v_sys_catalogs_name.push_back("pg_publication_rel");
  this->v_sys_catalogs_name.push_back("pg_range");
  this->v_sys_catalogs_name.push_back("pg_replication_origin");
  this->v_sys_catalogs_name.push_back("pg_rewrite");
  this->v_sys_catalogs_name.push_back("pg_seclabel");
  this->v_sys_catalogs_name.push_back("pg_sequence");
  this->v_sys_catalogs_name.push_back("pg_shdepend");
  this->v_sys_catalogs_name.push_back("pg_shdescription");
  this->v_sys_catalogs_name.push_back("pg_shseclabel");
  this->v_sys_catalogs_name.push_back("pg_statistic");
  this->v_sys_catalogs_name.push_back("pg_statistic_ext");
  this->v_sys_catalogs_name.push_back("pg_statistic_ext_data");
  this->v_sys_catalogs_name.push_back("pg_subscription");
  this->v_sys_catalogs_name.push_back("pg_subscription_rel");
  this->v_sys_catalogs_name.push_back("pg_tablespace");
  this->v_sys_catalogs_name.push_back("pg_transform");
  this->v_sys_catalogs_name.push_back("pg_trigger");
  this->v_sys_catalogs_name.push_back("pg_ts_config");
  this->v_sys_catalogs_name.push_back("pg_ts_config_map");
  this->v_sys_catalogs_name.push_back("pg_ts_dict");
  this->v_sys_catalogs_name.push_back("pg_ts_parser");
  this->v_sys_catalogs_name.push_back("pg_ts_template");
  this->v_sys_catalogs_name.push_back("pg_type");
  this->v_sys_catalogs_name.push_back("pg_user_mapping");
  this->v_sys_catalogs_name.push_back("System Views");
  this->v_sys_catalogs_name.push_back("pg_available_extensions");
  this->v_sys_catalogs_name.push_back("pg_available_extension_versions");
  this->v_sys_catalogs_name.push_back("pg_backend_memory_contexts");
  this->v_sys_catalogs_name.push_back("pg_config");
  this->v_sys_catalogs_name.push_back("pg_cursors");
  this->v_sys_catalogs_name.push_back("pg_file_settings");
  this->v_sys_catalogs_name.push_back("pg_group");
  this->v_sys_catalogs_name.push_back("pg_hba_file_rules");
  this->v_sys_catalogs_name.push_back("pg_indexes");
  this->v_sys_catalogs_name.push_back("pg_locks");
  this->v_sys_catalogs_name.push_back("pg_matviews");
  this->v_sys_catalogs_name.push_back("pg_policies");
  this->v_sys_catalogs_name.push_back("pg_prepared_statements");
  this->v_sys_catalogs_name.push_back("pg_prepared_xacts");
  this->v_sys_catalogs_name.push_back("pg_publication_tables");
  this->v_sys_catalogs_name.push_back("pg_replication_origin_status");
  this->v_sys_catalogs_name.push_back("pg_replication_slots");
  this->v_sys_catalogs_name.push_back("pg_roles");
  this->v_sys_catalogs_name.push_back("pg_rules");
  this->v_sys_catalogs_name.push_back("pg_seclabels");
  this->v_sys_catalogs_name.push_back("pg_sequences");
  this->v_sys_catalogs_name.push_back("pg_settings");
  this->v_sys_catalogs_name.push_back("pg_shadow");
  this->v_sys_catalogs_name.push_back("pg_shmem_allocations");
  this->v_sys_catalogs_name.push_back("pg_stats");
  this->v_sys_catalogs_name.push_back("pg_stats_ext");
  this->v_sys_catalogs_name.push_back("pg_stats_ext_exprs");
  this->v_sys_catalogs_name.push_back("pg_tables");
  this->v_sys_catalogs_name.push_back("pg_timezone_abbrevs");
  this->v_sys_catalogs_name.push_back("pg_timezone_names");
  this->v_sys_catalogs_name.push_back("pg_user");
  this->v_sys_catalogs_name.push_back("pg_user_mappings");
  this->v_sys_catalogs_name.push_back("pg_views");
}


void Mutator::init(string f_testcase, string f_common_string, string file2d,
                   string file1d, string f_gen_type) {

  // if (!f_testcase.empty());
  //   init_ir_library(f_testcase);


  /* init common_string_library */
  if (!f_common_string.empty())
    {init_common_string(f_common_string);}

  // init data_library_2d
  // if (!file2d.empty())
  //   init_data_library_2d(file2d);

  // if (!file1d.empty())
  //   init_data_library(file1d);
  // if (!f_gen_type.empty())
  //   init_safe_generate_type(f_gen_type);


  ifstream input_test(f_testcase);
  string line;

  // init lib from multiple sql
  while (getline(input_test, line)) {

    // cerr << "Parsing init line: " << line << "\n";

    vector<IR *> v_ir = parse_query_str_get_ir_set(line);
    if (v_ir.size() <= 0) {
      cerr << "failed to parse: " << line << endl;
      continue;
    }

    IR* v_ir_root = v_ir.back();
    string strip_sql = extract_struct(v_ir_root);
    v_ir.back()->deep_drop();
    v_ir.clear();

    v_ir = parse_query_str_get_ir_set(strip_sql);
    if (v_ir.size() <= 0) {
      cerr << "failed to parse after extract_struct:" << endl
           << line << endl
           << strip_sql << "\n\n\n";
      continue;
    }

    // cerr << "Parsing succeed. \n\n\n";

    add_all_to_library(v_ir.back());
    v_ir.back()->deep_drop();
  }

  return;
}

vector<IR *> Mutator::mutate(IR *input) {
  vector<IR *> res;

  if (!lucky_enough_to_be_mutated(input->mutated_times_)) {
    return res;
  }
  auto tmp = strategy_delete(input);
  if (tmp != NULL) {
    res.push_back(tmp);
  }

  tmp = strategy_insert(input);
  if (tmp != NULL) {
    res.push_back(tmp);
  }

  tmp = strategy_replace(input);
  if (tmp != NULL) {
    res.push_back(tmp);
  }

  input->mutated_times_ += res.size();
  for (auto i : res) {
    if (i == NULL)
      continue;
    i->mutated_times_ = input->mutated_times_;
  }
  return res;
}

bool Mutator::replace(IR *root, IR *old_ir, IR *new_ir) {
  auto parent_ir = locate_parent(root, old_ir);
  if (parent_ir == NULL)
    return false;
  if (parent_ir->left_ == old_ir) {
    deep_delete(old_ir);
    parent_ir->left_ = new_ir;
    return true;
  } else if (parent_ir->right_ == old_ir) {
    deep_delete(old_ir);
    parent_ir->right_ = new_ir;
    return true;
  }
  return false;
}

IR *Mutator::locate_parent(IR *root, IR *old_ir) {

  if (root->left_ == old_ir || root->right_ == old_ir)
    return root;

  if (root->left_ != NULL)
    if (auto res = locate_parent(root->left_, old_ir))
      return res;
  if (root->right_ != NULL)
    if (auto res = locate_parent(root->right_, old_ir))
      return res;

  return NULL;
}

IR *Mutator::strategy_delete(IR *cur) {
  assert(cur);
  MUTATESTART

  DOLEFT
  res = deep_copy(cur);
  if (res->left_ != NULL)
    deep_delete(res->left_);
  res->left_ = NULL;

  DORIGHT
  res = deep_copy(cur);
  if (res->right_ != NULL)
    deep_delete(res->right_);
  res->right_ = NULL;

  DOBOTH
  res = deep_copy(cur);
  if (res->left_ != NULL)
    deep_delete(res->left_);
  if (res->right_ != NULL)
    deep_delete(res->right_);
  res->left_ = res->right_ = NULL;

  MUTATEEND
}

IR *Mutator::strategy_insert(IR *cur) {
  // NOTE(vancir): rewritten by vancir.
  assert(cur);

  // auto res = deep_copy(cur);
  // auto parent_type = cur->type_;

  // if (res->right_ == NULL && res->left_ != NULL) {
  //   auto left_type = res->left_->type_;
  //   for (int k = 0; k < 4; k++) {
  //     auto fetch_ir = get_ir_from_library(parent_type);
  //     if (fetch_ir->left_ != NULL && fetch_ir->left_->type_ == left_type &&
  //         fetch_ir->right_ != NULL) {
  //       res->right_ = deep_copy(fetch_ir->right_);
  //       return res;
  //     }
  //   }
  // } else if (res->right_ != NULL && res->left_ == NULL) {
  //   auto right_type = res->left_->type_;
  //   for (int k = 0; k < 4; k++) {
  //     auto fetch_ir = get_ir_from_library(parent_type);
  //     if (fetch_ir->right_ != NULL && fetch_ir->right_->type_ == right_type &&
  //         fetch_ir->left_ != NULL) {
  //       res->left_ = deep_copy(fetch_ir->left_);
  //       return res;
  //     }
  //   }
  // } else if (res->left_ == NULL && res->right_ == NULL) {
  //   for (int k = 0; k < 4; k++) {
  //     auto fetch_ir = get_ir_from_library(parent_type);
  //     if (fetch_ir->right_ != NULL && fetch_ir->left_ != NULL) {
  //       res->left_ = deep_copy(fetch_ir->left_);
  //       res->right_ = deep_copy(fetch_ir->right_);
  //       return res;
  //     }
  //   }
  // }

  // return res;

  if (cur->type_ == kStmtlist) {
    auto new_right = get_from_libary_with_left_type(cur->type_);
    if (new_right != NULL) {
      auto res = cur->deep_copy();
      auto new_res = new IR(kStmtlist, OPMID(";"), res, new_right);
      return new_res;
    }
  }

  else if (cur->right_ == NULL && cur->left_ != NULL) {
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
  if (cur->left_ != NULL) {
    res = deep_copy(cur);

    auto new_node = get_ir_from_library(res->left_->type_);
    new_node->data_type_ = res->left_->data_type_;
    deep_delete(res->left_);
    res->left_ = deep_copy(new_node);
  }

  DORIGHT
  if (cur->right_ != NULL) {
    res = deep_copy(cur);

    auto new_node = get_ir_from_library(res->right_->type_);
    new_node->data_type_ = res->right_->data_type_;
    deep_delete(res->right_);
    res->right_ = deep_copy(new_node);
  }

  DOBOTH
  if (cur->left_ != NULL && cur->right_ != NULL) {
    res = deep_copy(cur);

    auto new_left = get_ir_from_library(res->left_->type_);
    auto new_right = get_ir_from_library(res->right_->type_);
    new_left->data_type_ = res->left_->data_type_;
    new_right->data_type_ = res->right_->data_type_;
    deep_delete(res->right_);
    res->right_ = deep_copy(new_right);

    deep_delete(res->left_);
    res->left_ = deep_copy(new_left);
  }

  MUTATEEND

  return res;
}

bool Mutator::lucky_enough_to_be_mutated(unsigned int mutated_times) {
  if (get_rand_int(mutated_times + 1) < LUCKY_NUMBER) {
    return true;
  }
  return false;
}

pair<string, string> Mutator::get_data_2d_by_type(DATATYPE type1,
                                                  DATATYPE type2) {
  pair<string, string> res("", "");
  auto size = data_library_2d_[type1].size();

  if (size == 0)
    return res;
  auto rint = get_rand_int(size);

  int counter = 0;
  for (auto &i : data_library_2d_[type1]) {
    if (counter++ == rint) {
      return std::make_pair(i.first, vector_rand_ele(i.second[type2]));
    }
  }
  return res;
}

// IR *Mutator::generate_ir_by_type(IRTYPE type) {
//   auto ast_node = generate_ast_node_by_type(type);
//   ast_node->generate();
//   vector<IR *> tmp_vector;
//   ast_node->translate(tmp_vector);
//   assert(tmp_vector.size());

//   return tmp_vector[tmp_vector.size() - 1];
// }

IR *Mutator::get_ir_from_library(IRTYPE type) {

  const int generate_prop = 1;
  const int threshold = 0;
  static IR *empty_ir = new IR(kStringLiteral, "");
#ifdef USEGENERATE
  if (ir_library_[type].empty() == true ||
      (get_rand_int(400) == 0 && type != kUnknown)) {
    auto ir = generate_ir_by_type(type);
    add_ir_to_library_no_deepcopy(ir);
    return ir;
  }
#endif
  if (ir_library_[type].empty())
    return empty_ir;
  return vector_rand_ele(ir_library_[type]);
}

string Mutator::get_a_string() {
  unsigned com_size = common_string_library_.size();
  // unsigned lib_size = string_library_.size();

  // if (get_rand_int(3) <= 1) {
    // if (lib_size == 0) {
    //   return "hello";
    // } else {
    //   return string_library_[get_rand_int(lib_size)];
    // }
  // } else {
    if (com_size == 0) {
      return "hello";
    } else {
      return common_string_library_[get_rand_int(com_size)];
    }
  // }
}

unsigned long Mutator::get_a_val() {
  assert(value_library_.size());

  return vector_rand_ele(value_library_);
}

unsigned long Mutator::hash(string &sql) {
  return fuzzing_hash(sql.c_str(), sql.size());
}

unsigned long Mutator::hash(IR *root) {
  auto tmp_str = move(root->to_string());
  return this->hash(tmp_str);
}

void Mutator::debug(IR *root) {
  for (auto &i : data_library_[kDataFunctionName]) {
    cout << i << endl;
  }
}

void Mutator::debug(IR *root, unsigned level) {

  for (unsigned i = 0; i < level; i++)
    cout << " ";

  cout << level << ": "
       << get_string_by_ir_type(root->type_) << ": "
       << get_string_by_data_type(root->data_type_) << ": "
       << get_string_by_data_flag(root->data_flag_) << ": "
       << get_string_by_option_type(root->option_type_) << ": "
       << root->uniq_id_in_tree_ << ": "
       << root -> to_string() 
       << endl;

  if (root->left_)
    debug(root->left_, level + 1);
  if (root->right_)
    debug(root->right_, level + 1);
}

Mutator::~Mutator() {
  for (auto iter = ir_library_.begin(); iter != ir_library_.end(); iter++){
    for (IR* cur_ir : iter->second) {
      cur_ir->deep_drop();
    }
  }

  for (auto iter : all_query_pstr_set) {
    delete iter;
  }



}

string Mutator::extract_struct(IR *root) {
  string res = "";
  _extract_struct(root);
  res = root->to_string();
  trim_string(res);
  return res;
}

void Mutator::_extract_struct(IR *root) {

  if (root->get_data_flag() == kNoModi) {return;}
  if (root->get_data_type() == kDataFunctionName) {return;}
  if (root->get_ir_type() == kFuncName) {return;}
  if (root->get_data_type() == kDataFixLater) {return;}
  if (root->get_data_type() == kDataLiteral) {return;}

  auto type = root->type_;
  if (root->left_) {
    extract_struct(root->left_);
  }
  if (root->right_) {
    extract_struct(root->right_);
  }

  if (root->get_ir_type() == kIntLiteral) {
    root->int_val_ = 0;
    root->str_val_ = "0";
    return;
  } else if (root->get_ir_type() == kFloatLiteral) {
    root->float_val_ = 0.0;
    root->str_val_ = "0.0";
    return;
  } else if (root->get_ir_type() == kBoolLiteral) {
    root->bool_val_ = true;
    root->str_val_ = "true";
    return;
  }
  // else if (root->get_ir_type() == kStringLiteral) {
  //   root->str_val_ = "x";
  //   return;
  // }


  if (root->left_ || root->right_ || root->data_type_ == kDataFunctionName)
    return;

  if (root->data_type_ != kDataWhatever && root->data_type_ != kDataFunctionName) {

    root->str_val_ = "x";
    return;
  }

  if (string_types_.find(type) != string_types_.end()) {
    root->str_val_ = "'x'";
  } else if (int_types_.find(type) != int_types_.end()) {
    root->int_val_ = 1;
  } else if (float_types_.find(type) != float_types_.end()) {
    root->float_val_ = 1.0;
  }
}

void Mutator::extract_struct2(IR *root) {
  static int counter = 0;
  auto type = root->type_;
  if (root->left_) {
    extract_struct2(root->left_);
  }
  if (root->right_) {
    extract_struct2(root->right_);
  }

  if (root->left_ || root->right_)
    return;

  if (root->data_type_ != kDataWhatever) {

    root->str_val_ = "x" + to_string(counter++);
    return;
  }

  if (string_types_.find(type) != string_types_.end()) {
    root->str_val_ = "'x'";
  } else if (int_types_.find(type) != int_types_.end()) {
    root->int_val_ = 1;
  } else if (float_types_.find(type) != float_types_.end()) {
    root->float_val_ = 1.0;
  }
}

string Mutator::parse_data(string &input) {
  string res;
  if (!input.compare("_int_")) {
    res = to_string(get_a_val());
  } else if (!input.compare("_empty_")) {
    res = "";
  } else if (!input.compare("_boolean_")) {
    if (get_rand_int(2) == 0)
      res = "false";
    else
      res = "true";
  } else if (!input.compare("_string_")) {
    res = get_a_string();
  } else {
    res = input;
  }

  return res;
}

void Mutator::pre_validate() {
  // Reset components that is local to the one query sequence. 
  reset_id_counter();
  reset_data_library();
  reset_scope_library(true);
  return;
}

bool Mutator::validate(IR *&cur_stmt, bool is_debug_info) {

  bool res = true;
  if (cur_stmt->type_ == kProgram) {
    vector<IR*> cur_stmt_vec = p_oracle->ir_wrapper.get_stmt_ir_vec(cur_stmt);
    for (IR* cur_stmt_tmp : cur_stmt_vec) {
      res = this->validate(cur_stmt_tmp, is_debug_info) && res;
    }
    return res;
  }

  if (cur_stmt == NULL)
    {return false;}

  /* All the fixing steps happens here. */
  if (is_debug_info) {
    cerr << "Trying to fix stmt: " << cur_stmt->to_string() << " \n";
  }

  if (!fix_one_stmt(cur_stmt, is_debug_info)) {  // Pass in kStmt, not kSpecificStatementType. 
    return false;
  }
  if (is_debug_info) {
    cerr << "After fixing: " << cur_stmt->to_string() << " \n\n\n";
  }
  return true;
}


string Mutator::validate(string query, bool is_debug_info) {
  reset_data_library();
  reset_scope_library(true);

  vector<IR *> ir_set = parse_query_str_get_ir_set(query);
  if (ir_set.size() == 0)
    return "";

  IR *root = ir_set.back();
  if (root->type_ != kParseToplevel) {
    root->deep_drop();
    return "";
  }
  
  if (!this->validate(root, is_debug_info)){
    return "";
  }
  string res = root->to_string();
  root->deep_drop();
  return res;
}

unsigned int Mutator::calc_node(IR *root) {
  unsigned int res = 0;
  if (root->left_)
    res += calc_node(root->left_);
  if (root->right_)
    res += calc_node(root->right_);

  return res + 1;
}


bool Mutator::fix_one_stmt(IR *cur_stmt, bool is_debug_info) {
  bool res = true;

  /* Reset library that is local to one query set. */
  reset_data_library_single_stmt();

  /* m_substmt_save, used for reconstruct the tree. */
  map<IR *, pair<bool, IR*>> m_substmt_save;
  auto substmts = split_to_substmt(cur_stmt, m_substmt_save, split_substmt_types_);

  int substmt_num = substmts.size();
  if (substmt_num > 10) {
    connect_back(m_substmt_save);
    if (is_debug_info) {
      cerr << "Dependency Error: the query is too complicated to fix. Has more than 5 subqueries. \n\n\n";  // Ad-hoc number, just based on intuition.
    }
    return false;
  }

  vector<vector<IR*>> cur_stmt_ir_to_fix;

  for (auto &substmt : substmts) {
    substmt->parent_ = NULL;

    int tmp_node_num = calc_node(substmt);

    /* No sub-queries, then <= 150, sub-queries <= 120 */
    // if ((substmt_num == 1 && tmp_node_num > 230) || tmp_node_num > 200) {
    //   if (is_debug_info) {
    //     cerr << "\n\n\nDepedency Error: The subquery is too complicated to mutate, sub_query node_num: " << tmp_node_num << " is > 200. \n\n\n";
    //   }
    //   continue;
    // }

    vector<IR*> cur_substmt_ir_to_fix;
    this->fix_preprocessing(substmt, cur_substmt_ir_to_fix);

    cur_stmt_ir_to_fix.push_back(cur_substmt_ir_to_fix);

  }

  res = connect_back(m_substmt_save) && res;

  res = fix_dependency(cur_stmt, cur_stmt_ir_to_fix, is_debug_info);

  return res;
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
      post_trans_stmt_vec = p_oracle->post_fix_transform_normal_stmt(cur_pre_trans_ir, run_count); // All deep_copied
    } else if (is_oracle_select) {
      post_trans_stmt_vec = p_oracle->post_fix_transform_select_stmt(cur_pre_trans_ir, run_count); // All deep_copied
    } else {
      post_trans_stmt_vec.push_back(cur_pre_trans_ir->deep_copy());
    }
    
    if (post_trans_stmt_vec.size() > 0){
      all_post_trans_vec.push_back(post_trans_stmt_vec);
    } else {
      /* Debug */
      // cerr << "DEBUG: stmt: " << cur_pre_trans_ir->to_string() << " returns empty. \n";

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

/* 
** From the outer most parent-statements to the inner most sub-statements. 
*/
vector<IR *> Mutator::split_to_substmt(IR *cur_stmt, map<IR *, pair<bool, IR*>> &m_save,
                                    set<IRTYPE> &split_set) {
  vector<IR *> res;
  deque<IR *> bfs = {cur_stmt};
  

  /* The root cur_stmt should always be saved. */
  res.push_back(cur_stmt);

  while (!bfs.empty()) {
    auto node = bfs.front();
    bfs.pop_front();

    if (node && node->left_)
      bfs.push_back(node->left_);
    if (node && node->right_)
      bfs.push_back(node->right_); 

    /* See if current node type is matching split_set. If yes, disconnect node->left and node->right. */
    if (node->left_ &&
        find(split_set.begin(), split_set.end(), node->left_->type_) != split_set.end() && 
        p_oracle->ir_wrapper.is_in_subquery(cur_stmt, node->left_)
    ) {
      res.push_back(node->left_);
      pair<bool, IR*> cur_m_save = make_pair<bool, IR*> (true, node->get_left());
      m_save[node] = cur_m_save;
    }
    if (node->right_ &&
        find(split_set.begin(), split_set.end(), node->right_->type_) != split_set.end() && 
        p_oracle->ir_wrapper.is_in_subquery(cur_stmt, node->right_)
      ) {
      res.push_back(node->right_);
      pair<bool, IR*> cur_m_save = make_pair<bool, IR*> (false, node->get_right());
      m_save[node] = cur_m_save;
    }
  }

  for (int idx = 1; idx < res.size(); idx++) {
    cur_stmt->detach_node(res[idx]);
  }

  return res;
}

bool Mutator::connect_back(map<IR *, pair<bool, IR*>> &m_save) {
  for (auto &iter : m_save) {
    if (iter.second.first) { // is_left?
      iter.first->update_left(iter.second.second);
    } else {
      iter.first->update_right(iter.second.second);
    }
  }
  return true;
}

pair<string, string> Mutator::ir_to_string(IR* root, vector<vector<IR*>> all_post_trans_vec, const vector<STMT_TYPE>& stmt_type_vec) {
  // Final step, IR_to_string function. 
  string output_str_mark, output_str_no_mark; 
  for (int i = 0; i < all_post_trans_vec.size(); i++) { // Loop between different statements. 
    vector<IR*> post_trans_vec = all_post_trans_vec[i];
    int count = 0;
    bool is_oracle_select = false;
    if (stmt_type_vec[i] == ORACLE_SELECT) {is_oracle_select = true;}
    for (IR* cur_trans_stmt : post_trans_vec) {  // Loop between different transformations. 
      string tmp = cur_trans_stmt->to_string();
      if (is_oracle_select) {
        output_str_mark += "SELECT 'BEGIN VERI " + to_string(count) + "'; \n";
        output_str_mark  += tmp + "; \n";
        output_str_mark += "SELECT 'END VERI " + to_string(count) + "'; \n";
        output_str_no_mark += tmp + "; \n";
        count++;
      } else {
        output_str_mark += tmp + "; \n";
        output_str_no_mark += tmp + "; \n";
      }
    }
  }
  pair<string, string> output_str_pair =  make_pair(output_str_mark, output_str_no_mark); 
  return output_str_pair;
}

void Mutator::analyze_scope(IR *stmt_root) {
  if (stmt_root->left_) {
    analyze_scope(stmt_root->left_);
  }
  if (stmt_root->right_) {
    analyze_scope(stmt_root->right_);
  }

  auto data_type = stmt_root->data_type_;
  if (data_type == kDataWhatever)
    return;

  scope_library_[stmt_root->scope_][data_type].push_back(stmt_root);
}

// find tree node whose identifier type can be handled
//
// NOTE: identifier type is different from IR type
//
static void collect_ir(IR *root, set<DATATYPE> &type_to_fix,
                       vector<IR *> &ir_to_fix) {
  DATATYPE idtype = root->data_type_;

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

/*
** relationmap_[kDataColumnName][kDataTableName] = kRelationSubtype;
** relationmap_[kDataPragmaValue][kDataPragmaKey] = kRelationSubtype;
** relationmap_[kDataTableName][kDataTableName] = kRelationElement;
** relationmap_[kDataColumnName][kDataColumnName] = kRelationElement;
*/
void
Mutator::fix_preprocessing(IR *stmt_root,
                     vector<IR*> &ordered_all_subquery_ir) {
  set<DATATYPE> type_to_fix = {
    kDataColumnName, kDataTableName, kDataPragmaKey,
    kDataPragmaValue, kDataLiteral, kDataRelOption,
    kDataIndexName, kDataAliasName, kDataTableNameFollow,
    kDataColumnNameFollow, kDataStatisticName, kDataSequenceName,
    kDataViewName, kDataForeignTableName, kDataConstraintName, kDataSequenceName, kDataStatisticName, kDataAliasTableName
  };
  vector<IR*> ir_to_fix;
  collect_ir(stmt_root, type_to_fix, ordered_all_subquery_ir);
}

bool Mutator::fix_dependency(IR* cur_stmt_root, const vector<vector<IR*>> cur_stmt_ir_to_fix_vec, bool is_debug_info) {

  if (is_debug_info) {
    cerr << "Fix_dependency: cur_stmt_root: " << cur_stmt_root->to_string() << ", size of cur_stmt_ir_to_fix_vec " << cur_stmt_ir_to_fix_vec.size() << ". \n\n\n";
  }

  /* Used to mark the IRs that are needed to be deep_drop(). However, it is not a good idea
   * to deep_drop in the middle of the fix_dependency() function, some ir_to_fix node might have
   * nested IR strcuture. Use this vector to save all IR that needs deep_drop, and drop them at the end
   * of the function.
   * */
  vector<IR*> ir_to_deep_drop;
  vector<IR*> fixed_ir;
  string cur_ir_str = cur_stmt_root->to_string();

  bool is_replace_table = false, is_replace_column = false;
  for (const vector<IR*>& ir_to_fix_vec : cur_stmt_ir_to_fix_vec) {  // Loop for substmt.

    vector<string> v_with_clause_alias_table_name;

    /* Definition of kDataTableName */
    for (IR* ir_to_fix : ir_to_fix_vec){
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (
        (
          ir_to_fix->data_type_ == kDataTableName ||
          ir_to_fix->data_type_ == kDataForeignTableName
        ) &&
        (ir_to_fix->data_flag_ == kDefine))
      {
        string new_name = gen_id_name();
        ir_to_fix->str_val_ = new_name;
        fixed_ir.push_back(ir_to_fix);

        if (ir_to_fix->data_type_ == kDataForeignTableName) {
          v_create_foreign_table_names_single.push_back(new_name);
        }

        v_create_table_names_single.push_back(new_name);
        if (is_debug_info) {
          cerr << "Dependency: Added to v_table_names: " << new_name << ", in kDataTableName with kDefine or kReplace. \n\n\n";
          for (string& all_used_name : v_table_names) {
            cerr << "Dependency: All saved table used names: " << all_used_name << "\n\n\n";
          }
        }
        is_replace_table = true;
      }
    }

    /* Undefine of kDataTableName */
    for (IR* ir_to_fix : ir_to_fix_vec){
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (
        (
          ir_to_fix->data_type_ == kDataTableName
        ) &&
        ir_to_fix->data_flag_ == kUndefine)
      {
        if (v_table_names.size() > 0 ) {
          string removed_table_name = v_table_names[get_rand_int(v_table_names.size())];
          v_table_names.erase(std::remove(v_table_names.begin(), v_table_names.end(), removed_table_name), v_table_names.end());
          v_table_names_single.erase(std::remove(v_table_names_single.begin(), v_table_names_single.end(), removed_table_name), v_table_names_single.end());
          ir_to_fix->str_val_ = removed_table_name;
          fixed_ir.push_back(ir_to_fix);
          if (is_debug_info) {
            cerr << "Dependency: Removed from v_table_names: " << removed_table_name << ", in kDataTableName with kUndefine \n\n\n";
          }
          if (is_replace_table && v_create_table_names_single.size() != 0) {
            string new_table_name = v_create_table_names_single.front();
            m_tables[new_table_name] = m_tables[removed_table_name];
          }
        } else {
          if (is_debug_info) {
            cerr << "Dependency Error: Failed to find info in v_table_names, in kDataTableName with kUndefine. \n\n\n";
          }
          fixed_ir.push_back(ir_to_fix);
        }
      } else if (
        (
          ir_to_fix->data_type_ == kDataForeignTableName
        ) &&
        ir_to_fix->data_flag_ == kUndefine)
      {
        if (v_foreign_table_name.size() > 0 ) {
          /* Find table name in the foreign table vector, not normal table vec.  */
          string removed_table_name = v_foreign_table_name[get_rand_int(v_foreign_table_name.size())];
          v_foreign_table_name.erase(std::remove(v_foreign_table_name.begin(), v_foreign_table_name.end(), removed_table_name), v_foreign_table_name.end());

          v_table_names.erase(std::remove(v_table_names.begin(), v_table_names.end(), removed_table_name), v_table_names.end());
          v_table_names_single.erase(std::remove(v_table_names_single.begin(), v_table_names_single.end(), removed_table_name), v_table_names_single.end());
          ir_to_fix->str_val_ = removed_table_name;
          fixed_ir.push_back(ir_to_fix);
          if (is_debug_info) {
            cerr << "Dependency: Removed from v_foreign_table_names: " << removed_table_name << ", in kDataForeignTableName with kUndefine \n\n\n";
          }
          if (is_replace_table && v_create_foreign_table_names_single.size() != 0) {
            string new_table_name = v_create_foreign_table_names_single.front();
            m_tables[new_table_name] = m_tables[removed_table_name];
          }

        } else {
          if (is_debug_info) {
            cerr << "Dependency Error: Failed to find info in v_foreign_table_names, in kDataForeignTableName with kUndefine. \n\n\n";
          }
          /* Unreconized, keep original */
          // ir_to_fix->str_val_ = "y";
          fixed_ir.push_back(ir_to_fix);
        }

      }
    }


    /* kUse of kDataTableName */
    for (IR* ir_to_fix : ir_to_fix_vec){
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (ir_to_fix->data_type_ == kDataTableName && ir_to_fix->data_flag_ == kUse) {

        /* If the original SQL is using the system catalogs,
         * gives just 10% chance to fix it.
         * */

        string ori_str = ir_to_fix->get_str_val();
        if (
          find(v_sys_catalogs_name.begin(), v_sys_catalogs_name.end(), ori_str) != v_sys_catalogs_name.end()
          &&
          get_rand_int(10) < 9
        ) {
          continue;
        }

        /* Check whether we are in the PARTITION OF clause, if yes, use the v_table_with_partition_names */
        if (
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kCreateStmt_30) ||
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kCreateStmt_38) ||
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kCreateForeignTableStmt_7) ||
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kCreateForeignTableStmt_11)
        ) {
          if (is_debug_info) {
            cerr << "Dependency: Detected fixing for kUse kTablename in the PARTITION OF clause. \n\n\n";
          }
          if (v_table_with_partition_name.size() > 0) {
            ir_to_fix->set_str_val(vector_rand_ele(v_table_with_partition_name));
            fixed_ir.push_back(ir_to_fix);
            if (is_debug_info) {
              cerr << "Dependency: In kUse of kTableName, use table name with partitioning: " << ir_to_fix->get_str_val() << ". \n\n\n";
            }
            continue;
          } else {
            if (is_debug_info) {
              cerr << "Dependency Error: In kUse of kTableName, cannot find table names with partitioning. \n\n\n";
            }
            /* In this error case, 20% use original */
            if(get_rand_int(5) < 1) {
              fixed_ir.push_back(ir_to_fix);
              continue;
            }
          }
        }

        // /* Give 5% chances, use system catalogs tables */
        // if (get_rand_int(20) < 1) {
        //   ir_to_fix->str_val_ = vector_rand_ele(v_sys_catalogs_name);
        //   if (is_debug_info) {
        //     cerr << "Dependency: In the context of kUsed table, we use system_catalog table with table_name: " << ir_to_fix->str_val_ << ". \n\n\n";
        //   }
        //   continue;
        // }

        if (v_table_names.size() == 0 && v_table_names_single.size() == 0 && v_create_table_names_single.size() == 0) {
          if (is_debug_info) {
            cerr << "Dependency Error: Failed to find info in v_table_names and v_create_table_names_single, in kDataTableName with kUse. \n\n\n";
          }
          fixed_ir.push_back(ir_to_fix);
          continue;
        }
        string used_name = "";
        if (v_table_names.size() != 0) {
          used_name = v_table_names[get_rand_int(v_table_names.size())];
        } else if (v_table_names_single.size() != 0){
          used_name = v_table_names_single[get_rand_int(v_table_names_single.size())];
        } else {
          used_name = v_create_table_names_single[get_rand_int(v_create_table_names_single.size())];
        }
        ir_to_fix->str_val_ = used_name;
        fixed_ir.push_back(ir_to_fix);
        v_table_names_single.push_back(used_name);
        if (is_debug_info) {
          cerr << "Dependency: In the context of kUsed table, we got table_name: " << used_name << ". \n\n\n";
          for (string& all_used_name : v_table_names) {
            cerr << "Dependency: All saved table used names: " << all_used_name << "\n\n\n";
          }
        }

        if (cur_stmt_root->get_ir_type() == kCreateStmt &&
            p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kTableLikeClause)) {

            if (v_create_table_names_single.size() > 0) {
              string newly_create_table_str = v_create_table_names_single.front();
              m_tables[newly_create_table_str] = m_tables[ir_to_fix->get_str_val()];
            }

        }
      }
    }

    /* kDefine of kDataViewName. */
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (ir_to_fix->data_type_ == kDataViewName && ir_to_fix->data_flag_ == kDefine) {
        string new_view_name_str = gen_view_name();
        ir_to_fix->set_str_val(new_view_name_str);
        fixed_ir.push_back(ir_to_fix);

        v_create_table_names_single.push_back(new_view_name_str);
        v_view_name.push_back(new_view_name_str);

        if(is_debug_info) {
          cerr << "Dependency: In kDefine of kDataViewName, generating view name: " << new_view_name_str << "\n\n\n";
        }
      }
    }

    /* kUndefine of kDataViewName. */
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (ir_to_fix->data_type_ == kDataViewName && ir_to_fix->data_flag_ == kUndefine) {
        if (!v_view_name.size()) {
          if (is_debug_info) {
            cerr << "Dependency Error: In kUndefine of kDataViewname, cannot find view name defined before. \n\n\n";
          }
          fixed_ir.push_back(ir_to_fix);
          continue;
        }
        string view_to_rov_str = vector_rand_ele(v_view_name);
        ir_to_fix->set_str_val(view_to_rov_str);
        fixed_ir.push_back(ir_to_fix);

        remove(v_view_name.begin(), v_view_name.end(), view_to_rov_str);
        remove(v_table_names.begin(), v_table_names.end(), view_to_rov_str);
        remove(v_create_table_names_single.begin(), v_create_table_names_single.end(), view_to_rov_str);

        if(is_debug_info) {
          cerr << "Dependency: In kUndefine of kDataViewName, removing view name: " << view_to_rov_str << "\n\n\n";
        }
      }

      /* kUse of kDataViewName */
      if (ir_to_fix->data_type_ == kDataViewName && ir_to_fix->data_flag_ == kUse) {
        if (!v_view_name.size()) {
          if (is_debug_info) {
            cerr << "Dependency Error: In kUndefine of kDataViewname, cannot find view name defined before. \n\n\n";
          }
          continue;
        }
        string view_str = vector_rand_ele(v_view_name);
        ir_to_fix->set_str_val(view_str);
        fixed_ir.push_back(ir_to_fix);
        v_table_names_single.push_back(view_str);

        if(is_debug_info) {
          cerr << "Dependency: In kUse of kDataViewName, using view name: " << view_str << "\n\n\n";
        }
      }
    }

    /* Fix of kAliasTableName.  */
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (ir_to_fix->data_type_ == kDataAliasTableName && ir_to_fix->data_flag_ == kDefine) {
        string new_alias_table_name_str = gen_alias_name();
        ir_to_fix->set_str_val(new_alias_table_name_str);
        fixed_ir.push_back(ir_to_fix);

        if (p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kWithClause)) {
          v_with_clause_alias_table_name.push_back(new_alias_table_name_str);
        } else {
          v_table_names_single.push_back(new_alias_table_name_str);
        }

        if(is_debug_info) {
          cerr << "Dependency: In kDefine of kDataAliasTableName, generating alias table name: " << new_alias_table_name_str << "\n\n\n";
        }
      }
    }

    /* Fix of kAlias name. */
    int alias_idx = 0;
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      /* Assume all kAlias are alias to Table name.  */
      if (ir_to_fix->data_type_ == kDataAliasName) {

        string closest_table_name = "";

        if (
          v_with_clause_alias_table_name.size() != 0
        ) {
          closest_table_name = vector_rand_ele(v_with_clause_alias_table_name);
          if (is_debug_info) {
            cerr << "Dependency: In with clause kAlias Name Defined, find table name: " << closest_table_name << ". \n\n\n" << endl;
          }
        }
        else if (v_table_names_single.size() != 0) {
          if (alias_idx < v_table_names_single.size()) {
            closest_table_name = v_table_names_single[alias_idx];
            alias_idx++;
          } else {
            closest_table_name = v_table_names_single[get_rand_int(v_table_names_single.size())];
          }
          if (is_debug_info) {
            cerr << "Dependency: In kAlias Name Defined, find table name: " << closest_table_name << ". \n\n\n" << endl;
          }
        } else if (v_create_table_names_single.size() != 0) {
          closest_table_name = v_create_table_names_single[0];
          if (is_debug_info) {
            cerr << "Dependency: In kAlias defined, find newly declared table name: " << closest_table_name << ". \n\n\n" << endl;
          }
        } else if (v_table_names.size() != 0) {
          closest_table_name = v_table_names[get_rand_int(v_table_names.size())];
          if (is_debug_info) {
            cerr << "Dependency Error: In defined of kDataAliasName, cannot find v_table_names_single. Thus find from v_table_name instead. Use table name: " << closest_table_name << ". \n\n\n" << endl;
          }
        }

        if (closest_table_name == "" || closest_table_name == "x" || closest_table_name == "y") {
          if (is_debug_info) {
            cerr << "Dependency Error: Cannot find the closest_table_name from the query. Error cloest_table_name is: " << closest_table_name << ". In kAliasName Define. \n\n\n";
          }
          /* Randomly set an alias name to the defined table.
           * And ignore the mapping for the moment
           * */
          string alias_name = gen_alias_name();
          ir_to_fix->str_val_ = alias_name;
          v_alias_names_single.push_back(alias_name);
          fixed_ir.push_back(ir_to_fix);
          continue;
          // return false;
        }

        /* Found the table name that matched to the alias, now generate the alias and save it.  */
        string alias_name = gen_alias_name();
        ir_to_fix->set_str_val(alias_name);
        vector<string>& cur_mapped_alias_vec = m_table2alias_single[closest_table_name];
        cur_mapped_alias_vec.push_back(alias_name);
        v_alias_names_single.push_back(alias_name);
        fixed_ir.push_back(ir_to_fix);

        if (is_debug_info) {
          cerr << "Dependency: In kAlias defined, generates: " << alias_name << " mapping to: " << closest_table_name << ". \n\n\n" << endl;
        }
      }
    }


    /* kDefine and kReplace of kDataColumnName */
    for (IR* ir_to_fix : ir_to_fix_vec){
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      /* Don't fix values inside the kValueClause. That is not permitted by Postgres semantics.
       * Change it to kDataLiteral, and it would be handled by later kDataLiteral logic.
       * */
      if (cur_stmt_root->get_ir_type() == kInsertStmt && p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kValuesClause)) {
        ir_to_fix->set_type(kDataLiteral, kFlagUnknown);
        // fixed_ir.push_back(ir_to_fix);
        continue;
      }

      if (ir_to_fix->data_type_ == kDataColumnName && (ir_to_fix->data_flag_ == kDefine || ir_to_fix->data_flag_ == kReplace)) {
        if (ir_to_fix->data_flag_ == kReplace) {
          is_replace_column = true;
        }
        string new_name = gen_column_name();
        ir_to_fix->str_val_ = new_name;
        fixed_ir.push_back(ir_to_fix);
        string closest_table_name = "";
        /* Attach the newly generated column name to the table. */
        if (v_create_table_names_single.size() > 0) {
          /* We have table name that is newly defined. */
          closest_table_name = v_create_table_names_single[0];
          if (is_debug_info) {
            cerr << "Dependency: For newly defined column name: " << new_name << ", we find v_create_table_names_single: " << closest_table_name << "\n\n\n";
          }
        } else if (v_table_names_single.size() != 0) {
          /* We cannot find the newly defined table name, see whether there are local table name used, this is typical in ALTER statement.  */
          closest_table_name = v_table_names_single[0];
          if (is_debug_info) {
            cerr << "Dependency: For newly defined column name: " << new_name << ", cannot find v_create_table_names_single, is it in a ALTER statement? We find v_table_names_single: " << closest_table_name << "\n\n\n";
          }
        } else if (v_table_names.size() != 0){ 
          /* This is an ERROR. Cannot find the TABLE name to attach to. 
          ** 80% chance, keep original. 
          ** 20% chance, find any declared table and attached to it. */
          if (get_rand_int(5) < 4) {
            /* Keep original */
            continue;
          }
          closest_table_name = v_table_names[get_rand_int(v_table_names.size())];
          if (is_debug_info) {
            cerr << "Dependency ERROR: For newly defined column name: " << new_name << ", ERROR finding matched newly created table names. Used previous declared table name: " << closest_table_name << "\n\n\n";
          }
        }
        if (closest_table_name == "" || closest_table_name == "x" || closest_table_name == "y") {
          if (is_debug_info) {
            cerr << "Dependency Error: Cannot find the closest_table_name from the query. ";
            cerr << "cloest_table_name returns: " << closest_table_name << "In kDataColumnName, kDefine or kReplace. \n\n\n";
          }
          // return false;
          /* Randomly set a name to the defined column.
           * And ignore the mapping for the moment
           * */

          /* Unreconized, keep original */
          // ir_to_fix->str_val_ = gen_column_name();
          continue;
        }
        if (is_debug_info) {
          cerr << "Dependency: For column_name: " << new_name << ", found closest_table_name: " << closest_table_name << ". \n\n\n";
        }
        m_tables[closest_table_name].push_back(new_name);


        /* Next, we save the column type to the mapping */
        if (ir_to_fix->data_flag_ == kDefine) {
          /* For normal tables, we need to save its column type. */
          if (ir_to_fix ->get_parent() ->get_right() && ir_to_fix->get_parent()->get_right()->get_ir_type() == kTypename ) {

            IR* typename_ir = ir_to_fix ->get_parent() ->get_right();
            COLTYPE column_type = typename_ir->typename_ir_get_type();

            m_column2datatype[new_name] = column_type;

          }
          /* For view, we don't have the obvious type information. Currently treat it as unknown types. */
          else {
            m_column2datatype[new_name] = COLTYPE::UNKNOWN_T; // Unknown data type.
          }
          if (is_debug_info) {
            cerr << "Dependency: For newly declared column: " << new_name << ", we map with type: " << m_column2datatype[new_name] << "\n\n\n";
          } 
        } else { // kReplace for type mapping
          /* This is a ALTER replace column statment. Find the previous column name type, map it to the new one. */
          vector<IR*> column_name_ir;
          set<DATATYPE> type_to_search = {kDataColumnName};
          collect_ir(cur_stmt_root, type_to_search, column_name_ir);
          string prev_column_name = column_name_ir[0]->str_val_;
          COLTYPE column_data_type = m_column2datatype[prev_column_name];
          m_column2datatype[new_name] = column_data_type;
          if (is_debug_info) {
            cerr << "Dependency: In the context of kReplace column mapping replace, we map the old column name: " << prev_column_name <<
            "to new column_name: " << new_name << ", mapped type: " << m_column2datatype[new_name] << ". \n\n\n";
          }
        }
        /* Finished mapping algorithm. */

      } else if (ir_to_fix->data_type_ == kDataColumnName && ir_to_fix->data_flag_ == kUndefine) {
        /* Find the table_name in the query first. */
        string closest_table_name = "";
        if (v_table_names_single.size() != 0) {
          closest_table_name = v_table_names_single[0];
          if (is_debug_info) {
            cerr << "Dependency: For removing kDataColumnName: we find v_create_table_names_single: " << closest_table_name << "\n\n\n";
          }
        } 
        if (closest_table_name == "" || closest_table_name == "x" || closest_table_name == "y") {
          if (is_debug_info) {
            cerr << "Dependency Error: Cannot find the closest_table_name from the query. closest_table_name returns: " << closest_table_name << ". In kDataColumnName, kUndefine. \n\n\n";
          }
          /* Unreconized, keep original */
          // return false;
          fixed_ir.push_back(ir_to_fix);
          continue;
        }

        if (is_debug_info) {
          cerr << "Dependency: In kDataColumnName, kUndefine, found closest_table_name: " << closest_table_name << ". \n\n\n";
        }

        vector<string>& column_vec = m_tables[closest_table_name];
        if (column_vec.size() == 0) {
          if (is_debug_info) {
            cerr << "Dependency Error: Cannot find the mapped column_vec for table_name: " << closest_table_name << " \n\n\n";
          }
          /* Not reconized column name. Keep original */
          // ir_to_fix->str_val_ = "y";
          // return false;
          fixed_ir.push_back(ir_to_fix);
          continue;
        }
        string removed_column_name = column_vec[get_rand_int(column_vec.size())];
        column_vec.erase(std::remove(column_vec.begin(), column_vec.end(), removed_column_name), column_vec.end());
        ir_to_fix->str_val_ = removed_column_name;
        fixed_ir.push_back(ir_to_fix);

        if (is_debug_info) {
          cerr << "Dependency: In kDataColumnName, kUndefine, found removed_column_name: " << removed_column_name << ", from closest_table_name: " << closest_table_name << ". \n\n\n"; 
        }
      } 
    } // for (IR* ir_to_fix : ir_to_fix_vec)

    /* kUse of kDataColumnName */
    for (IR* ir_to_fix : ir_to_fix_vec){
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      /* Don't fix values inside the kValueClause. That is not permitted by Postgres semantics.
       * Change it to kDataLiteral, and it would be handled by later kDataLiteral logic.
       * */
      if (cur_stmt_root->get_ir_type() == kInsertStmt && p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kValuesClause)) {
        ir_to_fix->set_type(kDataLiteral, kFlagUnknown);
        // fixed_ir.push_back(ir_to_fix);
        continue;
      }


      if (ir_to_fix->data_type_ == kDataColumnName && ir_to_fix->data_flag_ == kUse) {
        if (is_debug_info) {
          cerr << "Dependency: ori column name: " << ir_to_fix->str_val_ << "\n\n\n";
          cerr << "In the kDataColumnName with kUse, found v_alias_names_single.size: " << v_alias_names_single.size() << "\n\n\n";
        }
        /* If we are seeing system default columns, 75% skip the fixing and reuse the original.  */
        string ori_str = ir_to_fix->get_str_val();
        if (
          find(v_sys_column_name.begin(), v_sys_column_name.end(), ori_str) != v_sys_column_name.end() &&
          get_rand_int(4) >= 1
        ) {
          continue;
        } else if (
          // Do not use alias inside kWithClause
          !p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kWithClause) &&
          v_alias_names_single.size() > 0 &&
          get_rand_int(3) < 2
        ) {
          /* We have defined a new alias for column name! use it with 66% percentage. */
          // cerr << "DEBUG: is in kWithClause: " <<           p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kWithClause) << "\n\n\n";
          ir_to_fix->str_val_ = vector_rand_ele(v_alias_names_single);
          if (is_debug_info) {
            cerr << "Dependency: Using alias inside kUse of kColumnName: " << ir_to_fix->str_val_ << ". \n\n\n";
          }
          continue;
        }
        /* Or, assign with system column in 5% chances */
        else if (get_rand_int(20) < 1){
          ir_to_fix->str_val_ = v_sys_column_name[get_rand_int(v_sys_column_name.size())];
          continue;
        }


        string closest_table_name = "";
        if (v_table_names_single.size() != 0) {
          closest_table_name = v_table_names_single[get_rand_int(v_table_names_single.size())];
          if (is_debug_info) {
            cerr << "Dependency: In kUse of kDataColumnName, find table name: " << closest_table_name << " for column name origin. \n\n\n" << endl;
          }
        } else if (v_create_table_names_single.size() != 0) {
          closest_table_name = v_create_table_names_single[0];
          if (is_debug_info) {
            cerr << "Dependency: In kUse of kDataColumnName, find newly declared table name: " << closest_table_name << " for column name origin. \n\n\n" << endl;
          }
        } else if (v_alias_names_single.size() != 0) {
           ir_to_fix->str_val_ = v_alias_names_single[get_rand_int(v_alias_names_single.size())];
           if (is_debug_info) {
             cerr << "Dependency: In kUse of kDataColumnName, use alias name as the column name. Use alias name: " << ir_to_fix->str_val_ << " for column name. \n\n\n" << endl;
           }
           // Finished assigning column name. continue;
           fixed_ir.push_back(ir_to_fix);
           continue;
        } else if (v_table_names.size() != 0) {

          /* This should be an error. 
          ** 80% chances, keep original. 
          ** 20%, use predefined table name. 
          */
          if (get_rand_int(5) < 4) {
            fixed_ir.push_back(ir_to_fix);
            continue;
          } 

          closest_table_name = v_table_names[get_rand_int(v_table_names.size())];
          if (is_debug_info) {
            cerr << "Dependency Error: In kUse of kDataColumnName, cannot find v_table_names_single. Thus find from v_table_name instead. Use table name: " << closest_table_name << " for column name origin. \n\n\n" << endl;
          }
        }

        if (closest_table_name == "" || closest_table_name == "x" || closest_table_name == "y") {
          if (is_debug_info) {
            cerr << "Dependency Error: Cannot find the closest_table_name from the query. Error cloest_table_name is: " << closest_table_name << ". In kDataColumnName, kUse. \n\n\n";
          }
          if (v_alias_names_single.size() != 0) {
            ir_to_fix->str_val_ = vector_rand_ele(v_alias_names_single);
            if (is_debug_info) {
              cerr << "Dependency: Using alias inside kUse of kColumnName: " << ir_to_fix->str_val_ << ". \n\n\n";
            }
            fixed_ir.push_back(ir_to_fix);
            continue;
          }
          /* Unreconized, keep original */
          // ir_to_fix->str_val_ = "y";
          // return false;
          fixed_ir.push_back(ir_to_fix);
          continue;
        }

        vector<string>& cur_mapped_column_name_vec = m_tables[closest_table_name];
        if (is_debug_info) {
          cerr << "Dependency: In kUse of kDataColunName, use origin table name: " << closest_table_name << ". column size is: " << cur_mapped_column_name_vec.size() << ". \n\n\n";
        }
        if (cur_mapped_column_name_vec.size() > 0) {
          string cur_chosen_column = cur_mapped_column_name_vec[get_rand_int(cur_mapped_column_name_vec.size())];
          ir_to_fix->str_val_ = cur_chosen_column;
          fixed_ir.push_back(ir_to_fix);
          v_column_names_single.push_back(cur_chosen_column);
          if (is_debug_info) {
            cerr << "Dependency: In kDataColumnName, kUse, we choose closest_table_name: " << closest_table_name << " and column_name: " << cur_chosen_column << ". \n\n\n";
          }
        } else {
          /* Unreconized, keep original */
          // ir_to_fix->str_val_ = "y";
          fixed_ir.push_back(ir_to_fix);
          if (is_debug_info) {
            cerr << "Dependency Error: In kDataColumnName, kUse, cannot find mapping from table_name" << closest_table_name << ". \n\n\n";
          }
        }
      }
    }

    /* Fix for kDataTableNameFollow.  */
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }
      if (ir_to_fix->get_data_type() == kDataTableNameFollow) {
        /* This type is used in kDataTableNameFollow . kDataColumnNameFollow. */

        string cur_chosen_table_name = "";
        if (v_table_names_single.size()){
          cur_chosen_table_name = v_table_names_single[get_rand_int(v_table_names_single.size())];
        } else if (v_create_table_names_single.size()) {
          cur_chosen_table_name = v_create_table_names_single[get_rand_int(v_create_table_names_single.size())];
        } else if (v_table_names.size()) {
          if (is_debug_info) {
            cerr << "Dependency Error: In kDataTableNameFollow, cannot find mapping for cur_chosen_table_name in the local stmt, use v_table_names instead\n\n\n";
          }
          cur_chosen_table_name = v_table_names[get_rand_int(v_table_names.size())];
        } else {
          if (is_debug_info) {
            cerr << "Dependency Error: In kDataTableNameFollow, cannot find mapping for cur_chosen_table_name. \n\n\n";
          }
          fixed_ir.push_back(ir_to_fix);
          continue;
        }

        /* Save the chosen table name before change it to alias name.  */
        v_table_name_follow_single.push_back(cur_chosen_table_name);

        /* If the chosen table name has alias, use the alias */
        if (m_table2alias_single[cur_chosen_table_name].size()) {
          cur_chosen_table_name = m_table2alias_single[cur_chosen_table_name][0];
        }

        ir_to_fix->set_str_val(cur_chosen_table_name);
        fixed_ir.push_back(ir_to_fix);

        if (is_debug_info) {
          cerr << "Dependency: In kDataTableNameFollow, choose table name: " << cur_chosen_table_name << ". \n\n\n";
        }

      }
    }

    /* Fix for kDataColumnNameFollow.  */
    int table_follow_idx = 0;
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (ir_to_fix->get_data_type() == kDataColumnNameFollow) {
        /* This type is used in kDataTableNameFollow . kDataColumnNameFollow. */

        if (table_follow_idx < v_table_name_follow_single.size()) {
          string cur_chosen_table_name = v_table_name_follow_single[table_follow_idx];
          vector<string>& v_cur_mapped_column = m_tables[cur_chosen_table_name];
          if ( !v_cur_mapped_column.size() ) {
            if (is_debug_info) {
              cerr << "Dependency Error: In kDataColumnNameFollow, choose table name: " << cur_chosen_table_name << " cannot find mapped column names. \n\n\n";
            }
            fixed_ir.push_back(ir_to_fix);
            continue;
          }

          string cur_chosen_column_name = v_cur_mapped_column[get_rand_int(v_cur_mapped_column.size())];
          ir_to_fix->set_str_val(cur_chosen_column_name);
          fixed_ir.push_back(ir_to_fix);

          if (is_debug_info) {
            cerr << "Dependency: In kDataColumnNameFollow, choose table name: " << cur_chosen_table_name << ", mapped with kDataColumnName:" << cur_chosen_column_name << ". \n\n\n";
          }

        } else {
            if (is_debug_info) {
              cerr << "Dependency Error: In kDataColumnNameFollow, cannot find mapped table_follow names. \n\n\n";
            }
            fixed_ir.push_back(ir_to_fix);
            continue;
        }
      }
    }

    /* Fix of kDataIndex name. */
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }


      if (ir_to_fix->get_data_type() == kDataIndexName) {
        if (ir_to_fix->get_data_flag() == kDefine) {
          string tmp_index_name = gen_index_name();
          ir_to_fix->set_str_val(tmp_index_name);
          fixed_ir.push_back(ir_to_fix);

          /* Find the table used in this stmt. */
          if (v_table_names_single.size() != 0) {
            string tmp_table_name = v_table_names_single[0];
            m_table2index[tmp_table_name].push_back(tmp_index_name);
          }
        }
        else if (ir_to_fix->get_data_flag() == kUndefine) {

          string tmp_index_name = "y";

          /* Find the table used in this stmt. */
          if (v_table_names_single.size() != 0) {
            string tmp_table_name = v_table_names_single[0];
            vector<string>& v_index_name = m_table2index[tmp_table_name];
            if (!v_index_name.size()) continue;
            tmp_index_name = vector_rand_ele(v_index_name);

            vector<string> tmp_v_index_name;
            for (string s: v_index_name) {
              if (s != tmp_index_name) {
                tmp_v_index_name.push_back(s);
              }
            }
            v_index_name = tmp_v_index_name;
          } else {
            for (auto it = m_table2index.begin(); it != m_table2index.end(); it++) {
              vector<string>& v_index_name = it->second;
              if (!v_index_name.size()) continue;
              tmp_index_name = vector_rand_ele(v_index_name);

              vector<string> tmp_v_index_name;
              for (string s: v_index_name) {
                if (s != tmp_index_name) {
                  tmp_v_index_name.push_back(s);
                }
              }
              v_index_name = tmp_v_index_name;
            }
          }
          if (tmp_index_name != "y") {
            ir_to_fix->set_str_val(tmp_index_name);
            fixed_ir.push_back(ir_to_fix);
          }
        }

        else if (ir_to_fix->get_data_flag() == kUse) {

          string tmp_index_name = "y";

          /* Find the table used in this stmt. */
          if (v_table_names_single.size() != 0) {
            string tmp_table_name = v_table_names_single[0];
            vector<string>& v_index_name = m_table2index[tmp_table_name];
            if (!v_index_name.size()) continue;
            tmp_index_name = vector_rand_ele(v_index_name);
          } else {
            for (auto it = m_table2index.begin(); it != m_table2index.end(); it++) {
              vector<string>& v_index_name = it->second;
              if (!v_index_name.size()) continue;
              tmp_index_name = vector_rand_ele(v_index_name);
            }
          }
          if (tmp_index_name != "y") {
            ir_to_fix->set_str_val(tmp_index_name);
            fixed_ir.push_back(ir_to_fix);
          }
        }
      }
    }


    /* Fix the Literal. */
    int cur_literal_idx = -1;
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (ir_to_fix->data_type_ == kDataLiteral) {
        fixed_ir.push_back(ir_to_fix);

        if (is_debug_info) {
          cerr << "Fixing Literals: ori_literals: " << ir_to_fix->get_str_val() << "\n\n\n";
        }

        string ori_str = ir_to_fix->get_str_val();
        if (
          ir_to_fix->get_ir_type() == kStringLiteral &&
          find(common_string_library_.begin(), common_string_library_.end(), ori_str) == common_string_library_.end() &&
          get_rand_int(10) < 5
        ) {
          /* Update unseen string with just 10% chances. (heuristic) */
          common_string_library_.push_back(ori_str);
        }

        /* Mutate the literals in just 1% of chances is enough.
        * For 99% of chances, keep original. 
        * Only for non_select stmts. 
        * For select stmts, 1/5 keep original. 
        */
        bool is_keep_ori = false;
        if (cur_stmt_root->get_ir_type() != kSelectStmt && get_rand_int(100) < 99) {
          is_keep_ori = true;
        } else if (cur_stmt_root->get_ir_type() == kSelectStmt && get_rand_int(60) < 10) {
          is_keep_ori = true;
        }

        if (is_keep_ori) {
          /* Save the already seen literals */
          if (ir_to_fix->get_ir_type() == kIntLiteral) {
            string ori_str = ir_to_fix->get_str_val();
            try {
              int ori_int = std::stoi(ori_str);
              v_int_literals.push_back(ori_int);

              if (is_debug_info) {
                cerr << "Dependency: Saved int literals: " << ori_str << "\n\n\n";
              }
            } catch (...) {
              continue;
            }
          } else if (ir_to_fix->get_ir_type() == kFloatLiteral) {
            string ori_str = ir_to_fix->get_str_val();
            try {
              double ori_float = std::stod(ori_str);
              v_float_literals.push_back(ori_float);

              if (is_debug_info) {
                cerr << "Dependency: Saved float literals: " << ori_str << "\n\n\n";
              }
            } catch (...) {
              continue;
            }
          } else if (ir_to_fix->get_ir_type() == kStringLiteral) {
            v_string_literals.push_back(ir_to_fix->get_str_val());
            if (is_debug_info) {
              cerr << "Dependency: Saved string literals: " << ir_to_fix->get_str_val() << "\n\n\n";
            }

          }
          /* Do not save boolean. Not necessary.  */
          continue;
        }

        if (
          cur_stmt_root->get_ir_type() == kVariableSetStmt ||
          cur_stmt_root->get_ir_type() == kVariableResetStmt ||
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kGenericSet) ||
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kReloptionElem) ||
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kDefElem) ||
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kReloptions)
        ) {
          /* Do not fix literals used to define reloptions or Postgres configurations.  */
          continue;
        }

        cur_literal_idx++;
        COLTYPE column_data_type = COLTYPE::UNKNOWN_T;
        if (v_column_names_single.size() > cur_literal_idx) {
          /* For cases like INSERT INTO v0 (c1, c2) VALUES (1, 2); */
          string cur_column_name = v_column_names_single[cur_literal_idx];
          column_data_type = m_column2datatype[cur_column_name];
          if (is_debug_info) {
            cerr << "Dependency: For fixing literal idx: " << cur_literal_idx << ", we found column name: " << cur_column_name << ", thus choose column_data_type: " << column_data_type << ". \n\n\n";
          }
        } else if (v_table_names_single.size() != 0 && m_tables[v_table_names_single[0]].size() > cur_literal_idx) {
          /* For cases like INSERT INTO v0 VALUES (1, 2); */
          string cur_column_name = m_tables[v_table_names_single[0]][cur_literal_idx];
          column_data_type = m_column2datatype[cur_column_name];
          if (is_debug_info) {
            cerr << "Dependency: For fixing literal idx: " << cur_literal_idx << ", no column info found, but found table_name: " << v_table_names_single[0] << ", we choose column_data_type: " << column_data_type << ". \n\n\n";
          }
        } else {
          column_data_type = COLTYPE::UNKNOWN_T;
          if (is_debug_info) {
            cerr << "Dependency Error: For fixing literal idx: " << cur_literal_idx << ". Cannot find any table or column name that help identify the literal type. Randomly choose now. \n\n\n";
          }
        }

        /* For non-select, 95% chances, choose the original type. 
         * For select, 1/3 chances, keep original type.  
        */
        is_keep_ori = false;
        if (cur_stmt_root->get_ir_type() != kSelectStmt && get_rand_int(20) < 19) {
          is_keep_ori = true;
        } else if (cur_stmt_root->get_ir_type() == kSelectStmt && get_rand_int(50) < 10) {
          is_keep_ori = true;
        }

        if (is_keep_ori) {
          if (ir_to_fix->get_ir_type() == kIntLiteral) {
            column_data_type = COLTYPE::INT_T;
          }
          else if (ir_to_fix->get_ir_type() == kFloatLiteral) {
            column_data_type = COLTYPE::FLOAT_T;
          }
          else if (ir_to_fix->get_ir_type() == kBoolLiteral) {
            column_data_type = COLTYPE::BOOLEAN_T;
          }
          else if (ir_to_fix->get_ir_type() == kStringLiteral) {
            column_data_type = COLTYPE::STRING_T;
          }

          if (is_debug_info) {
            cerr << "Dependency: For fixing literal idx: " << cur_literal_idx << ", str_val_: " << ir_to_fix->str_val_ << " choose to use the original type for the literal: " << column_data_type << "\n\n\n";
          }
        }

        /* If it is used for defining length of column or text, use kIntLiteral */
        if (
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kBitWithLength) ||
          p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kCharacterWithLength)
        ) {
          column_data_type = COLTYPE::INT_T;
        }


        if (column_data_type == COLTYPE::UNKNOWN_T) {
          // Randomly choose Numerical, Character or Boolean.
          int rand_int = get_rand_int(4);
          switch (rand_int) {
            case 0:
              column_data_type = COLTYPE::INT_T;
              break;
            case 1:
              column_data_type = COLTYPE::FLOAT_T;
              break;
            case 2:
              column_data_type = COLTYPE::BOOLEAN_T;
              break;
            case 3:
              column_data_type = COLTYPE::STRING_T;
              break;
          }
        }

        /* INT */
        if (column_data_type == COLTYPE::INT_T){

          /* 'Size of' values, do not use too big values.  */
          if (
            p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kBitWithLength) ||
            p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kCharacterWithLength)
          ) {
            ir_to_fix->int_val_ = (get_rand_int(100));
            if (ir_to_fix->int_val_ < 0) ir_to_fix->int_val_ = - ir_to_fix->int_val_;
            ir_to_fix->str_val_ = to_string(ir_to_fix->int_val_);

            /* Don't save it to v_int_literals, because they are not data literals. */
            // v_int_literals.push_back(ir_to_fix->int_val_);
            // if (is_debug_info) {
            //   cerr << "Dependency: Saved int literals: " << ir_to_fix->int_val_ << "\n\n\n";
            // }

            continue;
          }

          /* In 90% chances, use the already seen int literals. */
          if (v_int_literals.size() > 0 && get_rand_int(10) < 9 ) {
            ir_to_fix->int_val_ = vector_rand_ele(v_int_literals);
            ir_to_fix->str_val_ = std::to_string(ir_to_fix->int_val_);
            if (is_debug_info) {
              cerr << "Dependency: Fixing int literal with previously seen int literals: " << ir_to_fix->str_val_ << "\n\n\n";
            }
            continue;
          }

          /* Preferred to choose a same range number with 4/5 chances */
          if (get_rand_int(5) < 4) {
            string ori_str = ir_to_fix->get_str_val();
            int ori_int = 0;
            try {
              ori_int = std::stoi(ori_str);
            } catch (...) {
              ori_int = -1;
            }
            if (
              ori_int >= 0 &&
              ori_int <= 7 &&
              get_rand_int(5) < 4
            ) {
              int tmp = get_rand_int(8);
              ir_to_fix->str_val_ = to_string(tmp);

              v_int_literals.push_back(tmp);
              if (is_debug_info) {
                cerr << "Dependency: Saved int literals: " << tmp << "\n\n\n";
              }

              continue;
            }

            if (ori_int < -10000) {
              if (get_rand_int(2) < 1) {
                int new_int = get_rand_int(INT_MIN, -10000);
                ir_to_fix->int_val_ = new_int;
                ir_to_fix->str_val_ = to_string(new_int);

                v_int_literals.push_back(new_int);
                if (is_debug_info) {
                  cerr << "Dependency: Saved int literals: " << new_int << "\n\n\n";
                }

                continue;
              } else {
                int new_int = get_rand_int(-10000, 10000);
                ir_to_fix->int_val_ = new_int;
                ir_to_fix->str_val_ = to_string(new_int);

                v_int_literals.push_back(new_int);
                if (is_debug_info) {
                  cerr << "Dependency: Saved int literals: " << new_int << "\n\n\n";
                }

                continue;
              }
            }
            else if (ori_int < -10) {
              int new_int = get_rand_int(-10000, -10);
              ir_to_fix->int_val_ = new_int;
              ir_to_fix->str_val_ = to_string(new_int);

              v_int_literals.push_back(new_int);
              if (is_debug_info) {
                cerr << "Dependency: Saved int literals: " << new_int << "\n\n\n";
              }

              continue;
            } else if (ori_int < 0) {
              int new_int = get_rand_int(-10, 0);
              ir_to_fix->int_val_ = new_int;
              ir_to_fix->str_val_ = to_string(new_int);

              v_int_literals.push_back(new_int);
              if (is_debug_info) {
                cerr << "Dependency: Saved int literals: " << new_int << "\n\n\n";
              }

              continue;
            } else if (ori_int < 10) {
              int new_int = get_rand_int(0, 10);
              ir_to_fix->int_val_ = new_int;
              ir_to_fix->str_val_ = to_string(new_int);

              v_int_literals.push_back(new_int);
              if (is_debug_info) {
                cerr << "Dependency: Saved int literals: " << new_int << "\n\n\n";
              }

              continue;
            } else if (ori_int < 10000) {
              int new_int = get_rand_int(0, 10);
              ir_to_fix->int_val_ = new_int;
              ir_to_fix->str_val_ = to_string(new_int);

              v_int_literals.push_back(new_int);
              if (is_debug_info) {
                cerr << "Dependency: Saved int literals: " << new_int << "\n\n\n";
              }

              continue;
            } else {
              if (get_rand_int(2) < 1) {
                int new_int = get_rand_int(10000, INT_MAX);
                ir_to_fix->int_val_ = new_int;
                ir_to_fix->str_val_ = to_string(new_int);

                v_int_literals.push_back(new_int);
                if (is_debug_info) {
                  cerr << "Dependency: Saved int literals: " << new_int << "\n\n\n";
                }

                continue;
              } else {
                int new_int = get_rand_int(-10000, 10000);
                ir_to_fix->int_val_ = new_int;
                ir_to_fix->str_val_ = to_string(new_int);

                v_int_literals.push_back(new_int);
                if (is_debug_info) {
                  cerr << "Dependency: Saved int literals: " << new_int << "\n\n\n";
                }

                continue;
              }
            }
          }

          /* 4/5 chances, use value_library, 1/2, use rand_int up to INT_MAX */
          if (get_rand_int(5) < 4 && value_library_.size()) {
            if (value_library_.size() == 0) {
              FATAL("Error: value_library_ is not being init properly. \n");
            }
            ir_to_fix->int_val_ = vector_rand_ele(value_library_);
            ir_to_fix->str_val_ = to_string(ir_to_fix->int_val_);

            v_int_literals.push_back(ir_to_fix->int_val_);
            if (is_debug_info) {
              cerr << "Dependency: Saved int literals: " << ir_to_fix->int_val_ << "\n\n\n";
            }

            continue;
          } else {
            ir_to_fix->int_val_ = get_rand_int(INT_MAX);
            ir_to_fix->str_val_ = to_string(ir_to_fix->int_val_);

            v_int_literals.push_back(ir_to_fix->int_val_);
            if (is_debug_info) {
              cerr << "Dependency: Saved int literals: " << ir_to_fix->int_val_ << "\n\n\n";
            }

            continue;
          }

          /* Randomly use string format of the int */
          // if ( get_rand_int(10) < 3 && ir_to_fix->str_val_.find("'") == string::npos) {
          //   ir_to_fix->str_val_ = "'" + ir_to_fix->str_val_ + "'";
          // }

          ir_to_fix->type_ = kIntLiteral;
        }

        /* FLOAT */
        else if (column_data_type == COLTYPE::FLOAT_T) {  // FLOAT

          /* In 90% chances, use the already seen float literals. */
          if (v_float_literals.size() > 0 && get_rand_int(10) < 9 ) {
            ir_to_fix->float_val_ = vector_rand_ele(v_float_literals);
            ir_to_fix->str_val_ = std::to_string(ir_to_fix->float_val_);
            if (is_debug_info) {
              cerr << "Dependency: Fixing float literal with previously seen float literals: " << ir_to_fix->str_val_ << "\n\n\n";
            }

            ir_to_fix->type_ = kFloatLiteral;
            continue;
          }


          if (get_rand_int(100) < 95) {
            /* Give more possibility to mutate on the same flot range */
            string ori_str = ir_to_fix->get_str_val();
            double ori_float = 0;
            try {
              ori_float = std::stoi(ori_str);
            } catch (...) {
              /* Mutate based on random generation */
              ir_to_fix->float_val_ = (double)(get_rand_double(DBL_MAX));
              ir_to_fix->str_val_ = to_string(ir_to_fix->float_val_);
              ir_to_fix->type_ = kFloatLiteral;

              v_float_literals.push_back(ir_to_fix->float_val_);
              if (is_debug_info) {
                cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
              }

              ir_to_fix->type_ = kFloatLiteral;
              continue;
            }

            if (ori_float < -10000.0) {
              if (get_rand_int(2) < 1) {
                double new_float = get_rand_double(-DBL_MIN, -10000.0);
                ir_to_fix->float_val_ = new_float;
                ir_to_fix->str_val_ = to_string(new_float);

                v_float_literals.push_back(ir_to_fix->float_val_);
                if (is_debug_info) {
                  cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
                }

                ir_to_fix->type_ = kFloatLiteral;
                continue;
              } else {
                double new_float = get_rand_double(-10000.0, 10000.0);
                ir_to_fix->float_val_ = new_float;
                ir_to_fix->str_val_ = to_string(new_float);

                v_float_literals.push_back(ir_to_fix->float_val_);
                if (is_debug_info) {
                  cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
                }

                ir_to_fix->type_ = kFloatLiteral;
                continue;
              }
            }
            else if (ori_float < -10.0) {
              double new_float = get_rand_double(-10000.0, -10.0);
              ir_to_fix->float_val_ = new_float;
              ir_to_fix->str_val_ = to_string(new_float);

              v_float_literals.push_back(ir_to_fix->float_val_);
              if (is_debug_info) {
                cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
              }

              ir_to_fix->type_ = kFloatLiteral;
              continue;
            } else if (ori_float < 0.0) {
              double new_float = get_rand_double(-10.0, 0.0);
              ir_to_fix->float_val_ = new_float;
              ir_to_fix->str_val_ = to_string(new_float);

              v_float_literals.push_back(ir_to_fix->float_val_);
              if (is_debug_info) {
                cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
              }

              ir_to_fix->type_ = kFloatLiteral;
              continue;
            } else if (ori_float < 10.0) {
              double new_float = get_rand_double(0.0, 10.0);
              ir_to_fix->float_val_ = new_float;
              ir_to_fix->str_val_ = to_string(new_float);

              v_float_literals.push_back(ir_to_fix->float_val_);
              if (is_debug_info) {
                cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
              }

              ir_to_fix->type_ = kFloatLiteral;
              continue;
            } else if (ori_float < 10000.0) {
              double new_float = get_rand_double(10.0, 10000.0);
              ir_to_fix->float_val_ = new_float;
              ir_to_fix->str_val_ = to_string(new_float);

              v_float_literals.push_back(ir_to_fix->float_val_);
              if (is_debug_info) {
                cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
              }

              ir_to_fix->type_ = kFloatLiteral;
              continue;
            } else {
              if (get_rand_int(2) < 1) {
                double new_float = get_rand_double(10000.0, DBL_MAX);
                ir_to_fix->float_val_ = new_float;
                ir_to_fix->str_val_ = to_string(new_float);

                v_float_literals.push_back(ir_to_fix->float_val_);
                if (is_debug_info) {
                  cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
                }

                ir_to_fix->type_ = kFloatLiteral;
                continue;
              } else {
                double new_float = get_rand_double(-10000.0, 10000.0);
                ir_to_fix->float_val_ = new_float;
                ir_to_fix->str_val_ = to_string(new_float);

                v_float_literals.push_back(ir_to_fix->float_val_);
                if (is_debug_info) {
                  cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
                }

                ir_to_fix->type_ = kFloatLiteral;
                continue;
              }
            }
          }
          else {
            /* Mutate based on random generation */
            ir_to_fix->float_val_ = (double)(get_rand_double(DBL_MAX));
            ir_to_fix->str_val_ = to_string(ir_to_fix->float_val_);

            v_float_literals.push_back(ir_to_fix->float_val_);
            if (is_debug_info) {
              cerr << "Dependency: Saved float literals: " << ir_to_fix->float_val_ << "\n\n\n";
            }

            ir_to_fix->type_ = kFloatLiteral;
            continue;

          }

        }

        /* BOOLEAN */
        else if (column_data_type == COLTYPE::BOOLEAN_T){
          if (get_rand_int(100) < 50){
            ir_to_fix->str_val_ = "TRUE";
          } else {
            ir_to_fix->str_val_ = "FALSE";
          }

          ir_to_fix->type_ = kBoolLiteral;
        }

        /* STRING */
        /* STRING could represent too many types: inet, datetime, or even regular expressions.
         * 
         */
        else {

          /* In 90% chances, use the already seen string literals. */
          if (v_string_literals.size() > 0 && get_rand_int(10) < 9 ) {
            ir_to_fix->str_val_ = vector_rand_ele(v_string_literals);
            if (is_debug_info) {
              cerr << "Dependency: Fixing string literal with previously seen string literals: " << ir_to_fix->str_val_ << "\n\n\n";
            }
            continue;
          }


          ir_to_fix->str_val_ = get_a_string();

          v_string_literals.push_back(ir_to_fix->str_val_);
          if (is_debug_info) {
            cerr << "Dependency: Fixing string literal with: " << ir_to_fix->str_val_ << "\n\n\n";
          }

          ir_to_fix->type_ = kStringLiteral;
        }
      }
    }  /* for (IR* ir_to_fix : ir_to_fix_vec) */

    /* Fix for reloptions. (Related options. ) and function names.  */
    for (IR* ir_to_fix : ir_to_fix_vec) {

      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (ir_to_fix->get_data_type() == kDataRelOption) {
        fixed_ir.push_back(ir_to_fix);

        /* See if we have seen this reloption before, if not, save it.  */
        string ori_str = ir_to_fix->to_string();
        if (
          std::find(v_saved_reloption_str.begin(), v_saved_reloption_str.end(), ori_str) == v_saved_reloption_str.end()
        ) {
          if (is_debug_info) {
            cerr << "Dependency: Saving unseen reloption string: " << ori_str << ". \n\n\n";
          }
          v_saved_reloption_str.push_back(ori_str);
        }

        // Use original reloptions, in 99% of chances.
        if (get_rand_int(100) < 99) {
          continue;
        }

        if (get_rand_int(5) < 4 && v_saved_reloption_str.size() > 0) {
          /* If 4/5 chances, rerun previously seen reloptions */
          IR* new_reloption_ir = new IR(kReloptionElem, vector_rand_ele(v_saved_reloption_str));
          cur_stmt_root->swap_node(ir_to_fix, new_reloption_ir);
          ir_to_deep_drop.push_back(ir_to_fix);
          if (is_debug_info) {
            cerr << "Dependency: In reloption, using previously seen reloption: " << new_reloption_ir->get_str_val() << ". \n\n\n";
          }
          continue;
        }

        if(is_debug_info) {
          cerr << "Dependency: Fixing kDataRelOption: " << get_string_by_ir_type(ir_to_fix->get_ir_type()) << ", to_string(): " << ir_to_fix->to_string() << " getting rel_option_type: " << ir_to_fix->get_rel_option_type() << "\n\n\n";
        }

        pair<string, string> reloption_choice;

        bool is_reset = RelOptionGenerator::get_rel_option_pair(ir_to_fix->get_rel_option_type(), reloption_choice);

        if (!is_reset) {
          IR* new_reloption_label = new IR(kReloptionElem, reloption_choice.first);
          IR* new_reloption_args = new IR(kReloptionElem, reloption_choice.second);

          IR* new_reloption_ir = new IR(kReloptionElem, OP3("", "=", ""), new_reloption_label, new_reloption_args);

          /* Replace the old reloption ir to the new one. But only deep_drop it at the end of the fix_dependency.  */
          cur_stmt_root->swap_node(ir_to_fix, new_reloption_ir);
          /* If nested reloption_elem happens, this will crash the program.
          * But I don't think that is a possible case in practice.
          * */
          ir_to_deep_drop.push_back(ir_to_fix);
        } else {
          IR* new_reloption_label = new IR(kReloptionElem, reloption_choice.first);
          IR* new_reloption_ir = new IR(kReloptionElem, OP3("", "", ""), new_reloption_label);

          /* Replace the old reloption ir to the new one. But only deep_drop it at the end of the fix_dependency.  */
          cur_stmt_root->swap_node(ir_to_fix, new_reloption_ir);
          /* If nested reloption_elem happens, this will crash the program.
          * But I don't think that is a possible case in practice.
          * */
          ir_to_deep_drop.push_back(ir_to_fix);
        }

      }

      /* Dont' fix for functions for now.  */
      // /* Fixing for functions.  */
      // if (ir_to_fix->get_data_type() == kDataFunctionName) {
      //   if (ir_to_fix->get_data_flag() == kNoModi) {
      //     continue;
      //   }

      //   string cur_func_str = ir_to_fix->get_str_val();

      //   for (string aggr_func : v_aggregate_func) {
      //     if (findStringIn(cur_func_str, aggr_func) || cur_func_str == "x") {
      //       /* This is a aggregate function. Randomly change it to another functions.  */
      //       ir_to_fix->set_str_val(v_aggregate_func[get_rand_int(v_aggregate_func.size())]);
      //       break;
      //     }
      //   }
      // }
    }

    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (std::find(fixed_ir.begin(), fixed_ir.end(), ir_to_fix) != fixed_ir.end()) {
        continue;
      }

      if (ir_to_fix->get_data_type() == kDataStatisticName) {
        if (ir_to_fix->get_data_flag() == kDefine) {
          string cur_chosen_name = gen_statistic_name();
          ir_to_fix->set_str_val(cur_chosen_name);
          fixed_ir.push_back(ir_to_fix);
          v_statistics_name.push_back(cur_chosen_name);
        }

        else if (ir_to_fix->get_data_flag() == kUndefine) {
          if (!v_statistics_name.size()) continue;
          string cur_chosen_name = vector_rand_ele(v_statistics_name);
          ir_to_fix->set_str_val(cur_chosen_name);
          fixed_ir.push_back(ir_to_fix);

          /* remove the statistic name from the vector */
          vector<string> v_tmp;
          for (string& s : v_statistics_name) {
            if (s != cur_chosen_name) {
              v_tmp.push_back(s);
            }
          }
          v_statistics_name = v_tmp;
        }

        else if (ir_to_fix->get_data_flag() == kUse) {
          if (!v_statistics_name.size()) continue;
          string cur_chosen_name = vector_rand_ele(v_statistics_name);
          ir_to_fix->set_str_val(cur_chosen_name);
          fixed_ir.push_back(ir_to_fix);
        }
      }

      /* Fix for kDataSequenceName */
      if (ir_to_fix->get_data_type() == kDataSequenceName) {
        fixed_ir.push_back(ir_to_fix);
        if (ir_to_fix->get_data_flag() == kDefine) {
          // string cur_chosen_name = gen_sequence_name();
          // ir_to_fix->set_str_val(cur_chosen_name);

          /* Yu: Do not fix for sequence name for now */
          string cur_chosen_name = ir_to_fix->get_str_val();
          v_sequence_name.push_back(cur_chosen_name);
        }

        else if (ir_to_fix->get_data_flag() == kUndefine) {
          if (!v_sequence_name.size()) continue;
          string cur_chosen_name = vector_rand_ele(v_sequence_name);
          ir_to_fix->set_str_val(cur_chosen_name);

          /* remove the statistic name from the vector */
          vector<string> v_tmp;
          for (string& s : v_sequence_name) {
            if (s != cur_chosen_name) {
              v_tmp.push_back(s);
            }
          }
          v_sequence_name = v_tmp;
        }

        else if (ir_to_fix->get_data_flag() == kUse) {
          if (!v_sequence_name.size()) continue;
          string cur_chosen_name = vector_rand_ele(v_sequence_name);
          ir_to_fix->set_str_val(cur_chosen_name);
        }
      }

      /* Fix for kDataConstraintName */
      if (ir_to_fix->get_data_type() == kDataConstraintName) {
        fixed_ir.push_back(ir_to_fix);
        if (ir_to_fix->get_data_flag() == kDefine) {
          // string cur_chosen_name = gen_sequence_name();
          // ir_to_fix->set_str_val(cur_chosen_name);

          /* Yu: Do not fix for constraint name for now */
          string cur_chosen_name = ir_to_fix->get_str_val();
          v_constraint_name.push_back(cur_chosen_name);
        }

        else if (ir_to_fix->get_data_flag() == kUndefine) {
          if (!v_constraint_name.size()) continue;
          string cur_chosen_name = vector_rand_ele(v_constraint_name);
          ir_to_fix->set_str_val(cur_chosen_name);

          /* remove the statistic name from the vector */
          vector<string> v_tmp;
          for (string& s : v_constraint_name) {
            if (s != cur_chosen_name) {
              v_tmp.push_back(s);
            }
          }
          v_constraint_name = v_tmp;
        }

        else if (ir_to_fix->get_data_flag() == kUse) {
          if (!v_constraint_name.size()) continue;
          string cur_chosen_name = vector_rand_ele(v_constraint_name);
          ir_to_fix->set_str_val(cur_chosen_name);
        }
      }

    }


  }  /* for (const vector<IR*>& ir_to_fix_vec : cur_stmt_ir_to_fix_vec) */


  /* Check whether the table is in the context of TABLE PARTITIONING */
  bool is_table_par = false;
  // First, check kOptPartitionClause
  vector<IR*> v_opt_par_clause = p_oracle->ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt_root, kOptPartitionClause, false);
  if (v_opt_par_clause.size() > 0) {
    for (IR* opt_par_clause : v_opt_par_clause) {
      if (opt_par_clause->get_prefix() == "PARTITION BY") {
        is_table_par = true;
        break;
      }
    }
  }
  v_opt_par_clause.clear();

  // Next, check kPartitionSpec
  vector<IR*> v_par_spec = p_oracle->ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt_root, kPartitionSpec, false);
  if (v_par_spec.size() > 0) {
    is_table_par = true;
  }

  if (is_table_par && v_create_table_names_single.size() > 0) {
    string new_par_table_name = v_create_table_names_single.front();
    v_table_with_partition_name.push_back(new_par_table_name);
  }



  /* For the newly declared v_table_names_single, save all these newly declared statement to the global v_table_names. */
  v_table_names.insert(v_table_names.end(), v_create_table_names_single.begin(), v_create_table_names_single.end());
  v_foreign_table_name.insert(v_foreign_table_name.end(), v_create_foreign_table_names_single.begin(), v_create_foreign_table_names_single.end());
  
  /* Reiterate the substmt.
  ** Added missing dependency information that is missing before. 
  */
  for (const vector<IR*>& ir_to_fix_vec : cur_stmt_ir_to_fix_vec) {


    /* Added mapping for Inheritance.  */
    for (IR* ir_to_fix : ir_to_fix_vec) {
      if (
        ir_to_fix->data_type_ == kDataTableName &&
        cur_stmt_root->get_ir_type() == kCreateStmt &&
        p_oracle->ir_wrapper.is_ir_in(ir_to_fix, kOptInherit) &&
        ir_to_fix->data_flag_ == kUse
        ) {
        if (v_create_table_names_single.size() > 0) {
          string cur_new_table_name_str = v_create_table_names_single.front();
          string inherit_table_name_str = ir_to_fix->get_str_val();

          vector<string>& inherit_m_tables = m_tables[inherit_table_name_str];

          for (string col_name : inherit_m_tables) {
            m_tables[cur_new_table_name_str].push_back(col_name);
          }
        }
      }
    }

    for (IR* ir_to_fix : ir_to_fix_vec){
      if (ir_to_fix->data_type_ != kDataTableName && ir_to_fix->data_type_ != kDataViewName) {
        continue;
      }

      /* Add missing mapping for CREATE VIEW stmt.  */
      /* Check whether we are in the CreateViewStatement. If yes, save the column mapping. */
      IR* cur_ir = ir_to_fix;
      bool is_in_create_view = false;
      while (cur_ir != nullptr) {
        if (cur_ir->type_ == kStmt) {
          break;
        }
        if (cur_ir->type_ == kCreateViewStmt || cur_ir->type_ == kViewStmt) {
          is_in_create_view = true;
          if (is_debug_info) {
            cerr << "Dependency: We are in a kCreateViewStmt. \n\n\n";
          }
          break;
        }
        /* Yu: Dirty fix for CREATE TABLE PARTITION OF or CREATE TABLE ... AS SELECT ... stmt. */
        if (
          cur_ir_str.find("PARTITION OF") != string::npos &&
          cur_ir_str.find("CREATE") != string::npos
        ) {
          is_in_create_view = true;
          if (is_debug_info) {
            cerr << "Dependency: We are in a CREATE TABLE PARTITION OF. Hack, treat it CREATE VIEW.  \n\n\n";
          }
          break;
        }
        if (
          cur_ir_str.find("CREATE TABLE") != string::npos &&
          cur_ir_str.find("AS SELECT") != string::npos
        ) {
          is_in_create_view = true;
          if (is_debug_info) {
            cerr << "Dependency: We are in a CREATE TABLE AS SELECT. Hack, treat it CREATE VIEW.  \n\n\n";
          }
          break;
        }
        
        cur_ir = cur_ir->parent_;
      }
      if (is_in_create_view) {
        /* Added column mapping for CREATE TABLE/VIEW... v0 AS SELECT... statement.
        */
        if (is_debug_info) {
          cerr << "Dependency: In CREATE VIEW statement, getting cur_stmt_ir_to_fix_vec.size: " << cur_stmt_ir_to_fix_vec.size() << ". \n\n\n";
        }
        // id_column_name should be in the subqueries and already been resolved in the previous loop. 
        vector<IR*> all_mentioned_column_vec;
        set<DATATYPE> column_type_set = {kDataColumnName};
        collect_ir(cur_stmt_root, column_type_set, all_mentioned_column_vec);

        /* Fix: also, add alias name defined here to the table */
        vector<IR*> all_mentioned_alias_vec;
        set<DATATYPE> alias_type_set = {kDataAliasName};
        collect_ir(cur_stmt_root, alias_type_set, all_mentioned_alias_vec);

        all_mentioned_column_vec.insert(all_mentioned_column_vec.end(), all_mentioned_alias_vec.begin(), all_mentioned_alias_vec.end());
        all_mentioned_alias_vec.clear();

        if (is_debug_info) {
          cerr << "Dependency: When building extra mapping for CREATE VIEW AS, collected kDataColumnName.size: " << all_mentioned_column_vec.size() << ". \n\n\n";
        }
        
        for (const IR* const cur_men_column_ir : all_mentioned_column_vec) {
          string cur_men_column_str = cur_men_column_ir->str_val_;
          if (findStringIn(cur_men_column_str, ".")) {
            cur_men_column_str = string_splitter(cur_men_column_str, '.')[1];
          }
          vector<string>& cur_m_table  = m_tables[ir_to_fix->str_val_];
          if (std::find(cur_m_table.begin(), cur_m_table.end(), cur_men_column_str) == cur_m_table.end()) {
            m_tables[ir_to_fix->str_val_].push_back(cur_men_column_str);
            if (is_debug_info) {
              cerr << "Dependency: Adding mappings: For table/view: " << ir_to_fix->str_val_ << ", map with column: " << cur_men_column_str << ". \n\n\n";
            }
          }
        }

        /* For CREATE VIEW x AS SELECT * FROM v0; */
        if (all_mentioned_column_vec.size() == 0) {
          if (is_debug_info) {
            cerr << "Dependency: For mapping CREATE VIEW, cannot find column name in the current subqueries. Thus, see if we can find table names, and map from there. \n\n\n";
          }
          vector<IR*> all_mentioned_table_vec, all_mentioned_table_kUsed_vec;
          set<DATATYPE> table_type_set = {kDataTableName};
          collect_ir(cur_stmt_root, table_type_set, all_mentioned_table_vec);
          for (IR* mentioned_table_ir : all_mentioned_table_vec ) {
            if (mentioned_table_ir->data_flag_ == kUse) {
              all_mentioned_table_kUsed_vec.push_back(mentioned_table_ir);
              if (is_debug_info) {
                cerr << "Dependency: For mapping CREATE VIEW, getting mentioned table name: " << mentioned_table_ir->str_val_ << ". \n\n\n";
              }
            }
          }
          for (IR* cur_men_tablename_ir : all_mentioned_table_kUsed_vec) {
            string cur_men_tablename_str = cur_men_tablename_ir->str_val_;
            const vector<string>& cur_men_column_vec = m_tables[cur_men_tablename_str];
            for (const string& cur_men_column_str : cur_men_column_vec) {
              vector<string>& cur_m_table  = m_tables[ir_to_fix->str_val_];
              if (std::find(cur_m_table.begin(), cur_m_table.end(), cur_men_column_str) == cur_m_table.end()) {
                m_tables[ir_to_fix->str_val_].push_back(cur_men_column_str);
                if (is_debug_info) {
                  cerr << "Dependency: Adding mappings: For table/view: " << ir_to_fix->str_val_ << ", map with column: " << cur_men_column_str << ". \n\n\n";
                }
              }
            }
          } // for (IR* cur_men_tablename_ir : all_mentioned_table_kUsed_vec)
        } // if (all_mentioned_column_vec.size() == 0)

        /* The extra mapping only need to be done once. Once reach this point, break the loop. */
        break;
      } // if (is_in_create_view)

    } // for (IR* ir_to_fix : ir_to_fix_vec)
  }

  for (IR* ir_to_drop : ir_to_deep_drop) {
    if (ir_to_drop) {
      ir_to_drop->deep_drop();
    }
  }

  return true;
}

// bool Mutator::fill_stmt_graph_one(map<IR *, vector<IR *>> &graph, IR *ir) {
//   if (graph.find(ir) == graph.end())
//     return true;

//   bool res = true;
//   auto type = ir->data_type_;
//   auto &vec = graph[ir];

//   if (!vec.empty()) {
//     for (auto d : vec) {
//       res = res & fill_one_pair(ir, d);
//       res = res & fill_stmt_graph_one(graph, d);
//     }
//   }
//   return res;
// }

static bool replace_in_vector(string &old_str, string &new_str,
                              vector<string> &victim) {
  for (int i = 0; i < victim.size(); i++) {
    if (victim[i] == old_str) {
      victim[i] = new_str;
      return true;
    }
  }
  return false;
}

static bool remove_in_vector(string &str_to_remove, vector<string> &victim) {
  for (auto iter = victim.begin(); iter != victim.end(); iter++) {
    if (*iter == str_to_remove) {
      victim.erase(iter);
      return true;
    }
  }
  return false;
}

bool Mutator::remove_one_from_datalibrary(DATATYPE datatype, string &key) {
  return remove_in_vector(key, data_library_[datatype]);
}

bool Mutator::replace_one_from_datalibrary(DATATYPE datatype, string &old_str,
                                           string &new_str) {
  return replace_in_vector(old_str, new_str, data_library_[datatype]);
}

bool Mutator::remove_one_pair_from_datalibrary_2d(DATATYPE p_datatype,
                                                  DATATYPE c_data_type,
                                                  string &p_key) {
  for (auto &value : data_library_2d_[p_datatype][p_key][c_data_type]) {
    remove_one_from_datalibrary(c_data_type, value);
  }

  data_library_2d_[p_datatype][p_key].erase(c_data_type);
  if (data_library_2d_[p_datatype][p_key].empty()) {
    remove_one_from_datalibrary(p_datatype, p_key);
    data_library_2d_[p_datatype].erase(p_key);
  }

  return true;
}

#define has_element(a, b) (find(a.begin(), a.end(), b) != (a).end())
#define has_key(a, b) ((a).find(b) != (a).end())

bool Mutator::replace_one_value_from_datalibray_2d(DATATYPE p_datatype,
                                                   DATATYPE c_data_type,
                                                   string &p_key,
                                                   string &old_c_value,
                                                   string &new_c_value) {
  replace_one_from_datalibrary(c_data_type, old_c_value, new_c_value);
  replace_in_vector(old_c_value, new_c_value,
                    data_library_2d_[p_datatype][p_key][c_data_type]);
  return true;
}

bool Mutator::fill_one(IR *ir) {
  auto type = ir->data_type_;
  visited.insert(ir);
  if (isDefine(ir->data_flag_)) {
    string new_name = gen_id_name();
    data_library_[type].push_back(new_name);
    ir->str_val_ = new_name;

    for (auto iter : relationmap_) {
      for (auto iter2 : iter.second) {
        if (iter2.first == type && iter2.second == kRelationSubtype) {
          data_library_2d_[type][new_name];
        }
      }
    }
    return true;
  } else if (isAlias(ir->data_flag_)) {
    string alias_target;
    if (data_library_[type].size() != 0)
      alias_target = vector_rand_ele(data_library_[type]);
    else {
      alias_target = get_rand_int(2) ? "v0" : "v1";
    }

    string new_name = gen_id_name();
    data_library_[type].push_back(new_name);
    ir->str_val_ = new_name;

    if (has_key(data_library_2d_, type)) {
      if (has_key(data_library_2d_[type], alias_target)) {
        data_library_2d_[type][new_name] = data_library_2d_[type][alias_target];
      }
    }
    return true;
  }

  else if (data_library_.find(type) != data_library_.end()) {
    if (data_library_[type].empty()) {
      ir->str_val_ = "v0";
      return false;
    }
    ir->str_val_ = vector_rand_ele(data_library_[type]);
    if (isUndefine(ir->data_flag_)) {
      remove_one_from_datalibrary(ir->data_type_, ir->str_val_);
      if (has_key(data_library_2d_, type) &&
          has_key(data_library_2d_[type], ir->str_val_)) {
        for (auto itr = data_library_2d_[type][ir->str_val_].begin();
             has_key(data_library_2d_[type], ir->str_val_) &&
             itr != data_library_2d_[type][ir->str_val_].end();
             itr++) {
          auto c_data_type = *itr;
          remove_one_pair_from_datalibrary_2d(type, c_data_type.first,
                                              ir->str_val_);
          itr--;
          if (!has_key(data_library_2d_[type], ir->str_val_))
            break;
        }
      }
    }
    return true;
  } else if (g_data_library_.find(type) != g_data_library_.end()) {
    if (g_data_library_[type].empty()) {
      return false;
    }
    ir->str_val_ = vector_rand_ele(g_data_library_[type]);
    return true;
  } else if (g_data_library_2d_.find(type) != g_data_library_2d_.end()) {
    int choice = get_rand_int(g_data_library_2d_[type].size());
    auto iter = g_data_library_2d_[type].begin();
    while (choice > 0) {
      iter++;
      choice--;
    }
    ir->str_val_ = iter->first;
    return true;
  } else {
    return false;
  }
  return true;
}

// bool Mutator::fill_one_pair(IR *parent, IR *child) {
//   visited.insert(child);

//   bool is_define = isDefine(child->data_flag_);
//   bool is_replace = isReplace(child->data_flag_);
//   bool is_undefine = isUndefine(child->data_flag_);
//   bool is_alias = isAlias(child->data_flag_);

//   string new_name = "";
//   if (is_define || is_replace || is_alias) {
//     new_name = gen_id_name();
//   }

//   auto p_type = parent->data_type_;
//   auto c_type = child->data_type_;
//   auto p_str = parent->str_val_;

//   auto r_type = relationmap_[c_type][p_type];
//   switch (r_type) {
//   case kRelationElement:

//     if (is_replace) {
//       child->str_val_ = new_name;
//       replace_one_from_datalibrary(c_type, p_str, new_name);

//       if (has_key(data_library_2d_, p_type)) {
//         if (has_key(data_library_2d_[p_type], p_str)) {
//           auto tmp = data_library_2d_[p_type].extract(p_str);
//           tmp.key() = new_name;
//           data_library_2d_[p_type].insert(move(tmp));
//         }
//       } else {
//         for (auto &i1 : data_library_2d_) {
//           for (auto &i2 : i1.second) {
//             for (auto &i3 : i2.second) {
//               if (i3.first == c_type) {
//                 if (has_element(i3.second, p_str)) {
//                   replace_in_vector(p_str, new_name, i3.second);
//                   goto END;
//                 }
//               }
//             }
//           }
//         }
//       }
//     } else if (is_alias) {
//       child->str_val_ = new_name;

//       if (has_key(data_library_2d_, p_type)) {
//         if (has_key(data_library_2d_[p_type], p_str)) {
//           data_library_2d_[p_type][new_name] = data_library_2d_[p_type][p_str];
//           data_library_[p_type].push_back(new_name);
//         }
//       }
//     } else {
//       child->str_val_ = p_str;
//     }
//   END:
//     break;

//   case kRelationSubtype:
//     if (data_library_2d_.find(p_type) != data_library_2d_.end()) {
//       if (data_library_2d_[p_type].find(p_str) !=
//           data_library_2d_[p_type].end()) {
//         if (is_define) {
//           data_library_2d_[p_type][p_str][c_type].push_back(new_name);
//           child->str_val_ = new_name;
//           data_library_[c_type].push_back(new_name);
//           break;
//         } else if (is_undefine) {
//           if ((data_library_2d_[p_type][p_str][c_type]).empty()) {
//             child->str_val_ = "v1";
//             break;
//           }
//           child->str_val_ =
//               vector_rand_ele(data_library_2d_[p_type][p_str][c_type]);
//           remove_in_vector(child->str_val_,
//                            data_library_2d_[p_type][p_str][c_type]);
//           remove_in_vector(child->str_val_, data_library_[c_type]);
//           break;
//         } else if (data_library_2d_[p_type][p_str].find(c_type) !=
//                    data_library_2d_[p_type][p_str].end()) {
//           if (data_library_2d_[p_type][p_str][c_type].empty() == false) {
//             child->str_val_ =
//                 vector_rand_ele(data_library_2d_[p_type][p_str][c_type]);
//           }
//         } else {
//           if (data_library_[c_type].empty()) {
//             if (get_rand_int(2) == 1) {
//               child->str_val_ = "v0";
//             } else {
//               child->str_val_ = "v1";
//             }
//           } else
//             child->str_val_ = vector_rand_ele(data_library_[c_type]);
//         }
//       } else {
//       }
//     } else if (g_data_library_2d_.find(p_type) != g_data_library_2d_.end()) {
//       if (g_data_library_2d_[p_type].find(p_str) !=
//           g_data_library_2d_[p_type].end()) {
//         if (g_data_library_2d_[p_type][p_str].find(c_type) !=
//             g_data_library_2d_[p_type][p_str].end()) {
//           if (g_data_library_2d_[p_type][p_str][c_type].empty() == false) {
//             child->str_val_ =
//                 vector_rand_ele(g_data_library_2d_[p_type][p_str][c_type]);
//           }
//         }
//       }
//     } else {
//       return false;
//     }

//     break;

//   default:
//     assert(0);
//     break;
//   }

//   return true;
// }

void Mutator::reset_scope_library(bool clear_define) {
  scope_library_.clear();
  return;
}

void Mutator::reset_data_library_single_stmt() {
  this->v_table_names_single.clear();
  this->v_create_table_names_single.clear();
  this->v_alias_names_single.clear();
  this->m_table2alias_single.clear();
  this->v_column_names_single.clear();
  this->v_table_name_follow_single.clear();
  this->v_create_foreign_table_names_single.clear();
}

void Mutator::reset_data_library() {
  // data_library_.clear();
  // data_library_2d_.clear();
  m_tables.clear();
  v_table_names.clear();
  m_table2index.clear();
  m_table2alias_single.clear();
  v_table_names_single.clear();
  v_create_table_names_single.clear();
  v_alias_names_single.clear();
  v_column_names_single.clear();
  v_table_name_follow_single.clear();
  v_statistics_name.clear();
  v_create_foreign_table_names_single.clear();
  v_sequence_name.clear();
  v_view_name.clear();
  v_constraint_name.clear();
  v_foreign_table_name.clear();
  v_table_with_partition_name.clear();
  v_int_literals.clear();
  v_float_literals.clear();
  v_string_literals.clear();
}

static IR *search_mapped_ir(IR *ir, DATATYPE type) {
  vector<IR *> to_search;
  vector<IR *> backup;
  to_search.push_back(ir);
  while (!to_search.empty()) {
    for (auto i : to_search) {
      if (i->data_type_ == type) {
        return i;
      }
      if (i->left_) {
        backup.push_back(i->left_);
      }
      if (i->right_) {
        backup.push_back(i->right_);
      }
    }
    to_search = move(backup);
    backup.clear();
  }
  return NULL;
}

IR *Mutator::find_closest_node(IR *stmt_root, IR *node, DATATYPE type) {
  auto cur = node;
  while (true) {
    auto parent = locate_parent(stmt_root, cur);
    if (!parent)
      break;
    bool flag = false;
    while (parent->left_ == NULL || parent->right_ == NULL) {
      cur = parent;
      parent = locate_parent(stmt_root, cur);
      if (!parent) {
        flag = true;
        break;
      }
    }
    if (flag)
      return NULL;

    auto search_root = parent->left_ == cur ? parent->right_ : parent->left_;
    auto res = search_mapped_ir(search_root, type);
    if (res)
      return res;

    cur = parent;
  }
  return NULL;
}

int Mutator::try_fix(char *buf, int len, char *&new_buf, int &new_len) {
  string sql(buf);

  new_buf = buf;
  new_len = len;

  IR* ir_root = raw_parser(sql.c_str(), RAW_PARSE_DEFAULT);

  if (ir_root == NULL)
    return 0;
  validate(ir_root);
  string fixed = ir_root->to_string();
  if (fixed == "") {
    return 0;
  }
  deep_delete(ir_root);
  if (fixed.empty())
    return 0;

  char *sfixed = (char *)malloc(fixed.size() + 1);
  memcpy(sfixed, fixed.c_str(), fixed.size());
  sfixed[fixed.size()] = 0;

  new_buf = sfixed;
  new_len = fixed.size();

  return 1;
}

// added by vancir.

// Return use_temp or not.
bool Mutator::get_valid_str_from_lib(string &ori_norec_select) {
  /* For 1/2 chance, grab one query from the norec library, and return.
   * For 1/2 chance, take the template from the p_oracle and return.
   */
  bool is_succeed = false;

  while (!is_succeed) { // Potential dead loop. Only escape through return.
    bool use_temp = false;
    int query_method = get_rand_int(2);
    if (all_valid_pstr_vec.size() > 0 && query_method < 1) {
      /* Pick the query from the lib, pass to the mutator. */
      ori_norec_select =
          *(all_valid_pstr_vec[get_rand_int(all_valid_pstr_vec.size())]);
      
      if (ori_norec_select == "" ||
          !p_oracle->is_oracle_select_stmt(ori_norec_select))
        continue;
      use_temp = false;
    } else {
      /* Pick the query from the template, pass to the mutator. */
      ori_norec_select = p_oracle->get_template_select_stmts();
      use_temp = true;
    }

    trim_string(ori_norec_select);
    return use_temp;
  }
  fprintf(stderr, "*** FATAL ERROR: Unexpected code execution in the "
                  "Mutator::get_valid_str_from_lib function. \n");
  fflush(stderr);
  abort();
}


vector<IR *> Mutator::parse_query_str_get_ir_set(string &query_str) {
  vector<IR *> ir_set;

  ensure_semicolon_at_query_end(query_str);

  IR* root_ir = NULL;

  try {
    root_ir = raw_parser(query_str.c_str(), RAW_PARSE_DEFAULT);
    if (root_ir == NULL) {
      return ir_set;
    }
  } catch (...) {
    return ir_set;
  }


  /* Debug */
  // root_ir->deep_drop();
  // vector<IR*>dummp_vec;
  // return dummp_vec;

  ir_set = p_oracle->ir_wrapper.get_all_ir_node(root_ir);

  int unique_id_for_node = 0;
  for (auto ir : ir_set) 
    {ir->uniq_id_in_tree_ = unique_id_for_node++;}

  return ir_set;
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


vector<IR *> Mutator::extract_statement(IR *root) {
  vector<IR *> res;
  deque<IR *> bfs = {root};

  while (bfs.empty() != true) {
    auto node = bfs.front();
    bfs.pop_front();

    if (node->type_ == kStmt)
      res.push_back(node);
    if (node->left_)
      bfs.push_back(node->left_);
    if (node->right_)
      bfs.push_back(node->right_);
  }

  return res;
}

void Mutator::set_dump_library(bool to_dump) { this->dump_library = to_dump; }

int Mutator::get_ir_libary_2D_hash_kStatement_size() {
  return this->ir_libary_2D_hash_[kStmt].size();
}

bool Mutator::is_stripped_str_in_lib(string stripped_str) {
  // stripped_str = extract_struct(stripped_str);
  unsigned long str_hash = hash(stripped_str);
  if (stripped_string_hash_.find(str_hash) != stripped_string_hash_.end())
    return true;
  stripped_string_hash_.insert(str_hash);
  return false;
}

/* add_to_library supports only one stmt at a time,
 * add_all_to_library is responsible to split the
 * the current IR tree into single query stmts.
 * This function is not responsible to free the input IR tree.
 */
void Mutator::add_all_to_library(IR *ir, const vector<int> &explain_diff_id) {
  add_all_to_library(ir->to_string(), explain_diff_id);
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
                                 const vector<int> &explain_diff_id) {

  /* If the query_str is empty. Ignored and return. */
  bool is_empty = true;
  for (int i = 0; i < whole_query_str.size(); i++) {
    char c = whole_query_str[i];
    if (!isspace(c) && c != '\n' && c != '\0') {
      is_empty = false; // Not empty.
      break;
    } // Empty
  }

  if (is_empty)
    return;

  vector<string> queries_vector = string_splitter(whole_query_str, ';');
  int i = 0; // For counting oracle valid stmt IDs.
  for (auto current_query : queries_vector) {
    trim_string(current_query);
    if (current_query == "") {
      continue;
    }
    current_query += ";";
    // check the validity of the IR here
    // The unique_id_in_tree_ variable are being set inside the parsing func.

    /* Debug */
    // cerr << "In initial library: getting current_query: " << current_query << "\n";


    vector<IR *> ir_set = parse_query_str_get_ir_set(current_query);
    if (ir_set.size() == 0)
      continue;

    IR *root = ir_set[ir_set.size() - 1];
    vector<IR*> v_cur_stmt_ir = p_oracle->ir_wrapper.get_stmt_ir_vec(root);
    if (v_cur_stmt_ir.size() == 0) {
      root->deep_drop();
      return;
    }
    IR* cur_stmt_ir = v_cur_stmt_ir.front();

    if (p_oracle->is_oracle_select_stmt(cur_stmt_ir)) {
    // if (p_oracle->is_oracle_valid_stmt(current_query)) {
      if (std::find(explain_diff_id.begin(), explain_diff_id.end(), i) !=
          explain_diff_id.end()) {
        add_to_valid_lib(root, current_query, true);
      } else {
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

  if (norec_hash.find(p_hash) != norec_hash.end())
    return;

  norec_hash[p_hash] = true;

  string *new_select = new string(select);

  all_query_pstr_set.insert(new_select);
  all_valid_pstr_vec.push_back(new_select);

//  if (this->dump_library) {
//    std::ofstream f;
//    f.open("./norec-select", std::ofstream::out | std::ofstream::app);
//    f << *new_select << endl;
//    f.close();
//  }

  // cerr << "Saving select str: " << *new_select << " to the lib. \n\n\n";
  add_to_library_core(ir, new_select);

  return;
}

void Mutator::add_to_library(IR *ir, string &query) {

  if (query == "")
    return;

  IRTYPE p_type = ir->type_;
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

//  if (this->dump_library) {
//    std::ofstream f;
//    f.open("./normal-lib", std::ofstream::out | std::ofstream::app);
//    f << *p_query_str << endl;
//    f.close();
//  }

  // cerr << "Saving str: " << *p_query_str << " to the lib. \n\n\n";
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

  IRTYPE p_type = ir->type_;
  IRTYPE left_type = kEmpty, right_type = kEmpty;
  
  string ir_str = ir->to_string();
  unsigned long p_hash = hash(ir_str);
  if (p_type != kParseToplevel && ir_libary_2D_hash_[p_type].find(p_hash) !=
                                ir_libary_2D_hash_[p_type].end()) {
    /* current node not interesting enough. Ignore it and clean up. */
    // cerr << "current node not interesting enough. Ignore it and clean up.\n\n\n";
    return;
  }
  if (p_type != kParseToplevel)
    ir_libary_2D_hash_[p_type].insert(p_hash);

  if (!is_skip_saving_current_node)
    {
      real_ir_set[p_type].push_back(
        std::make_pair(p_query_str, current_unique_id));
      // cerr << "Saving str: " << *p_query_str << "with type: " << get_string_by_ir_type(p_type) << " \n\n\n";
    }

  // Update right_lib, left_lib
  if (ir->right_ != NULL && ir->left_ != NULL && !is_skip_saving_current_node) {
    left_type = ir->left_->type_;
    right_type = ir->right_->type_;
    left_lib_set[left_type].push_back(std::make_pair(
        p_query_str, current_unique_id)); // Saving the parent node id. When
                                          // fetching, use current_node->right.
    // if (*p_query_str == "ALTER INDEX x NO DEPENDS ON EXTENSION x;") {
    //   cerr << "Saving left_type_ ir_node with right type: " << get_string_by_ir_type(right_type) << ", unique_id:" << ir->right_->uniq_id_in_tree_ << "\n\n\n";
    // }
    right_lib_set[right_type].push_back(std::make_pair(
        p_query_str, current_unique_id)); // Saving the parent node id. When
                                          // fetching, use current_node->left.
    // if (*p_query_str == "ALTER INDEX x NO DEPENDS ON EXTENSION x;") {
    //   cerr << "Saving right_type_ ir_node with left type: " << get_string_by_ir_type(left_type) << ", unique_id:" << ir->left_->uniq_id_in_tree_ << "\n\n\n";
    // }
  }

//  if (this->dump_library) {
//
//    std::ofstream f;
//    f.open("./append-core", std::ofstream::out | std::ofstream::app);
//    f << *p_query_str << " node_id: " << current_unique_id << endl;
//    f.close();
//  }

  if (ir->left_) {
    add_to_library_core(ir->left_, p_query_str);
  }

  if (ir->right_) {
    add_to_library_core(ir->right_, p_query_str);
  }

  return;
}

int Mutator::get_cri_valid_collection_size() {
  return all_cri_valid_pstr_vec.size();
}

int Mutator::get_valid_collection_size() { return all_valid_pstr_vec.size(); }


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
    if (current_ir_set.size() <= 0)
      return new IR(kStringLiteral, "");
    current_ir_root = current_ir_set.back();

    /* Retrive the required node, deep copy it, clean up the IR tree and return.
     */
    IR *matched_ir_node = current_ir_set[unique_node_id];
    if (matched_ir_node != NULL) {
      if (matched_ir_node->type_ != type_) {
        current_ir_root->deep_drop();
        return new IR(kStringLiteral, "");
      }
      // return_matched_ir_node = matched_ir_node->deep_copy();
      return_matched_ir_node = matched_ir_node;
      current_ir_root->detach_node(return_matched_ir_node);
    }

    current_ir_root->deep_drop();

    if (return_matched_ir_node != NULL) {
      // cerr << "\n\n\nSuccessfuly with_type: with string: " <<
      // return_matched_ir_node->to_string() << endl;
      return return_matched_ir_node;
    }
  }

  return new IR(kStringLiteral, "");
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
    if (current_ir_set.size() <= 0)
      return NULL;
    current_ir_root = current_ir_set.back();

    /* Retrive the required node, deep copy it, clean up the IR tree and return.
     */
    IR *matched_ir_node = current_ir_set[unique_node_id];
    if (matched_ir_node != NULL) {
      if (matched_ir_node->left_->type_ != type_) {
        current_ir_root->deep_drop();
        return NULL;
      }
      // return_matched_ir_node = matched_ir_node->right_->deep_copy();;  // Not
      // returnning the matched_ir_node itself, but its right_ child node!
      return_matched_ir_node = matched_ir_node->right_;
      current_ir_root->detach_node(return_matched_ir_node);
    }

    current_ir_root->deep_drop();

    if (return_matched_ir_node != NULL) {
      // cerr << "\n\n\nSuccessfuly left_type: with string: " <<
      // return_matched_ir_node->to_string() << endl;
      return return_matched_ir_node;
    }
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
    if (current_ir_set.size() <= 0)
      return NULL;
    current_ir_root = current_ir_set.back();

    /* Retrive the required node, deep copy it, clean up the IR tree and return.
     */
    IR *matched_ir_node = current_ir_set[unique_node_id];
    if (matched_ir_node != NULL) {
      if (matched_ir_node->right_->type_ != type_) {
        current_ir_root->deep_drop();
        return NULL;
      }
      // return_matched_ir_node = matched_ir_node->left_->deep_copy();  // Not
      // returnning the matched_ir_node itself, but its left_ child node!
      return_matched_ir_node = matched_ir_node->left_;
      current_ir_root->detach_node(return_matched_ir_node);
    }

    current_ir_root->deep_drop();

    if (return_matched_ir_node != NULL) {
      // cerr << "\n\n\nSuccessfuly right_type: with string: " <<
      // return_matched_ir_node->to_string() << endl;
      return return_matched_ir_node;
    }
  }

  return NULL;
}

IR* Mutator::get_ir_with_type(const IRTYPE type_) {
  IR* new_ir = get_from_libary_with_type(type_);
  if (new_ir == NULL) {
    return NULL;
  } else if (new_ir->get_ir_type() != type_) {
    cerr << "get_from_libary_with_type(type_) type doesn't matched! Return type: " << get_string_by_ir_type(new_ir->get_ir_type()) << ", requested type: " << get_string_by_ir_type(type_) << ". \n\n\n";
    new_ir->deep_drop();
    return NULL;
  }

  return new_ir;

}


bool Mutator::add_missing_create_table_stmt(IR* ir_root) {
  /* Only accept ir_root as inputs. */
  if (ir_root->get_ir_type() != kParseToplevel) {
    return false;
  }

  // Get Create Stmt. For the beginning. 
  p_oracle->ir_wrapper.set_ir_root(ir_root);
  IR* new_stmt_ir = this->get_ir_with_type(kCreateStmt);
  if (new_stmt_ir == NULL) {
    cerr << "Debug: add_missing_create_table_stmt: Return false because kCreateStmt is NULL. \n\n\n";
    return false;
  } else if (new_stmt_ir->get_left() == NULL) {
    new_stmt_ir->deep_drop();
    cerr << "Debug: add_missing_create_table_stmt: Return false because kCreateStmt is NULL. \n\n\n";
    return false;
  }

  // Get INSERT stmt
  p_oracle->ir_wrapper.set_ir_root(ir_root);
  IR* new_stmt_ir_2 = this->get_ir_with_type(kInsertStmt);
  if (new_stmt_ir_2 == NULL) {
    cerr << "Debug: add_missing_create_table_stmt: Return false because kInsertStmt is NULL. \n\n\n";
    return false;
  } else if (new_stmt_ir_2->get_left() == NULL) {
    new_stmt_ir_2->deep_drop();
    cerr << "Debug: add_missing_create_table_stmt: Return false because kInsertStmt is NULL. \n\n\n";
    return false;
  }

  // Get CREATE INDEX stmt
  p_oracle->ir_wrapper.set_ir_root(ir_root);
  IR* new_stmt_ir_3 = this->get_ir_with_type(kIndexStmt);
  if (new_stmt_ir_3 == NULL) {
    cerr << "Debug: add_missing_create_table_stmt: Return false because kIndexStmt is NULL. \n\n\n";
    return false;
  } else if (new_stmt_ir_3->get_left() == NULL) {
    new_stmt_ir_3->deep_drop();
    cerr << "Debug: add_missing_create_table_stmt: Return false because kIndexStmt is NULL. \n\n\n";
    return false;
  }

  p_oracle->ir_wrapper.set_ir_root(ir_root);
  p_oracle->ir_wrapper.append_stmt_at_idx(new_stmt_ir, 0);
  p_oracle->ir_wrapper.append_stmt_at_idx(new_stmt_ir_2, 1);
  p_oracle->ir_wrapper.append_stmt_at_idx(new_stmt_ir_3, 2);



  // Get Create Stmt, for the end. 
  p_oracle->ir_wrapper.set_ir_root(ir_root);
  new_stmt_ir = this->get_ir_with_type(kCreateStmt);
  if (new_stmt_ir == NULL) {
    cerr << "Debug: add_missing_create_table_stmt: Return false because kCreateStmt is NULL. \n\n\n";
    return false;
  } else if (new_stmt_ir->get_left() == NULL) {
    new_stmt_ir->deep_drop();
    cerr << "Debug: add_missing_create_table_stmt: Return false because kCreateStmt is NULL. \n\n\n";
    return false;
  }

  // Get INSERT stmt
  p_oracle->ir_wrapper.set_ir_root(ir_root);
  new_stmt_ir_2 = this->get_ir_with_type(kInsertStmt);
  if (new_stmt_ir_2 == NULL) {
    cerr << "Debug: add_missing_create_table_stmt: Return false because kInsertStmt is NULL. \n\n\n";
    return false;
  } else if (new_stmt_ir_2->get_left() == NULL) {
    new_stmt_ir_2->deep_drop();
    cerr << "Debug: add_missing_create_table_stmt: Return false because kInsertStmt is NULL. \n\n\n";
    return false;
  }

  // Get CREATE INDEX stmt
  p_oracle->ir_wrapper.set_ir_root(ir_root);
  new_stmt_ir_3 = this->get_ir_with_type(kIndexStmt);
  if (new_stmt_ir_3 == NULL) {
    cerr << "Debug: add_missing_create_table_stmt: Return false because kIndexStmt is NULL. \n\n\n";
    return false;
  } else if (new_stmt_ir_3->get_left() == NULL) {
    new_stmt_ir_3->deep_drop();
    cerr << "Debug: add_missing_create_table_stmt: Return false because kIndexStmt is NULL. \n\n\n";
    return false;
  }

  p_oracle->ir_wrapper.set_ir_root(ir_root);
  p_oracle->ir_wrapper.append_stmt_at_end(new_stmt_ir);
  p_oracle->ir_wrapper.append_stmt_at_end(new_stmt_ir_2);
  p_oracle->ir_wrapper.append_stmt_at_end(new_stmt_ir_3);

  return true;

}
#include "./sqlite_index.h"
#include "../include/mutator.h"
#include <iostream>

#include <regex>
#include <string>

/* TODO:: Should we change this function in the not NOREC oracle? */
bool SQL_INDEX::mark_all_valid_node(vector<IR *> &v_ir_collector) {
  return true;
}

void SQL_INDEX::get_v_valid_type(const string &cmd_str,
                                 vector<VALID_STMT_TYPE_INDEX> &v_valid_type) {
  /* Look throught first validation stmt's result_1 first */
  size_t begin_idx = cmd_str.find("SELECT 'BEGIN VERI 0';", 0);
  size_t end_idx = cmd_str.find("SELECT 'END VERI 0';", 0);

  while (begin_idx != string::npos) {
    if (end_idx != string::npos) {
      string cur_cmd_str =
          cmd_str.substr(begin_idx + 23, (end_idx - begin_idx - 23));
      begin_idx = cmd_str.find("SELECT 'BEGIN VERI 0';", begin_idx + 23);
      end_idx = cmd_str.find("SELECT 'END VERI 0';", end_idx + 21);

      vector<IR*> v_cur_stmt_ir = g_mutator->parse_query_str_get_ir_set(cur_cmd_str);
      if ( v_cur_stmt_ir.size() == 0 ) {
        continue;
      }
      if ( !(v_cur_stmt_ir.back()->left_ != NULL && v_cur_stmt_ir.back()->left_->left_ != NULL) ) {
        v_cur_stmt_ir.back()->deep_drop();
        continue;
      }

      IR* cur_stmt_ir = v_cur_stmt_ir.back()->left_->left_;
      v_valid_type.push_back(get_stmt_INDEX_type(cur_stmt_ir));

      v_cur_stmt_ir.back()->deep_drop();

    } else {
      // cerr << "Error: For the current begin_idx, we cannot find the end_idx. \n\n\n";
      break; // For the current begin_idx, we cannot find the end_idx. Ignore
             // the current output.
    }
  }
}

void SQL_INDEX::compare_results(ALL_COMP_RES &res_out) {
  if ((res_out.v_cmd_str.size() < 1) || (res_out.v_res_str.size() < 1)) {
    cerr << "Error: Getting empty v_cmd_str or v_res_str from the res_out. Actual size for v_res_str is: " \
         << to_string(res_out.v_res_str.size()) << \
            ". Possibly processing only the seed files. \n";
    res_out.final_res = ALL_Error;
    return;
  }

  res_out.final_res = Pass;

  vector<VALID_STMT_TYPE_INDEX> v_valid_type;
  get_v_valid_type(res_out.v_cmd_str[0], v_valid_type);

  bool is_all_errors = true;
  int i = 0;
  for (COMP_RES &res : res_out.v_res) {
    if (i >= v_valid_type.size()) {
      res.comp_res = ORA_COMP_RES::Error;
      break; // break the loop
    }
    switch (v_valid_type[i++]) {
    case VALID_STMT_TYPE_INDEX::NORMAL:
      if (!this->compare_norm(res))
        is_all_errors = false;
      break;

    case VALID_STMT_TYPE_INDEX::AGGR:
      if (!this->compare_aggr(res))
        is_all_errors = false;
      break;
    default:
      res.comp_res == ORA_COMP_RES::Error;
    }
    if (res.comp_res == ORA_COMP_RES::Fail)
      res_out.final_res = ORA_COMP_RES::Fail;
  }

  if (is_all_errors && res_out.final_res != ORA_COMP_RES::Fail)
    res_out.final_res = ORA_COMP_RES::ALL_Error;

  return;
}

bool SQL_INDEX::compare_norm(COMP_RES &res) { /* Handle normal valid stmt: SELECT * FROM ...; Return is_err */
  if (res.v_res_str.size() <= 1) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }
  vector<string> &v_res_str = res.v_res_str;
  vector<int> &v_res_int = res.v_res_int;

  for (const string &res_str : v_res_str) {
    if (res_str.find("Error") != string::npos) {
      res.comp_res = ORA_COMP_RES::Error;
      return true;
    }
    int cur_res_int = 0;
    vector<string> v_res_split = string_splitter(res_str, '\n');

    if (v_res_split.size() > 50) {
      res.comp_res = ORA_COMP_RES::Error;
      return true;
    }
    /* Remove NULL results */
    for (const string &r : v_res_split) {
      if (is_str_empty(r))
        --cur_res_int;
    }
    v_res_split.clear();

    cur_res_int += std::count(res_str.begin(), res_str.end(), '\n');
    v_res_int.push_back(cur_res_int);
  }

  for (int i = 1; i < v_res_int.size(); i++) {
    if (v_res_int[0] != v_res_int[i]) {
      res.comp_res = ORA_COMP_RES::Fail;
      return false;
    }
  }

  res.comp_res = ORA_COMP_RES::Pass;
  return false;
}

bool SQL_INDEX::compare_aggr(COMP_RES &res) {
  if (res.v_res_str.size() <= 1) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }
  vector<string> &v_res_str = res.v_res_str;

  for (int i = 0; i < v_res_str.size(); i++) {
    if (v_res_str[i].find("Error") != string::npos) {
      res.comp_res = ORA_COMP_RES::Error;
      return true;
    }
    int res_a_int = 0;
    int res_b_int = 0;
    try {
      res_a_int = stoi(res.v_res_str[0]);
      res_b_int = stoi(res.v_res_str[i]);
    } catch (std::invalid_argument &e) {
      res.comp_res = ORA_COMP_RES::Error;
      return true;
    } catch (std::out_of_range &e) {
      res.comp_res = ORA_COMP_RES::Error;
      return true;
    } catch (const std::exception& e) {
      res.comp_res = ORA_COMP_RES::Error;
      return true;
    }
    res.v_res_int.push_back(res_b_int);

    if (res_a_int != res_b_int) {
      res.comp_res = ORA_COMP_RES::Fail;
      return false;
    }

  }

  res.comp_res = ORA_COMP_RES::Pass;
  return false;
}

bool SQL_INDEX::is_oracle_normal_stmt(IR* cur_IR) {
  if (cur_IR->type_ == kCreateIndexStatement) {
    return true;
  }
  return false;
}

bool SQL_INDEX::is_oracle_select_stmt(IR* cur_IR) {
  if (cur_IR->type_ == kSelectStatement) {
    return true;
  } else {
    return false;
  }
}

IR* SQL_INDEX::pre_fix_transform_normal_stmt(IR* cur_stmt) {
  if (!this->is_oracle_normal_stmt(cur_stmt)){
    cerr << "Error: Pre_fix_transform_normal_stmt not receiving kCreateIndexStatement. Func: SQL_INDEX::pre_fix_transform_normal_stmt(IR* cur_stmt). \n";
    return nullptr;
  }
  cur_stmt = cur_stmt->deep_copy();
  vector<IR*> opt_unique_vec = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOptUnique, false);
  for (auto opt_unique_ir : opt_unique_vec) {
    if (opt_unique_ir->op_)
      opt_unique_ir->op_->prefix_ = ""; // Remove UNIQUE constraints in the deep_copied cur_stmt. 
  }
  return cur_stmt;
  cur_stmt->deep_drop();
  return nullptr;
}

vector<IR*> SQL_INDEX::post_fix_transform_normal_stmt(IR* cur_stmt, unsigned multi_run_id){
  if (multi_run_id == 0) {
    vector<IR*> v_ret; v_ret.push_back(cur_stmt->deep_copy()); return v_ret;
  }
  // multi_run_id == 1: return an empty statement. 
  IR* new_empty_stmt = new IR(kStatement, "");
  vector<IR*> output_stmt_vec;
  output_stmt_vec.push_back(new_empty_stmt);
  return output_stmt_vec;
}

vector<IR*> SQL_INDEX::post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) {
  vector<IR*> ret_vec;
  ret_vec.push_back(cur_stmt->deep_copy());
  return ret_vec;
}

IR* SQL_INDEX::get_random_append_stmts_ir() {
  string temp_append_str = this->temp_append_stmts[get_rand_int(this->temp_append_stmts.size())];
  vector<IR*> app_ir_set = g_mutator->parse_query_str_get_ir_set(temp_append_str);
  if (app_ir_set.size() == 0) { 
    cerr << "FATAL ERROR: SQL_INDEX::get_random_append_stmts_ir() parse string failed. \n"; 
    return nullptr;
  }
  IR* cur_root = app_ir_set.back();
  vector<IR*> stmt_list_vec = ir_wrapper.get_stmt_ir_vec(cur_root);
  if (stmt_list_vec.size() == 0) {
    cerr << "FATAL ERROR: SQL_INDEX::get_random_append_stmts_ir() getting stmt failed. \n"; 
    cur_root->deep_drop();
    return nullptr;
  }
  IR* first_stmt = stmt_list_vec[0]->deep_copy();
  cur_root->deep_drop();
  return first_stmt;
}

VALID_STMT_TYPE_INDEX SQL_INDEX::get_stmt_INDEX_type (IR* cur_stmt) {
  VALID_STMT_TYPE_INDEX default_type_ = VALID_STMT_TYPE_INDEX::NORMAL;

  vector<IR*> v_result_column_list = ir_wrapper.get_result_column_list_in_select_clause(cur_stmt);
  if (v_result_column_list.size() == 0) {
    return VALID_STMT_TYPE_INDEX::ROWID_UNKNOWN;
  }

  vector<IR*> v_agg_func_args = ir_wrapper.get_ir_node_in_stmt_with_type(v_result_column_list[0], kFunctionArgs, false);
  if (v_agg_func_args.size() == 0) {
    return default_type_;
  }

  vector<IR*> v_aggr_func_ir = ir_wrapper.get_ir_node_in_stmt_with_type(v_result_column_list[0], kFunctionName, false);
  if (v_aggr_func_ir.size() == 0) {
    return default_type_;
  }
  if (v_aggr_func_ir[0]->left_ == NULL) {
    return default_type_;
  }

  /* Might have aggr function. */
  if (v_aggr_func_ir[0]->left_->op_ && v_aggr_func_ir[0]->left_->op_->prefix_) {
    string aggr_func_str = v_aggr_func_ir[0]->left_->op_->prefix_;
    if (findStringIn(aggr_func_str, "MIN")) {
      return VALID_STMT_TYPE_INDEX::AGGR;
    } else if (findStringIn(aggr_func_str, "MAX")){
      return VALID_STMT_TYPE_INDEX::AGGR;
    } else if (findStringIn(aggr_func_str, "COUNT")){
      return VALID_STMT_TYPE_INDEX::AGGR;
    } else if (findStringIn(aggr_func_str, "SUM")) {
      return VALID_STMT_TYPE_INDEX::AGGR;
    } else if (findStringIn(aggr_func_str, "AVG")) {
      return VALID_STMT_TYPE_INDEX::AGGR;
    }
  }

  return default_type_;

}

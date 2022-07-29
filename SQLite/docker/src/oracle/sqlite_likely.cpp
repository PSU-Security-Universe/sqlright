#include "./sqlite_likely.h"
#include "../include/mutator.h"
#include <iostream>

#include <algorithm>
#include <regex>
#include <string>

bool SQL_LIKELY::mark_all_valid_node(vector<IR *> &v_ir_collector) {
  return true;
}


void SQL_LIKELY::get_v_valid_type(
    const string &cmd_str, vector<VALID_STMT_TYPE_LIKELY> &v_valid_type) {
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
      v_valid_type.push_back(get_stmt_LIKELY_type(cur_stmt_ir));

      v_cur_stmt_ir.back()->deep_drop();

    } else {
      // cerr << "Error: For the current begin_idx, we cannot find the end_idx. \n\n\n";
      break; // For the current begin_idx, we cannot find the end_idx. Ignore
             // the current output.
    }
  }
}

void SQL_LIKELY::compare_results(ALL_COMP_RES &res_out) {

  res_out.final_res = Pass;

  vector<VALID_STMT_TYPE_LIKELY> v_valid_type;
  this->get_v_valid_type(res_out.cmd_str, v_valid_type);

  bool is_all_errors = true;
  int i = 0;
  for (COMP_RES &res : res_out.v_res) {
    switch (v_valid_type[i++]) {
    case VALID_STMT_TYPE_LIKELY::NORMAL:
      if (!this->compare_norm(res))
        is_all_errors = false;
      break;
    case VALID_STMT_TYPE_LIKELY::AGGR:
      if (!this->compare_aggr(res))
        is_all_errors = false;
      break;
    default:
      res.comp_res = ORA_COMP_RES::Error;
      break;
    }
    if (res.comp_res == ORA_COMP_RES::Fail)
      res_out.final_res = ORA_COMP_RES::Fail;
  }

  if (is_all_errors && res_out.final_res != ORA_COMP_RES::Fail)
    res_out.final_res = ORA_COMP_RES::ALL_Error;

  return;
}

bool SQL_LIKELY::compare_norm(
    COMP_RES
        &res) { /* Handle normal valid stmt: SELECT * FROM ...; Return is_err */

  const string &res_str_0 = res.res_str_0;
  const string &res_str_1 = res.res_str_1;
  const string &res_str_2 = res.res_str_2;
  int &res_int_0 = res.res_int_0;
  int &res_int_1 = res.res_int_1;
  int &res_int_2 = res.res_int_2;

  res_int_0 = 0;
  res_int_1 = 0;
  res_int_2 = 0;

  if (
      findStringIn(res_str_0, "error") ||
      findStringIn(res_str_1, "error") ||
      findStringIn(res_str_2, "error")
    ) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  vector<string> v_res_0 = string_splitter(res_str_0, '\n');
  vector<string> v_res_1 = string_splitter(res_str_1, '\n');
  vector<string> v_res_2 = string_splitter(res_str_2, '\n');

  if (v_res_0.size() > 50 || v_res_1.size() > 50 || v_res_2.size() > 50) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  for (const string &r : v_res_0) {
    if (is_str_empty(r))
      --res_int_0;
  }
  for (const string &r : v_res_1) {
    if (is_str_empty(r))
      --res_int_1;
  }
  for (const string &r : v_res_2) {
    if (is_str_empty(r))
      --res_int_2;
  }

  res_int_0 += std::count(res_str_0.begin(), res_str_0.end(), "\n");
  res_int_1 += std::count(res_str_1.begin(), res_str_1.end(), "\n");
  res_int_2 += std::count(res_str_2.begin(), res_str_2.end(), "\n");

  if (res_int_0 != res_int_1 || res_int_0 != res_int_2) {
    res.comp_res = ORA_COMP_RES::Fail;
    return false;
  }

  res.comp_res = ORA_COMP_RES::Pass;
  return false;
}

bool SQL_LIKELY::compare_aggr(COMP_RES &res) {

  string &res_a = res.res_str_0;
  string &res_b = res.res_str_1;
  string &res_c = res.res_str_2;
  int &res_a_int = res.res_int_0;
  int &res_b_int = res.res_int_1;
  int &res_c_int = res.res_int_2;

  if (
      findStringIn(res_a, "error") ||
      findStringIn(res_b, "error") ||
      findStringIn(res_c, "error")
    ) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  try {
    res_a_int = stoi(res.res_str_0);
    res_b_int = stoi(res.res_str_1);
    res_c_int = stoi(res.res_str_2);
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

  if (res_a_int != res_b_int || res_a_int != res_c_int) {
    res.comp_res = ORA_COMP_RES::Fail;
  } else {
    res.comp_res = ORA_COMP_RES::Pass;
  }

  return false;
}

bool SQL_LIKELY::is_oracle_select_stmt(IR* cur_IR) {

  // // Remove GROUP BY and HAVING stmts. 
  // if (ir_wrapper.is_exist_group_by(cur_IR) || ir_wrapper.is_exist_having(cur_IR)) {
  //   return false;
  // }

  if (
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_IR, kSelectStatement, false) &&
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_IR, kFromClause, false) &&
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_IR, kWhereExpr, false)
    // ir_wrapper.get_num_result_column_in_select_clause(cur_IR) == 1
  ) {
    return true;
  }
  return false;
}

vector<IR*> SQL_LIKELY::post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) {

  vector<IR*> trans_IR_vec;
  IR* ori_ir_root = cur_stmt;
  trans_IR_vec.push_back(ori_ir_root->deep_copy());

  // ADDED LIKELY.
  cur_stmt = ori_ir_root->deep_copy();
  IR* expr_in_where = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kWhereExpr, false)[0]->left_;
  // Add LIKELY functions. 
  IR* cur_where_expr = expr_in_where;
  cur_where_expr = this->ir_wrapper.add_func(cur_where_expr, "LIKELY");
  if (cur_where_expr == nullptr) {
    cerr << "Error: ir_wrapper>add_func() failed. Func: SQL_LIKELY::post_fix_transform_select_stmt(). Return empty vector. \n";
    trans_IR_vec[0]->deep_drop();
    cur_stmt->deep_drop();
    vector<IR*> tmp;
    return tmp;
  }
  trans_IR_vec.push_back(cur_stmt);

  // Added UNLIKELY
  cur_stmt = ori_ir_root->deep_copy();
  expr_in_where = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kWhereExpr, false)[0]->left_;
  // Add UNLIKELY functions. 
  cur_where_expr = expr_in_where;
  cur_where_expr = this->ir_wrapper.add_func(cur_where_expr, "UNLIKELY");
  if (cur_where_expr == nullptr) {
    cerr << "Error: ir_wrapper>add_func() failed. Func: SQL_LIKELY::post_fix_transform_select_stmt(). Return empty vector. \n";
    trans_IR_vec[0]->deep_drop();
    cur_stmt->deep_drop();
    vector<IR*> tmp;
    return tmp;
  }
  trans_IR_vec.push_back(cur_stmt);

  return trans_IR_vec;

}


VALID_STMT_TYPE_LIKELY SQL_LIKELY::get_stmt_LIKELY_type (IR* cur_stmt) {
  VALID_STMT_TYPE_LIKELY default_type_ = VALID_STMT_TYPE_LIKELY::NORMAL;

  vector<IR*> v_result_column_list = ir_wrapper.get_result_column_list_in_select_clause(cur_stmt);
  if (v_result_column_list.size() == 0) {
    return VALID_STMT_TYPE_LIKELY::ROWID_UNKNOWN;
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
      return VALID_STMT_TYPE_LIKELY::AGGR;
    } else if (findStringIn(aggr_func_str, "MAX")){
      return VALID_STMT_TYPE_LIKELY::AGGR;
    } else if (findStringIn(aggr_func_str, "COUNT")){
      return VALID_STMT_TYPE_LIKELY::AGGR;
    } else if (findStringIn(aggr_func_str, "SUM")) {
      return VALID_STMT_TYPE_LIKELY::AGGR;
    } else if (findStringIn(aggr_func_str, "AVG")) {
      return VALID_STMT_TYPE_LIKELY::AGGR;
    }
  }

  return default_type_;

}

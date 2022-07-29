#include "mysql_norec.h"
#include "../include/mutate.h"
#include <iostream>
#include <chrono>

#include <regex>
#include <string>

bool SQL_NOREC::is_oracle_select_stmt(IR* cur_stmt) {

  // auto single_is_oracle_select_func_start_time = std::chrono::system_clock::now();

  if (cur_stmt == NULL) {
    // cerr << "Return false because cur_stmt is NULL; \n";
    return false;
  }

  if (cur_stmt->get_ir_type() != kSelectStmt) {
    // cerr << "Return false because this is not a SELECT stmt: " << get_string_by_ir_type(cur_stmt->get_ir_type()) <<  " \n";
    return false;
  }

  // g_mutator->debug(cur_stmt, 0);

  /* Remove cases that contains kGroupClause, kHavingClause and kLimitClause */
  if (
      ir_wrapper.is_exist_group_clause(cur_stmt) ||
      ir_wrapper.is_exist_having_clause(cur_stmt) ||
      ir_wrapper.is_exist_limit_clause(cur_stmt) ||
      ir_wrapper.is_exist_window_func_call(cur_stmt)
  ) {
      return false;
  }

  // Ignore statements with UNION, EXCEPT and INTERCEPT
  if (ir_wrapper.is_exist_set_operator(cur_stmt)) {
    // cerr << "Return false because of set operator \n";
    return false;
  }

  /* If it is an NOREC compatible select statment,
   * there would be only one kSelectItem.
   * */
  vector<IR*> v_select_item_ir = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSelectItem, false);
  if (v_select_item_ir.size() != 1) {return false;}

  IR* select_item_ir = v_select_item_ir.front();

  // auto single_is_ir_in_start_time = std::chrono::system_clock::now();

  // Avoid calculations inside select item, such as SELECT count(*) + 100 FROM... 
  vector<IR*> v_bit_expr = ir_wrapper.get_ir_node_in_stmt_with_type(select_item_ir, kBitExpr, false);
  if (v_bit_expr.size() != 1) {
    return false;
  }

  /* Next, check whether there are COUNT(*) func */
  bool is_found_count = false;
  vector<IR*> v_sum_expr_ir = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSumExpr, false);
  vector<IR*> v_matching_sum_expr_ir;
  for (IR* sum_expr_ir : v_sum_expr_ir) {
      if (
          sum_expr_ir->get_prefix() == "COUNT(" &&
          sum_expr_ir->get_middle() == "* )" &&
          sum_expr_ir->get_right()->is_empty()  // opt_windowing_clause should be empty
      ) {
          v_matching_sum_expr_ir.push_back(sum_expr_ir);
      }
  }

  for (IR* sum_expr_ir : v_matching_sum_expr_ir) {
      if (ir_wrapper.is_ir_in(sum_expr_ir, select_item_ir)) {
        is_found_count = true;
        break;
      }
  }


  if (!is_found_count) {
      // cerr << "Return false because COUNT func is not found. \n\n\n";
      return false;
  }

  if (
    !ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_stmt, kFromClause, false) ||
    !ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_stmt, kWhereClause, false)
  ) {
      // cerr << "Return false because FROM clause or WHERE clause is not found. \n\n\n";
      return false;
  }

  // auto single_ir_in_end_time = std::chrono::system_clock::now();
  // std::chrono::duration<double> single_ir_in_used_time = single_ir_in_end_time  - single_is_ir_in_start_time;
  // cerr << " single_ir_in_used_time used time: " << single_ir_in_used_time.count() << "\n\n\n";

  // auto single_is_oracle_end_time = std::chrono::system_clock::now();
  // std::chrono::duration<double> is_oracle_used_time = single_is_oracle_end_time  - single_is_oracle_select_func_start_time;
  // cerr << " Is_oracle_select stmt used time: " << is_oracle_used_time.count() << "\n\n\n";

  /* All checks passed. This is an NOREC compatible SELECT stmt. */
  return true;

}

vector<IR*> SQL_NOREC::post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id){
  vector<IR*> trans_IR_vec;

  cur_stmt->parent_ = NULL;

  /* Double check whether the stmt is norec compatible */
  if (!is_oracle_select_stmt(cur_stmt)) {
    return trans_IR_vec;
  }

  // cerr << "Debug: in SQL_NOREC::post_fix_transform_select_stmt(), getting: \n";
  // g_mutator->debug(cur_stmt);
  // cerr << "Is parent? " << cur_stmt->parent_ << "\n";
  // cerr << "End \n\n\n";

  IR* first_stmt = cur_stmt->deep_copy();

  // cerr << "Debug: in SQL_NOREC::post_fix_transform_select_stmt(), getting: \n";
  // g_mutator->debug(first_stmt);
  // cerr << "Is parent? " << first_stmt->parent_ << "\n";
  // cerr << "End \n\n\n";

  /* Remove the kWindowingClause, if exists.
   * These kWindowingClause are parented by kOptWindowingClause, and
   * can be removed without causing syntactic errors.
   * kWindowingClause inside kWindowFuncCall are excluded by is_oracle_select_stmt() already
   * Doesn't need to worry about double free, because all overclause that we remove
   * are not in subqueries.
   * */
  vector<IR* > v_over_clause = ir_wrapper.get_ir_node_in_stmt_with_type(first_stmt, kWindowingClause, false);

  if (v_over_clause.size() > 0) {
    IR* over_clause = v_over_clause.front();
    IR* new_over_clause = new IR(kWindowingClause, OP0());
    first_stmt->swap_node(over_clause, new_over_clause);
    over_clause->deep_drop();
  }

  /* Remove the kWindowClause, if exists.
   * Doesn't need to worry about double free, because all windowclause that we remove
   * are not in subqueries.
   * */
  vector<IR* > v_window_clause = ir_wrapper.get_ir_node_in_stmt_with_type(first_stmt, kOptWindowClause, false);
  if (v_window_clause.size() > 0) {
    IR* window_clause = v_window_clause.front();
    IR* new_window_clause = new IR(kOptWindowClause, OP0());
    first_stmt->swap_node(window_clause, new_window_clause);
    window_clause->deep_drop();
  }


  trans_IR_vec.push_back(first_stmt); // Save the original version.

  // cerr << "DEBUG: Getting post_fix cur_stmt: " << cur_stmt->to_string() << " \n\n\n";

  // cerr << "DEBUG: Getting where_clause " <<  ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kWhereClause, false).size() << "\n\n\n";

  /* Take care of WHERE and FROM clauses. */
  // cerr << "Printing post_fix tree: ";
  // g_mutator->debug(cur_stmt, 0);
  // cerr << "\n\n\n\n\n\n\n";

  vector<IR*> transformed_temp_vec;
  int ret = run_parser_multi_stmt(this->post_fix_temp, transformed_temp_vec);

  if (ret != 0 || transformed_temp_vec.size() == 0) {
      cerr << "Error: parsing the post_fix_temp from SQL_NOREC::post_fix_transform_select_stmt returns empty IR vector. \n";
      first_stmt->deep_drop();
      trans_IR_vec.clear();
      return trans_IR_vec;
  }

  IR* transformed_temp_ir = transformed_temp_vec.back();
  IR* trans_stmt_ir = ir_wrapper.get_first_stmt_from_root(transformed_temp_ir)->deep_copy();
  trans_stmt_ir->parent_ = NULL;
  transformed_temp_ir->deep_drop();


  vector<IR*> src_order_vec = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOrderClause, false);
  if (src_order_vec.size() > 0 ) {
    IR* src_order_clause = src_order_vec[0]->deep_copy();
    IR* dest_order_clause = ir_wrapper.get_ir_node_in_stmt_with_type(trans_stmt_ir, kOrderClause, false)[0];
    if (!trans_stmt_ir->swap_node(dest_order_clause, src_order_clause)){
      trans_stmt_ir->deep_drop();
      src_order_clause->deep_drop();
      cerr << "Error: swap_node failed for sort_clause. In function SQL_NOREC::post_fix_transform_select_stmt. \n";
      vector<IR*> tmp; return tmp;
    }
    dest_order_clause->deep_drop();
  } else {
    IR* dest_order_clause = ir_wrapper.get_ir_node_in_stmt_with_type(trans_stmt_ir, kOrderClause, false)[0];
    trans_stmt_ir->detatch_node(dest_order_clause);
    dest_order_clause->deep_drop();
  }

  IR* src_where_expr = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kWhereClause, false)[0]->where_clause_get_expr()->deep_copy();
  IR* dest_where_expr = ir_wrapper.get_ir_node_in_stmt_with_type(trans_stmt_ir, kExpr, false)[4];


  IR* src_from_expr = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kFromClause, false)[0]->deep_copy();
  IR* dest_from_expr = ir_wrapper.get_ir_node_in_stmt_with_type(trans_stmt_ir, kFromClause, false)[0];

  if (!trans_stmt_ir->swap_node(dest_where_expr, src_where_expr)){
    trans_stmt_ir->deep_drop();
    src_where_expr->deep_drop();
    src_from_expr->deep_drop();
    cerr << "Error: swap_node failed for where_clause. In function SQL_NOREC::post_fix_transform_select_stmt. \n";
    vector<IR*> tmp; return tmp;
  }
  dest_where_expr->deep_drop();
  if (!trans_stmt_ir->swap_node(dest_from_expr, src_from_expr)) {
    trans_stmt_ir->deep_drop();
    src_from_expr->deep_drop();
    cerr << "Error: swap_node failed for from_clause. In function SQL_NOREC::post_fix_transform_select_stmt. \n";
    vector<IR*> tmp; return tmp;
  }
  dest_from_expr->deep_drop();

  trans_IR_vec.push_back(trans_stmt_ir);

  return trans_IR_vec;

}


void SQL_NOREC::compare_results(ALL_COMP_RES &res_out) {

  res_out.final_res = ORA_COMP_RES::Pass;
  bool is_all_err = true;

  for (COMP_RES &res : res_out.v_res) {
    if (findStringIn(res.res_str_0, "Error") ||
        findStringIn(res.res_str_1, "Error")) {
      res.comp_res = ORA_COMP_RES::Error;
      res.res_int_0 = -1;
      res.res_int_1 = -1;
      continue;
    }
    try {
      res.res_int_0 = stoi(res.res_str_0);
      // cout << "res_int_0: " << res.res_int_0 << endl;
      res.res_int_1 = stoi(res.res_str_1);
      // cout << "res_int_1: " << res.res_int_1 << endl;
    } catch (std::invalid_argument &e) {
      res.comp_res = ORA_COMP_RES::Error;
      continue;
    } catch (std::out_of_range &e) {
      continue;
    }
    is_all_err = false;
    if (res.res_int_0 != res.res_int_1) { // Found mismatched.
      res.comp_res = ORA_COMP_RES::Fail;
      res_out.final_res = ORA_COMP_RES::Fail;
    } else {
      res.comp_res = ORA_COMP_RES::Pass;
    }
  }

  if (is_all_err && res_out.final_res != ORA_COMP_RES::Fail)
    res_out.final_res = ORA_COMP_RES::ALL_Error;
  return;
}

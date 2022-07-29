#include "./postgres_norec.h"
#include "../include/mutate.h"
#include <iostream>

#include <regex>
#include <string>

bool SQL_NOREC::is_oracle_select_stmt(IR* cur_stmt) {

  if (cur_stmt == NULL) {
    // cerr << "Return false because cur_stmt is NULL; \n";
    return false;
  }

  if (cur_stmt->get_ir_type() != kSelectStmt) {
    // cerr << "Return false because this is not a SELECT stmt: " << get_string_by_ir_type(cur_stmt->get_ir_type()) <<  " \n";
    return false;
  }

  /* Remove cases that contains kGroupClause, kHavingClause and kLimitClause */
  vector<IR*> v_group_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kGroupClause, false);
  for (IR* group_clause : v_group_clause) {
    if (!group_clause->is_empty()){
      // cerr << "Return false because of GROUP clause \n";
      return false;
    }
  }


  vector<IR*> v_having_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kHavingClause, false);
  for (IR* having_clause : v_having_clause) {
    if (!having_clause->is_empty()){
      // cerr << "Return false because of having clause \n";
      return false;
    }
  }

  vector<IR*> v_limit_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kLimitClause, false);
  for (IR* limit_clause : v_limit_clause) {
    if (!limit_clause->is_empty()){
      // cerr << "Return false because of LIMIT clause \n";
      return false;
    }
  }

  // Ignore statements with UNION, EXCEPT and INTERCEPT
  if (ir_wrapper.is_exist_set_operator(cur_stmt)) {
    // cerr << "Return false because of set operator \n";
    return false;
  }


  vector<IR*> v_target_list_ir = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kTargetList, false);

  if (v_target_list_ir.size() == 0) return false;

  IR* target_list_ir = v_target_list_ir.front();

  while ( target_list_ir->get_ir_type() == kTargetList && target_list_ir->get_right()) {
    /* Clean all the extra select target clauses, only leave the first one untouched.
     * If this is the first kTargetList, the right sub-node should be empty.
     * */
    target_list_ir->replace_op(OP0());
    IR* extra_targetel_ir = target_list_ir->get_right();
    target_list_ir->update_right(NULL);
    extra_targetel_ir->deep_drop();
    target_list_ir = target_list_ir->get_left();
  }

  // cerr << "num_target_el: " << ir_wrapper.get_num_target_el_in_select_clause(cur_stmt) << "\n";

  if (
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_stmt, kFromClause, false) &&
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_stmt, kWhereClause, false) &&
    ir_wrapper.get_num_target_el_in_select_clause(cur_stmt) == 1
  ) {

    /* Make sure from clause and where clause are not empty.  */
    IR* from_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kFromClause, false)[0];
    // The first one should be the parent one.
    if (from_clause->is_empty()) {
      // cerr << "Return false because FROM clause is empty \n";
      return false;
    }
    IR* where_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kWhereClause, false)[0];
    // The first one should be the parent one.
    if (where_clause->is_empty()) {
      // cerr << "Return false because WHERE clause is empty \n";
      return false;
    }


    /* Here, we need to ensure the SELECT COUNT(*) structure is enforced.  */
    /* This is the IR tree structure that we need to enforce:
     *
     *   12: kSimpleSelect_1: data_whatever: kUnknown: 11: SELECT count ( * )
     *    13: kOptAllClause: data_whatever: kUnknown: 12:
     *    13: kOptTargetList: data_whatever: kUnknown: 13: count ( * )
     *     14: kTargetList: data_whatever: kUnknown: 14: count ( * )
     *      15: kTargetEl: data_whatever: kUnknown: 15: count ( * )
     *       16: kAExpr: data_whatever: kUnknown: 16: count ( * )
     *        17: kCExpr: data_whatever: kUnknown: 17: count ( * )
     *         18: kFuncExpr: data_whatever: kUnknown: 18: count ( * )
     *          19: kFuncExpr_2: data_whatever: kUnknown: 19: count ( * )
     *           20: kFuncExpr_1: data_whatever: kUnknown: 20: count ( * )
     *            21: kFuncApplication: data_whatever: kUnknown: 21: count ( * )
     *             22: kFuncName: data_whatever: kUnknown: 22: count
     *              23: kIdentifier: data_functionName: kUnknown: 23: count
     * */



    vector<IR*> count_func_vec = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kFuncName, false);
    for (IR* count_func_ir : count_func_vec){

      // cerr << "Debug: norec get parent 1: " << ir_wrapper.get_parent_type_str(count_func_ir, 1) << "\n";
      // cerr << "Debug: norec get parent 2: " << ir_wrapper.get_parent_type_str(count_func_ir, 2) << "\n";
      // cerr << "Debug: norec get parent 3: " << ir_wrapper.get_parent_type_str(count_func_ir, 3) << "\n";
      // cerr << "Debug: norec get parent 4: " << ir_wrapper.get_parent_type_str(count_func_ir, 4) << "\n";
      // cerr << "Debug: norec get parent 5: " << ir_wrapper.get_parent_type_str(count_func_ir, 5) << "\n";
      // cerr << "Debug: norec get parent 6: " << ir_wrapper.get_parent_type_str(count_func_ir, 6) << "\n";
      // cerr << "Debug: norec get parent 7: " << ir_wrapper.get_parent_type_str(count_func_ir, 7) << "\n";
      // cerr << "Debug: norec get parent 8: " << ir_wrapper.get_parent_type_str(count_func_ir, 8) << "\n";

      if (
        ir_wrapper.get_parent_type_str(count_func_ir, 1) == "kFuncApplication" &&
        ir_wrapper.get_parent_type_str(count_func_ir, 2) == "kFuncExpr"  &&
        ir_wrapper.get_parent_type_str(count_func_ir, 3) == "kCExpr"  &&
        ir_wrapper.get_parent_type_str(count_func_ir, 4) == "kAExpr" &&
        ir_wrapper.get_parent_type_str(count_func_ir, 5) == "kTargetEl" &&
        ir_wrapper.get_parent_type_str(count_func_ir, 6) == "kTargetList" &&
        ir_wrapper.get_parent_type_str(count_func_ir, 7) == "kOptTargetList" &&
        ir_wrapper.get_parent_type_str(count_func_ir, 8) == "kSimpleSelect"
      ) {
        /* The Func expression structure is enforced. Next ensure the func is COUNT */
        IR* func_app_ir = count_func_ir->get_parent();
        // Enforce '*'
        if (!strcmp(func_app_ir->get_middle(), "( * )")) {
          IR* iden_ir = count_func_ir->get_left();
          // Enforce count.
          if (iden_ir &&
              (
                iden_ir->get_str_val() == "count" ||
                iden_ir->get_str_val() == "COUNT"
              )
          ) {
            // cerr << "For is_oracle stmt: " << cur_stmt->to_string() << "\n";
            // cerr << "is_oracle DEBUG: for where_clause, getting to_string(): " << where_clause->to_string() << "\n";
            // cerr << "size: " << ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kWhereClause, false).size() << "\n\n\n";
            // g_mutator->debug(cur_stmt, 0);
            // cerr << "\n\n\n";
            return true;
          }
        }
      }
    }
    // cerr << "Return false because of not found count (*) \n";
    // cerr << "stmt is: " << cur_stmt->to_string() << "\n\n\n";
    return false;
  }
  // cerr << "return false because not found from and where clause. \n";
  // cerr << "target_el: " << ir_wrapper.get_num_target_el_in_select_clause(cur_stmt) << "\n";
  return false;

}

bool SQL_NOREC::mark_all_valid_node(vector<IR *> &v_ir_collector) {
  // TODO:: FixLater
  return true;
}

vector<IR*> SQL_NOREC::post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id){
  vector<IR*> trans_IR_vec;

  cur_stmt->parent_ = NULL;

  /* Double check whether the stmt is norec compatible */
  if (!is_oracle_select_stmt(cur_stmt)) {
    return trans_IR_vec;
  }

  IR* first_stmt = cur_stmt->deep_copy();

  /* Remove the kOverClause, if exists.
   * Doesn't need to worry about double free, because all overclause that we remove
   * are not in subqueries.
   * */
  vector<IR* > v_over_clause = ir_wrapper.get_ir_node_in_stmt_with_type(first_stmt, kOverClause, false);

  if (v_over_clause.size() > 0) {
    IR* over_clause = v_over_clause.front();
    IR* new_over_clause = new IR(kOverClause, OP0());
    first_stmt->swap_node(over_clause, new_over_clause);
    over_clause->deep_drop();
  }

  /* Remove the kWindowClause, if exists.
   * Doesn't need to worry about double free, because all windowclause that we remove
   * are not in subqueries.
   * */
  vector<IR* > v_window_clause = ir_wrapper.get_ir_node_in_stmt_with_type(first_stmt, kWindowClause, false);
  if (v_window_clause.size() > 0) {
    IR* window_clause = v_window_clause.front();
    IR* new_window_clause = new IR(kWindowClause, OP0());
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

  is_oracle_select_stmt(cur_stmt);

  vector<IR*> transformed_temp_vec = g_mutator->parse_query_str_get_ir_set(this->post_fix_temp);
  if (transformed_temp_vec.size() == 0) {
    cerr << "Error: parsing the post_fix_temp from SQL_NOREC::post_fix_transform_select_stmt returns empty IR vector. \n";
    vector<IR*> tmp; return tmp;
  }

  IR* transformed_temp_ir = transformed_temp_vec.back();
  IR* trans_stmt_ir = ir_wrapper.get_first_stmt_from_root(transformed_temp_ir)->deep_copy();
  trans_stmt_ir->parent_ = NULL;
  transformed_temp_ir->deep_drop();

  /* Move the original ORDER BY function to the dest IR stmt. */
  vector<IR*> src_order_vec = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSortClause, false);
  if (src_order_vec.size() > 0) {
    IR* src_order_clause = src_order_vec[0]->deep_copy();
    IR* dest_order_clause = ir_wrapper.get_ir_node_in_stmt_with_type(trans_stmt_ir, kSortClause, true)[0];
    if (!trans_stmt_ir->swap_node(dest_order_clause, src_order_clause)){
      trans_stmt_ir->deep_drop();
      src_order_clause->deep_drop();
      cerr << "Error: swap_node failed for sort_clause. In function SQL_NOREC::post_fix_transform_select_stmt. \n";
      vector<IR*> tmp; return tmp;
    }
    dest_order_clause->deep_drop();
  } else {
    IR* dest_order_clause = ir_wrapper.get_ir_node_in_stmt_with_type(trans_stmt_ir, kSortClause, true)[0];
    trans_stmt_ir->detach_node(dest_order_clause);
    dest_order_clause->deep_drop();
  }

  IR* src_where_expr = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kWhereClause, false)[0]->get_left()->deep_copy();
  IR* dest_where_expr = ir_wrapper.get_ir_node_in_stmt_with_type(trans_stmt_ir, kAexprConst, true)[0];

  IR* src_from_expr = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kFromClause, false)[0]->deep_copy();
  IR* dest_from_expr = ir_wrapper.get_ir_node_in_stmt_with_type(trans_stmt_ir, kFromClause, true)[0];

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

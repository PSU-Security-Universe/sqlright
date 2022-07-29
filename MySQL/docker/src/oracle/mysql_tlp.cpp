#include "mysql_tlp.h"
#include "../include/mutate.h"
#include <iostream>
#include <chrono>

#include <regex>
#include <string>

bool SQL_TLP::is_oracle_select_stmt(IR* cur_stmt) {

  if (cur_stmt == NULL) {
    // cerr << "Return false because cur_stmt is NULL; \n";
    return false;
  }

  if (cur_stmt->get_ir_type() != kSelectStmt) {
    // cerr << "Return false because this is not a SELECT stmt: " << get_string_by_ir_type(cur_stmt->get_ir_type()) <<  " \n";
    return false;
  }

  if (!g_mutator->check_node_num(cur_stmt, 300)) {
    return false;
  }


  /* Remove cases that contains kGroupClause, kHavingClause and kLimitClause */
  // vector<IR*> v_group_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kGroupClause, false);
  // for (IR* group_clause : v_group_clause) {
  //   if (!group_clause->is_empty()){
  //     // cerr << "Return false because of GROUP clause \n";
  //     return false;
  //   }
  // }

  // vector<IR*> v_having_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kHavingClause, false);
  // for (IR* having_clause : v_having_clause) {
  //   if (!having_clause->is_empty()){
  //     // cerr << "Return false because of having clause \n";
  //     return false;
  //   }
  // }

  vector<IR*> v_limit_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kLimitClause, false);
  for (IR* limit_clause : v_limit_clause) {
    if (!limit_clause->is_empty()){
      // cerr << "Return false because of LIMIT clause \n";
      return false;
    }
  }

  v_limit_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOptSimpleLimit, false);
  for (IR* limit_clause : v_limit_clause) {
    if (!limit_clause->is_empty()){
      // cerr << "Return false because of LIMIT clause \n";
      return false;
    }
  }

  // Ignore stmts with UNION ALL, UNION, EXCEPT and INTERCEPT
  if (ir_wrapper.is_exist_set_operator(cur_stmt)) {
    return false;
  }

  if (ir_wrapper.is_exist_func_call_generic(cur_stmt)) {
    return false;
  }

  if (
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_stmt, kSelectStmt, false) &&
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_stmt, kFromClause, false) &&
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_stmt, kWhereClause, false) &&
    ir_wrapper.get_num_select_items_in_select_stmt(cur_stmt) == 1
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

    return true;
  }

  /* Cannot pass the test of kFromClause and kWhereClause. Not compatible.  */
  return false;

}


vector<IR*> SQL_TLP::post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id){
  vector<IR*> trans_IR_vec;
  cur_stmt->parent_ = NULL;

  /* If the original statement contains WINDOWING clause, remove it. 
  ** Windowing clause would cause FPs in the TLP oracle. 
  */
  vector<IR*> v_opt_windowing_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOptWindowingClause, false);
  for (IR* opt_windowing_clause : v_opt_windowing_clause) {
    if (opt_windowing_clause -> get_left() != NULL) {
      IR* windowing_clause = opt_windowing_clause->get_left();
      opt_windowing_clause->update_left(NULL);
      windowing_clause->deep_drop();
    }
  }

  /* Let's take care of the first stmt. Remove (the last?) its kWhereClause */
  IR* first_stmt = cur_stmt->deep_copy();
  vector<IR*> where_clause_in_first_vec = ir_wrapper.get_ir_node_in_stmt_with_type(first_stmt, kWhereClause, false);
  // for (IR* where_clause_in_first : where_clause_in_first_vec) {
  if (where_clause_in_first_vec.size() > 0 ) {
    IR* where_clause_in_first = where_clause_in_first_vec.back();
    first_stmt->detatch_node(where_clause_in_first);
    /* Should we directly deep_drop it? Seems fine */
    where_clause_in_first->deep_drop();
  } else {
    first_stmt->deep_drop();
    cerr << "Error: Failed to find kWhereClause in the original stmt.  \n\n\n";
    vector<IR*> tmp; return tmp;
  }
  trans_IR_vec.push_back(first_stmt); /* Save the first oracle stmt. */ 



  /* Construct the second SELECT oracle stmt.  */
  VALID_STMT_TYPE_TLP cur_stmt_TLP_type = get_stmt_TLP_type(cur_stmt);

  /* Ignore unknown cases. */
  if (cur_stmt_TLP_type == VALID_STMT_TYPE_TLP::TLP_UNKNOWN) {
    first_stmt->deep_drop();
    trans_IR_vec.clear();
    return trans_IR_vec;
  }

  switch (cur_stmt_TLP_type) {
    case VALID_STMT_TYPE_TLP::AGGR_AVG: 
    // case VALID_STMT_TYPE_TLP::AGGR_DISTINCT_AVG: 
    {
      IR* transformed_stmt = transform_aggr(cur_stmt, true, cur_stmt_TLP_type);
      trans_IR_vec.push_back(transformed_stmt);
    }
      break;
//    case VALID_STMT_TYPE_TLP::AGGR_COUNT: {
//      IR* transformed_stmt = transform_aggr(cur_stmt, true, cur_stmt_TLP_type);
//      trans_IR_vec.push_back(transformed_stmt);
//    }
//      break;
    // case VALID_STMT_TYPE_TLP::AGGR_DISTINCT_COUNT: {
//      IR* transformed_stmt = transform_aggr(cur_stmt, true, cur_stmt_TLP_type);
//      trans_IR_vec.push_back(transformed_stmt);
//    }
//      break;
    case VALID_STMT_TYPE_TLP::AGGR_MAX:
    [[fallthrough]];
    case VALID_STMT_TYPE_TLP::AGGR_DISTINCT_MAX: {
      IR* transformed_stmt = transform_aggr(cur_stmt, true, cur_stmt_TLP_type);
      trans_IR_vec.push_back(transformed_stmt);
    }
      break;
    case VALID_STMT_TYPE_TLP::AGGR_MIN: 
    [[fallthrough]];
    case VALID_STMT_TYPE_TLP::AGGR_DISTINCT_MIN: {
      IR* transformed_stmt = transform_aggr(cur_stmt, true, cur_stmt_TLP_type);
      trans_IR_vec.push_back(transformed_stmt);
    }
      break;
    case VALID_STMT_TYPE_TLP::AGGR_SUM:
    [[fallthrough]];
    case VALID_STMT_TYPE_TLP::AGGR_DISTINCT_SUM: {
      IR* transformed_stmt = transform_aggr(cur_stmt, true, cur_stmt_TLP_type);
      trans_IR_vec.push_back(transformed_stmt);
    }
      break;
    case VALID_STMT_TYPE_TLP::DISTINCT: {
      IR* transformed_stmt = transform_non_aggr(cur_stmt, false, cur_stmt_TLP_type);
      trans_IR_vec.push_back(transformed_stmt);
    }
      break;
    case VALID_STMT_TYPE_TLP::HAVING: {
      IR* transformed_stmt = transform_non_aggr(cur_stmt, true, cur_stmt_TLP_type);
      trans_IR_vec.push_back(transformed_stmt);
    }
      break;
    case VALID_STMT_TYPE_TLP::GROUP_BY: {
      IR* transformed_stmt = transform_non_aggr(cur_stmt, false, cur_stmt_TLP_type);
      trans_IR_vec.push_back(transformed_stmt);
    }
      break;
    case VALID_STMT_TYPE_TLP::NORMAL: {
      IR* transformed_stmt = transform_non_aggr(cur_stmt, true, cur_stmt_TLP_type);
      trans_IR_vec.push_back(transformed_stmt);
    }
      break;
    default:
      first_stmt->deep_drop();
      trans_IR_vec.clear();
      return trans_IR_vec;
  }
  if (trans_IR_vec[1] != NULL) {
    return trans_IR_vec;
  }
  else {
    // cerr << "Debug: for cur_stmt: " << cur_stmt->to_string() << ". Failed to transform. \n\n\n";
    first_stmt->deep_drop();
    trans_IR_vec.clear();
    return trans_IR_vec;
  }

}


bool SQL_TLP::compare_norm(COMP_RES &res) {

  string &res_a = res.res_str_0;
  string &res_b = res.res_str_1;
  int &res_a_int = res.res_int_0;
  int &res_b_int = res.res_int_1;

  if ( findStringIn(res_a, "ERROR") ||
       findStringIn(res_b, "ERROR")
      ) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  // Ignore outputs that returns no rows. Could due to MySQL errors. 
  if (is_str_empty(res_a) || is_str_empty(res_b) ) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  res_a_int = 0;
  res_b_int = 0;

  vector<string> v_res_a = string_splitter(res_a, '\n');
  vector<string> v_res_b = string_splitter(res_b, '\n');

  if (v_res_a.size() > 50 || v_res_b.size() > 50) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  /* Remove NULL results */
  for (string &r : v_res_a) {
    if (is_str_empty(r))
      res_a_int--;
  }

  for (string &r : v_res_b) {
    if (is_str_empty(r))
      res_b_int--;
  }

  v_res_a.clear();
  v_res_b.clear();

  res_a_int += std::count(res_a.begin(), res_a.end(), '\n');
  res_b_int += std::count(res_b.begin(), res_b.end(), '\n');

  /* For case that the first stmt return NULL, but the second stmt returns all 0. */
  if (res_a_int == 0) {
    bool is_all_zero = true;
    for (string& r : v_res_b) {
      if (r != "0") {
        is_all_zero = false;
        break;
      }
    }
    if (is_all_zero) {
      res.comp_res = ORA_COMP_RES::Pass;
      return false;
    }
  }

  if (res_a_int != res_b_int) { // Found inconsistent.
    // cerr << "NORMAL Found mismatched: " << "res_a: " << res_a << "res_b: " <<
    // res_b << " res_a_int: " << res_a_int << "res_b_int: " << res_b_int <<
    // endl;
    res.comp_res = ORA_COMP_RES::Fail;
    return false;
  }
  res.comp_res = ORA_COMP_RES::Pass;
  return false;
}

bool SQL_TLP::compare_uniq(COMP_RES &res) {

  string &res_a = res.res_str_0;
  string &res_b = res.res_str_1;
  int &res_a_int = res.res_int_0;
  int &res_b_int = res.res_int_1;

  if ( findStringIn(res_a, "ERROR") ||
       findStringIn(res_b, "ERROR")
      ) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  // Ignore outputs that returns no rows. Could due to MySQL errors. 
  if (is_str_empty(res_a) || is_str_empty(res_b) ) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  res_a_int = 0;
  res_b_int = 0;

  vector<string> v_res_a = string_splitter(res_a, '\n');
  vector<string> v_res_b = string_splitter(res_b, '\n');

  if (v_res_a.size() > 50 || v_res_b.size() > 50) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  set<string> uniq_rows;

  /* Remove NULL results */
  for (string &r : v_res_a) {
    if (is_str_empty(r)) {
      res_a_int--;
    } else if (uniq_rows.find(r) != uniq_rows.end()) {      /* Remove duplicated results. */
      res_a_int--;
    } else {
      uniq_rows.insert(r);
    }

  }
  uniq_rows.clear();

  for (string &r : v_res_b) {
    if (is_str_empty(r)) {
      res_b_int--;
    } else if (uniq_rows.find(r) != uniq_rows.end()) {      /* Remove duplicated results. */
      res_b_int--;
    } else {
      uniq_rows.insert(r);
    }

  }
  uniq_rows.clear();

  res_a_int += std::count(res_a.begin(), res_a.end(), '\n');
  res_b_int += std::count(res_b.begin(), res_b.end(), '\n');

  /* For case that the first stmt return NULL, but the second stmt returns all 0. */
  if (res_a_int == 0) {
    bool is_all_zero = true;
    for (string& r : v_res_b) {
      if (r != "0") {
        is_all_zero = false;
        break;
      }
    }
    if (is_all_zero) {
      res.comp_res = ORA_COMP_RES::Pass;
      return false;
    }
  }

  if (res_a_int != res_b_int) { // Found inconsistent.
    // cerr << "NORMAL Found mismatched: " << "res_a: " << res_a << "res_b: " <<
    // res_b << " res_a_int: " << res_a_int << "res_b_int: " << res_b_int <<
    // endl;
    res.comp_res = ORA_COMP_RES::Fail;
    return false;
  }
  res.comp_res = ORA_COMP_RES::Pass;
  return false;
}

/* Handle MIN valid stmt: SELECT MIN(*) FROM ...; and MAX valid stmt: SELECT
 * MAX(*) FROM ...;  */
bool SQL_TLP::compare_aggr(COMP_RES &res) {
  string &res_a = res.res_str_0;
  string &res_b = res.res_str_1;
  int &res_a_int = res.res_int_0;
  int &res_b_int = res.res_int_1;

  if ( findStringIn(res_a, "ERROR") ||
       findStringIn(res_b, "ERROR")
      ) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  // Ignore outputs that returns no rows. Could due to MySQL errors. 
  if (is_str_empty(res_a) || is_str_empty(res_b) ) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }

  try {
    res_a_int = stoi(res.res_str_0);
    res_b_int = stoi(res.res_str_1);
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

  if (res_a_int != res_b_int) {
    res.comp_res = ORA_COMP_RES::Fail;
  } else {
    res.comp_res = ORA_COMP_RES::Pass;
  }

  return false;
}


void SQL_TLP::compare_results(ALL_COMP_RES &res_out) {

  res_out.final_res = ORA_COMP_RES::Pass;
  bool is_all_err = true;

  vector<VALID_STMT_TYPE_TLP> v_valid_type;
  get_v_valid_type(res_out.cmd_str, v_valid_type);

  if (v_valid_type.size() != res_out.v_res.size()) {
    cerr << "Error: In oracle TLP, v_valid_type.size() is not equals to res_out.v_res.size(). Returns ALL_ERRORS. \n\n\n";
    for (COMP_RES &res : res_out.v_res) {
      res.comp_res = ORA_COMP_RES::Error;
      res.res_int_0 = -1;
      res.res_int_1 = -1;
    }
    res_out.final_res = ORA_COMP_RES::ALL_Error;
    return;
  }

  int i = 0;
  for (COMP_RES &res : res_out.v_res) {
    switch (v_valid_type[i++]) {
      case VALID_STMT_TYPE_TLP::NORMAL:
        /* Handle normal valid stmt: SELECT * FROM ...; */
        if (!compare_norm(res))
          {is_all_err = false;}
        break; // Break the switch

      /* Compare unique results */
      case VALID_STMT_TYPE_TLP::DISTINCT:
        [[fallthrough]];
      case VALID_STMT_TYPE_TLP::GROUP_BY:
        compare_uniq(res);
        break;

      /* Compare concret values */
      case VALID_STMT_TYPE_TLP::AGGR_AVG:
        [[fallthrough]];
    //   case VALID_STMT_TYPE_TLP::AGGR_AVG:
    //     [[fallthrough]];
      // case VALID_STMT_TYPE_TLP::AGGR_COUNT:
      //   [[fallthrough]];
      case VALID_STMT_TYPE_TLP::AGGR_MAX:
        [[fallthrough]];
      case VALID_STMT_TYPE_TLP::AGGR_DISTINCT_MAX:
        [[fallthrough]];
      case VALID_STMT_TYPE_TLP::AGGR_MIN:
        [[fallthrough]];
      case VALID_STMT_TYPE_TLP::AGGR_DISTINCT_MIN:
        [[fallthrough]];
      case VALID_STMT_TYPE_TLP::AGGR_SUM:
        if (!compare_aggr(res))
          {is_all_err = false;}
        break; // Break the switch

      default:
        res.comp_res = ORA_COMP_RES::Error;
        break;
    } // Switch stmt.
    if (res.comp_res == ORA_COMP_RES::Fail)
      {res_out.final_res = ORA_COMP_RES::Fail;}
  } // Result outer loop.

  if (is_all_err && res_out.final_res != ORA_COMP_RES::Fail)
    res_out.final_res = ORA_COMP_RES::ALL_Error;


  return;
}

void SQL_TLP::get_v_valid_type(const string &cmd_str,
                               vector<VALID_STMT_TYPE_TLP> &v_valid_type) {
  /* Look throught first validation stmt's result_1 first */
  size_t begin_idx = cmd_str.find("SELECT 'BEGIN VERI 0';", 0);
  size_t end_idx = cmd_str.find("SELECT 'END VERI 0';", 0);

  while (begin_idx != string::npos) {
    if (end_idx != string::npos) {
      string cur_cmd_str =
          cmd_str.substr(begin_idx + 23, (end_idx - begin_idx - 23));
      begin_idx = cmd_str.find("SELECT 'BEGIN VERI 0';", begin_idx + 23);
      end_idx = cmd_str.find("SELECT 'END VERI 0';", end_idx + 21);

      vector<IR*> v_cur_stmt_ir;
      int ret = run_parser_multi_stmt(cur_cmd_str, v_cur_stmt_ir);
      if ( ret != 0 || v_cur_stmt_ir.size() == 0 ) {
        continue;
      }
      if ( v_cur_stmt_ir.back()->left_ == NULL || v_cur_stmt_ir.back()->left_->left_ == NULL ) {
        v_cur_stmt_ir.back()->deep_drop();
        continue;
      }
      
      vector<IR*> cur_stmt_ir_vec = ir_wrapper.get_stmt_ir_vec(v_cur_stmt_ir.back());
      if (cur_stmt_ir_vec.size() == 0 ) {
          v_cur_stmt_ir.back()->deep_drop();
      }
      IR* cur_stmt_ir = cur_stmt_ir_vec.front();

      v_valid_type.push_back(get_stmt_TLP_type(cur_stmt_ir));

      v_cur_stmt_ir.back()->deep_drop();

    } else {
      // cerr << "Error: For the current begin_idx, we cannot find the end_idx. \n\n\n";
      break; // For the current begin_idx, we cannot find the end_idx. Ignore
             // the current output.
    }
  }
}


VALID_STMT_TYPE_TLP SQL_TLP::get_stmt_TLP_type (IR* cur_stmt) {
  VALID_STMT_TYPE_TLP default_type_ = VALID_STMT_TYPE_TLP::NORMAL;

  /* Distince first situation: in distinct_clause.  */
  vector<IR*> v_distinct_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOptDistinct, false);
  for (IR* distinct_clause : v_distinct_clause) {
      if ( distinct_clause && !distinct_clause->is_empty()) {
        default_type_ = VALID_STMT_TYPE_TLP::DISTINCT;
      }
  }
  v_distinct_clause.clear();

  /* Has GROUP BY clause.  */
  vector<IR*> v_group_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOptGroupClause, false);
  for (IR* group_clause : v_group_clause) {
    if ( group_clause && !group_clause->is_empty() ) {
      default_type_ = VALID_STMT_TYPE_TLP::GROUP_BY;
    }
  }

  /* Ignore having. Treat it as normal, or other type if other elements are evolved. */

  /* TODO:: Here we want to restrict the SELECT target to have only one targetel. Fix it later.  */
  // vector<IR*> v_result_column_list = ir_wrapper.get_result_column_list_in_select_clause(cur_stmt);
  // if (v_result_column_list.size() == 0) {
  //   return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
  // }


  vector<IR*> sum_func_vec = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSumExpr, false);

  /* TODO:: Ignore cases like SELECT COUNT() FROM v0; */

  for (IR* sum_func_ir : sum_func_vec){

    if (
        ir_wrapper.is_ir_in(sum_func_ir, kSelectItem)
    ) {
      string func_name_str = sum_func_ir->get_prefix();

      if (func_name_str == "COUNT(") {

        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_COUNT;

      } else if (func_name_str == "COUNT(DISTINCT") {

        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_DISTINCT_COUNT;

      } else if (func_name_str == "SUM(") {

        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_SUM;
      } else if (func_name_str == "SUM(DISTINCT") {

        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_DISTINCT_SUM;

      } else if (func_name_str == "MIN(") {

        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_MIN;

      } else if (func_name_str == "MIN(DISTINCT") {

        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_DISTINCT_MIN;

      } else if (func_name_str == "MAX(") {
        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_MAX;

      } else if (func_name_str == "MAX(DISTINCT") {
        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_DISTINCT_MAX;

      } else if (func_name_str == "AVG(") {
        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_AVG;

      } else if (func_name_str == "AVG( DISTINCT") {
        if (default_type_ == VALID_STMT_TYPE_TLP::GROUP_BY) {
          return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
        }
        return VALID_STMT_TYPE_TLP::AGGR_DISTINCT_AVG;
      } else {
        return VALID_STMT_TYPE_TLP::TLP_UNKNOWN;
      }
    }
  }

  return default_type_;

}

IR* SQL_TLP::transform_non_aggr(IR* cur_stmt, bool is_UNION_ALL, VALID_STMT_TYPE_TLP tlp_type) {

  /* Retrive the kSimpleSelect, that is used to construct the TLP stmt. */
  vector<IR*> src_simple_select_vec_ = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSelectStmt, false);
  if (src_simple_select_vec_.size() == 0) {
    cerr << "Error: Failed to detect the kSelectStmt node from the mutated oracle select stmt. Return failure. \n\n\n";
    return NULL;
  }

  /* Remove the WINDOWING function from each statement. */
  vector<IR*> v_opt_windowing_clause = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOptWindowingClause, false);
  for (IR* opt_windowing_clause : v_opt_windowing_clause) {
    if (opt_windowing_clause -> get_left() != NULL) {
      IR* windowing_clause = opt_windowing_clause->get_left();
      opt_windowing_clause->update_left(NULL);
      windowing_clause->deep_drop();
    }
  }

  /* If the logic has no error, should always pick the first one. Deep copid on every used. */
  IR* src_simple_select_ = src_simple_select_vec_[0];
  /* Now we have the simple_select. :-) */

  /* modify the first part of TLP. Put the Whereclause into a brackets. */
  IR* operand_ir_ = new IR(kSimpleExpr, OP3("(", ")", ""));
  IR* expr_ir_ = new IR(kExpr, OP3("", "", ""), operand_ir_);

  IR* first_part_TLP = src_simple_select_->deep_copy();
  vector<IR*> v_where_first_stmt = ir_wrapper.get_ir_node_in_stmt_with_type(first_part_TLP, kWhereClause, false);
  if (v_where_first_stmt.size() == 0) {
    expr_ir_->deep_drop();
    first_part_TLP->deep_drop();
    cerr << "Error: Failed to detect the kWhereClause node from the mutated oracle select stmt. Return failure. \n\n\n";
    return NULL;
  }
  IR* where_first_stmt_ = v_where_first_stmt[0];
  if (where_first_stmt_->is_empty()) {
    first_part_TLP->deep_drop();
    expr_ir_->deep_drop();
    cerr << "Error: The retrived where_first_stmt_ doesn't have the left_ child node. \n\n\n";
    return NULL;
  }
  IR* where_first_expr_ = where_first_stmt_->get_left();

  /* Swap the original where expr to the newly created expr_ir_ node, and attach the expr
   * we need into it.
   * */
  first_part_TLP->swap_node(where_first_expr_, expr_ir_);
  operand_ir_->update_left(where_first_expr_);

  /* Finished the first TLP part.  */

  /* Modify the second part of TLP. Pu the Whereclause into (Not (kWhereClause)) */
  IR* operand_0 = new IR(kSimpleExpr, OP3("(", ")", "")); // For brackets
  IR* unary_expr_ = new IR(kExpr, OP3("NOT", "", ""), operand_0); // NOT (kWhereClause)
  IR* operand_1 = new IR(kSimpleExpr, OP3("(", ")", ""), unary_expr_); // For the second brackets. (NOT (kWhereClause))
  IR* expr_ = new IR(kSimpleExpr, OP0(), operand_1);

  IR* second_part_TLP = src_simple_select_->deep_copy();
  /* vector size has been double checked before */
  IR* where_second_stmt_ = ir_wrapper.get_ir_node_in_stmt_with_type(second_part_TLP, kWhereClause, false)[0];
  IR* where_second_expr_ = where_second_stmt_->left_;

  second_part_TLP->swap_node(where_second_expr_, expr_);
  operand_0->update_left(where_second_expr_);

  /* Finished the second part TLP */


  /* Modify the third part of TLP. Put the WhereClause into ((kWhereClause) IS NULL) */
  operand_0 = new IR(kSimpleExpr, OP3("(", ")", "")); // For brackets
  unary_expr_ = new IR(kExpr, OP3("", "IS NULL", ""), operand_0); // (kWhereClause) IS NULL
  operand_1 = new IR(kSimpleExpr, OP3("(", ")", ""), unary_expr_); // For the second brackets. ((kWhereClause) IS NULL)
  expr_ = new IR(kExpr, OP0(), operand_1);

  IR* third_part_TLP = src_simple_select_->deep_copy();
  /* vector size has been double checked before */
  IR* where_third_stmt_ = ir_wrapper.get_ir_node_in_stmt_with_type(third_part_TLP, kWhereClause, false)[0];
  IR* where_third_expr_ = where_third_stmt_->left_;

  third_part_TLP->swap_node(where_third_expr_, expr_);
  operand_0->update_left(where_third_expr_);

  /* Finished the third part TLP.  */
  cur_stmt = first_part_TLP;
  if (is_UNION_ALL) {
    IR* set_operator = new IR(kUnknown, OP3("", "UNION ALL", ""), second_part_TLP, third_part_TLP);
    set_operator = new IR(kUnknown, OP3("", "UNION ALL", ""), first_part_TLP, set_operator);
    cur_stmt = set_operator;
  } else {
    IR* set_operator = new IR(kUnknown, OP3("", "UNION", ""), second_part_TLP, third_part_TLP);
    set_operator = new IR(kUnknown, OP3("", "UNION", ""), first_part_TLP, set_operator);
    cur_stmt = set_operator;
  }

  return cur_stmt;
}


/*
** Transform original stmt to TLP form. This function is used for SELECT stmt WITH aggregate functions
** in the SELECT clause.
** cur_stmt need to be freed outside this function.
*/

IR* SQL_TLP::transform_aggr(IR* cur_stmt, bool is_UNION_ALL, VALID_STMT_TYPE_TLP tlp_type) {

  cur_stmt = cur_stmt->deep_copy();

  vector<IR*> v_aggr_func_ir = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSumExpr, false);
  if (v_aggr_func_ir.size() == 0) {
    cur_stmt->deep_drop();
    // cerr << "Error: In SQL_TLP::transform_aggr, cannot find kFuncName. \n";
    return NULL;
  }

  IR* aggr_func_ir = v_aggr_func_ir.front();

  if (aggr_func_ir->get_left() == NULL) {
    cerr << "ERROR: In transform_aggr, the kFuncName IR doesn't have the left sub-node. \n";
    cur_stmt->deep_drop();
    return NULL;
  }

  if (
    // tlp_type == VALID_STMT_TYPE_TLP::AGGR_COUNT ||
    tlp_type == VALID_STMT_TYPE_TLP::AGGR_SUM ||
    tlp_type == VALID_STMT_TYPE_TLP::AGGR_MAX ||
    tlp_type == VALID_STMT_TYPE_TLP::AGGR_MIN
  ) {

    /* First of all, check whether there is existing alias name in the stmt */
    vector<IR*> v_select_alias = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSelectAlias, false);
    if (v_select_alias.size() > 0) {
      IR* select_alias_ir = v_select_alias.front();
      if (!select_alias_ir->is_empty()) {
        /* Found the originally existed matching alias. Change it to aggr*/
        IR* iden = select_alias_ir->get_left();
        iden -> set_str_val(string("aggr"));
      }

      // We found v_select_alis, but it is empty. Fill in our own. 
      else {
        IR* new_alias_iden = new IR(kIdentifier, string("AS aggr")); // This is postfix, do not need to worry about validate fixing. 
        select_alias_ir->update_left(new_alias_iden);
      }
    } 
    else {
      // If we cannot find select_alias. Create our own and insert. 
      IR* new_alias_iden = new IR(kIdentifier, string("AS aggr"));

      vector<IR*> v_select_item = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSelectItem, false);
      if (v_select_item.size() != 1) {
        new_alias_iden->deep_drop();
        cur_stmt->deep_drop();
        return NULL;
      }
      IR* cur_select_item = v_select_item.front();
      if (!cur_select_item->get_right()) {
        new_alias_iden->deep_drop();
        cur_stmt->deep_drop();
        return NULL;
      }
      cur_select_item->update_right(new_alias_iden);

    }

// If it is a aggregate SUM/MIN/MAX function select, we finished adding alias in the logic above. 

  } else {
    /* Fix for VALID_STMT_TYPE_TLP::AGGR_AVG */
    /* First of all, check whether there is existing alias name in the stmt */
    // Change the original SELECT AVG(c1) ... to SELECT SUM(c1), COUNT(c1) ...
    vector<IR*> v_select_item = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kSelectItem, false);
    if (v_select_item.size() != 1) {
      cur_stmt->deep_drop();
      return NULL;
    }

    IR* select_item_ir = v_select_item.front();
    vector<IR*> v_func_name_ir = ir_wrapper.get_ir_node_in_stmt_with_type(select_item_ir, kSumExpr, false);
    if (v_func_name_ir.size() == 0 ){
      cerr << "Error: Cannot find kFuncName inside kTargetEl. TLP oracle logic error. \n";
      cur_stmt->deep_drop();
      return NULL;
    }
    IR* func_name_ir = v_func_name_ir.front();

    IR *alias_id_0 = new IR(kIdentifier, string("AS s"), kDataAliasName, 0, kDefine);
    IR *alias_id_1 = new IR(kIdentifier, string("AS c"), kDataAliasName, 0, kDefine);\

    IR* new_func_name_ir_0 = func_name_ir->deep_copy();
    IR* new_func_name_ir_1 = func_name_ir->deep_copy();
    if (new_func_name_ir_0->get_str_val() == "AVG(") {
      new_func_name_ir_0->set_str_val("SUM(");
      new_func_name_ir_1->set_str_val("COUNT(");
    } else if (new_func_name_ir_0->get_str_val() == "AVG( DISTINCT") {
      new_func_name_ir_0->set_str_val("SUM(DISTINCT");
      new_func_name_ir_1->set_str_val("COUNT(DISTINCT");
    } else {
      cur_stmt->deep_drop();
      return NULL;
    }

    IR* new_select_item_0 = new IR(kSelectItem, OP0(), new_func_name_ir_0, alias_id_0);
    IR* new_select_item_1 = new IR(kSelectItem, OP0(), new_func_name_ir_1, alias_id_1);

    IR* new_select_item_list = new IR(kSelectItemList, OP3("", ",", ""), new_select_item_0, new_select_item_1);

    cur_stmt->swap_node(select_item_ir, new_select_item_list);

    /* Fix for aggregate function AVG completed. */
  }

  IR* cur_stmt_inner = transform_non_aggr(cur_stmt, is_UNION_ALL, tlp_type);
  /* Finished generating inner stmt. Deep drop. */
  cur_stmt->deep_drop();

   /* Fill in SELECT AGGR(aggr) from (inner stmt) */
  IR* cur_stmt_outer;
  int ret = 0;
  vector<IR*> v_outer_stmt_ir_vec;
  if (tlp_type == VALID_STMT_TYPE_TLP::AGGR_SUM) {
    ret = run_parser_multi_stmt(this->trans_outer_SUM_tmp_str, v_outer_stmt_ir_vec);
    if (ret != 0 || v_outer_stmt_ir_vec.size() == 0) {
      cur_stmt_inner->deep_drop();
      return NULL;
    }
    cur_stmt_outer = v_outer_stmt_ir_vec.back();
  } else if (tlp_type == VALID_STMT_TYPE_TLP::AGGR_DISTINCT_SUM) {
    ret = run_parser_multi_stmt(this->trans_outer_SUM_DISTINCT_tmp_str, v_outer_stmt_ir_vec);
    if (ret != 0 || v_outer_stmt_ir_vec.size() == 0) {
      cur_stmt_inner->deep_drop();
      return NULL;
    }
    cur_stmt_outer = v_outer_stmt_ir_vec.back();
  } else if (tlp_type == VALID_STMT_TYPE_TLP::AGGR_MIN) {
    ret = run_parser_multi_stmt(this->trans_outer_MIN_tmp_str, v_outer_stmt_ir_vec);
    if (ret != 0 || v_outer_stmt_ir_vec.size() == 0) {
      cur_stmt_inner->deep_drop();
      return NULL;
    }
    cur_stmt_outer = v_outer_stmt_ir_vec.back();
  } else if (tlp_type == VALID_STMT_TYPE_TLP::AGGR_DISTINCT_MIN) {
    ret = run_parser_multi_stmt(this->trans_outer_MIN_DISTINCT_tmp_str, v_outer_stmt_ir_vec);
    if (ret != 0 || v_outer_stmt_ir_vec.size() == 0) {
      cur_stmt_inner->deep_drop();
      return NULL;
    }
    cur_stmt_outer = v_outer_stmt_ir_vec.back();
  } else if (tlp_type == VALID_STMT_TYPE_TLP::AGGR_MAX) {
    ret = run_parser_multi_stmt(this->trans_outer_MAX_tmp_str, v_outer_stmt_ir_vec);
    if (ret != 0 || v_outer_stmt_ir_vec.size() == 0) {
      cur_stmt_inner->deep_drop();
      return NULL;
    }
    cur_stmt_outer = v_outer_stmt_ir_vec.back();
  } else if (tlp_type == VALID_STMT_TYPE_TLP::AGGR_DISTINCT_MAX) {
    ret = run_parser_multi_stmt(this->trans_outer_MAX_DISTINCT_tmp_str, v_outer_stmt_ir_vec);
    if (ret != 0 || v_outer_stmt_ir_vec.size() == 0) {
      cur_stmt_inner->deep_drop();
      return NULL;
    }
    cur_stmt_outer = v_outer_stmt_ir_vec.back();
  } else if (tlp_type == VALID_STMT_TYPE_TLP::AGGR_AVG) {
    ret = run_parser_multi_stmt(this->trans_outer_AVG_tmp_str, v_outer_stmt_ir_vec);
    if (ret != 0 || v_outer_stmt_ir_vec.size() == 0) {
      cur_stmt_inner->deep_drop();
      return NULL;
    }
    cur_stmt_outer = v_outer_stmt_ir_vec.back();
  } else if (tlp_type == VALID_STMT_TYPE_TLP::AGGR_DISTINCT_AVG) {
    ret = run_parser_multi_stmt(this->trans_outer_AVG_DISTINCT_tmp_str, v_outer_stmt_ir_vec);
    if (ret != 0 || v_outer_stmt_ir_vec.size() == 0) {
      cur_stmt_inner->deep_drop();
      return NULL;
    }
    cur_stmt_outer = v_outer_stmt_ir_vec.back();
  }

  IR* ori_outer_expr = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt_outer, kQueryExpression, true).front();

  cur_stmt_outer->swap_node(ori_outer_expr, cur_stmt_inner);
  ori_outer_expr->deep_drop();

  return cur_stmt_outer;

}

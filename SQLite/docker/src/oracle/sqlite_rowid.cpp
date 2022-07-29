#include "./sqlite_rowid.h"
#include "../include/mutator.h"
#include <iostream>

#include <regex>
#include <string>

bool SQL_ROWID::mark_all_valid_node(vector<IR *> &v_ir_collector) {
  return true;
}

void SQL_ROWID::get_v_valid_type(const string &cmd_str,
                                 vector<VALID_STMT_TYPE_ROWID> &v_valid_type) {
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
      v_valid_type.push_back(get_stmt_ROWID_type(cur_stmt_ir));

      v_cur_stmt_ir.back()->deep_drop();

    } else {
      // cerr << "Error: For the current begin_idx, we cannot find the end_idx. \n\n\n";
      break; // For the current begin_idx, we cannot find the end_idx. Ignore
             // the current output.
    }
  }
}

void SQL_ROWID::compare_results(ALL_COMP_RES &res_out) {
  if ((res_out.v_cmd_str.size() < 1) || (res_out.v_res_str.size() < 1)) {
    cerr << "Error: Getting empty v_cmd_str or v_res_str from the res_out. Actual size for v_res_str is: " \
         << to_string(res_out.v_res_str.size()) << \
            ". Possibly processing only the seed files. \n";
    res_out.final_res = ALL_Error;
    return;
  }

  /* If we detect NOT NULL or Datatype Mismatch in the res_str. Do not compare
   * and return All_Error directly. */
  for (const string &cur_res_str : res_out.v_res_str) {
    if (is_str_error(cur_res_str)) {
      for (COMP_RES &res : res_out.v_res) {
        res.comp_res = ORA_COMP_RES::Error;
      }
      res_out.final_res = ALL_Error;
      return;
    }
  }

  res_out.final_res = Pass;

  vector<VALID_STMT_TYPE_ROWID> v_valid_type;
  get_v_valid_type(res_out.v_cmd_str[0], v_valid_type);

  bool is_all_errors = true;
  int i = 0;
  for (COMP_RES &res : res_out.v_res) {
    if (i >= v_valid_type.size()) {
      res.comp_res = ORA_COMP_RES::Error;
      break; // break the loop
    }
    switch (v_valid_type[i++]) {
    case VALID_STMT_TYPE_ROWID::NORMAL:
      if (!this->compare_norm(res))
        is_all_errors = false;
      break; // break the switch

    case VALID_STMT_TYPE_ROWID::AGGR:
      if (!this->compare_aggr(res))
        is_all_errors = false;
      break; // break the switch
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

bool SQL_ROWID::compare_norm(COMP_RES &res) { /* Handle normal valid stmt: SELECT * FROM ...; Return is_err */
  if (res.v_res_str.size() <= 1) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }
  vector<string> &v_res_str = res.v_res_str;
  vector<int> &v_res_int = res.v_res_int;

  for (const string &res_str : v_res_str) {
    if (findStringIn(res_str, "error")) {
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

bool SQL_ROWID::compare_aggr(COMP_RES &res) {
  if (res.v_res_str.size() <= 1) {
    res.comp_res = ORA_COMP_RES::Error;
    return true;
  }
  vector<string> &v_res_str = res.v_res_str;

  for (int i = 0; i < v_res_str.size(); i++) {
    if (
      findStringIn(res.v_res_str[0], "error") || 
      findStringIn(res.v_res_str[i], "error")
    ) {
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

bool SQL_ROWID::is_str_error(const string &input_str) {

  // check whether if 'Error:' exists in input_str
  if (input_str.find("Error") != string::npos) {

    /* check if this is a known error string. */
    if (input_str.find("NOT NULL") != string::npos ||  // For PRIMARY KEY column, we cannot add NULL values into it.  
        input_str.find("datatype mismatch") != string::npos) {  // For WITHOUT ROWID PRIMARY KEY column, the only accepted data type is INTEGER

      // It's a known error string. Return Error. Give up the current results. 
      return true;
    }
  }

  // not a error string.
  return false;
}


bool SQL_ROWID::is_oracle_normal_stmt(IR* cur_IR) {
  if (
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_IR, kCreateTableStatement, false) ||
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_IR, kCreateVirtualTableStatement, false)
    ) {
    return true;
  }
  return false;
}

bool SQL_ROWID::is_oracle_select_stmt(IR* cur_IR) {
  /* Limit only ONE parameter in the aggregate function. */
  vector<IR*> v_result_column_list = ir_wrapper.get_result_column_list_in_select_clause(cur_IR);
  if (v_result_column_list.size() != 0) {
    vector<IR*> v_aggr_func_ir = ir_wrapper.get_ir_node_in_stmt_with_type(v_result_column_list[0], kFunctionName, false);
    if (v_aggr_func_ir.size() != 0) {
      IR* func_aggr_ir = v_aggr_func_ir[0] -> parent_ ->right_; // func_name -> unknown -> kfuncargs
      if (func_aggr_ir -> type_ == kFunctionArgs && func_aggr_ir -> right_ != NULL && func_aggr_ir ->right_ -> type_ == kExprList) {
        /* If the stmt has multiple expr_list inside the func_args, ignore current stmt. */
        if (func_aggr_ir->right_->right_ != NULL) {// Another kExprList.
          return false;
        }
      }
    }
  }

  if (
    cur_IR->type_ == kSelectStatement 
  ) {
    return true;
  }
  return false;
}

IR* SQL_ROWID::pre_fix_transform_normal_stmt(IR* cur_stmt) {
  if (!this->is_oracle_normal_stmt(cur_stmt)) {
    cerr << "Error: Detected input stmt is not oracle normal statement. Func: SQL_ROWID::pre_fix_transform_normal_stmt. \n";
    return nullptr;
  }
  cur_stmt = cur_stmt->deep_copy();

  bool is_exist_WITHOUT_ROWID = false;
  vector<IR*> v_opt_without_rowid_ir = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOptWithoutRowID, false);
  for (IR* opt_without_rowid : v_opt_without_rowid_ir) {
    if (opt_without_rowid->op_ && opt_without_rowid->op_->prefix_ &&
        strcmp(opt_without_rowid->op_->prefix_, "WITHOUT ROWID") == 0) {
      is_exist_WITHOUT_ROWID = true;
    }
  }
  // Insert WIHTOUT ROWID symbol. If is_exist_WIHTOUT_ROWID, then ignore the insertion. 
  if(!is_exist_WITHOUT_ROWID && !ir_wrapper.add_without_rowid_to_stmt(cur_stmt)) {
    cerr << "Error: add_without_rowid_to_stmt failed. Func: SQL_ROWID::pre_fix_transform_normal_stmt. \n";
    cur_stmt->deep_drop();
    return nullptr;
  }

  /* Check whether there are PRAIMRY KEY inside the defined column  
  ** Two situations, kColumnConstraint and kTableConstraint
  */
  vector<IR*> v_column_constraints_exist = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kColumnConstraint, false);
  for( IR* cur_column_constraints_exist : v_column_constraints_exist) {
    if (cur_column_constraints_exist->op_ != NULL && cur_column_constraints_exist->op_->prefix_ &&
        strcmp(cur_column_constraints_exist->op_->prefix_, "PRIMARY KEY") == 0) {
      return cur_stmt;
    }
  }

  vector<IR*> v_table_constraint_exist = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kTableConstraint, false);
  for ( IR* cur_table_constraint_exist : v_table_constraint_exist ) {
    if (cur_table_constraint_exist-> left_ != NULL &&
      cur_table_constraint_exist->left_->op_ != NULL && cur_table_constraint_exist->left_->op_->prefix_ &&
      strcmp(cur_table_constraint_exist->left_->op_->prefix_, "PRIMARY KEY (") == 0
      ) {
        return cur_stmt;
    }
  }


  // Arbitarily insert PRIMARY KEY. (Replaced the old column constraints)
  vector<IR*> opt_column_constraintlist_vec = ir_wrapper.get_ir_node_in_stmt_with_type(cur_stmt, kOptColumnConstraintlist, false);
  if (opt_column_constraintlist_vec.size() == 0) {
    cur_stmt->deep_drop();
    return nullptr;
  }
  IR* chosen_opt_column_constraintlist = opt_column_constraintlist_vec[get_rand_int(opt_column_constraintlist_vec.size())];

  IR* opt_order_type_ir = new IR(kOptOrderType, "");
  IR* opt_conflict_clause = new IR(kOptConflictClause, string(""));
  IR* column_constraint = new IR(kColumnConstraint, OP1("PRIMARY KEY"), opt_order_type_ir, opt_conflict_clause);

  IR* opt_auto_inc = new IR(kOptAutoinc, "");
  column_constraint = new IR(kColumnConstraint, OP0(), column_constraint, opt_auto_inc); 

  IR* column_constraint_list = new IR(kColumnConstraintlist, OP0(), column_constraint);
  IR* new_opt_column_constraint_list = new IR(kOptColumnConstraintlist, OP0(), column_constraint_list);

  cur_stmt->swap_node(chosen_opt_column_constraintlist, new_opt_column_constraint_list);
  chosen_opt_column_constraintlist->deep_drop();

  return cur_stmt;
}

vector<IR*> SQL_ROWID::post_fix_transform_normal_stmt(IR* cur_stmt, unsigned multi_run_id) {
  if (multi_run_id == 0) {vector<IR*> v_ret; v_ret.push_back(cur_stmt->deep_copy()); return v_ret;} // If it is the first run. Do not remove WITHOUT ROWID.
  cur_stmt = cur_stmt->deep_copy();
  if(!ir_wrapper.remove_without_rowid_to_stmt(cur_stmt)) {
    cerr << "Error: remove_without_rowid_to_stmt failed. Func: SQL_ROWID::post_fix_transform_normal_stmt. \n";
    cur_stmt->deep_drop();
    vector<IR*> tmp; return tmp;
  }
  /* Do we want to remove PRIMARY KEY constraints to the column too? */
  vector<IR*> output_stmt;
  output_stmt.push_back(cur_stmt);
  return output_stmt;
}


VALID_STMT_TYPE_ROWID SQL_ROWID::get_stmt_ROWID_type (IR* cur_stmt) {
  VALID_STMT_TYPE_ROWID default_type_ = VALID_STMT_TYPE_ROWID::NORMAL;

  vector<IR*> v_result_column_list = ir_wrapper.get_result_column_list_in_select_clause(cur_stmt);
  if (v_result_column_list.size() == 0) {
    return VALID_STMT_TYPE_ROWID::ROWID_UNKNOWN;
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
      return VALID_STMT_TYPE_ROWID::AGGR;
    } else if (findStringIn(aggr_func_str, "MAX")){
      return VALID_STMT_TYPE_ROWID::AGGR;
    } else if (findStringIn(aggr_func_str, "COUNT")){
      return VALID_STMT_TYPE_ROWID::AGGR;
    } else if (findStringIn(aggr_func_str, "SUM")) {
      return VALID_STMT_TYPE_ROWID::AGGR;
    } else if (findStringIn(aggr_func_str, "AVG")) {
      return VALID_STMT_TYPE_ROWID::AGGR;
    }
  }

  return default_type_;

}

vector<IR*> SQL_ROWID::post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) {
  vector<IR*> ret_stmts;
  ret_stmts.push_back(cur_stmt->deep_copy());
  return ret_stmts;
}

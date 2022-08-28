#include "./sqlite_opt.h"
#include "../include/mutator.h"
#include <iostream>

#include <fstream> // Debug purpose. 

#include <regex>
#include <string>

bool SQL_OPT::mark_all_valid_node(vector<IR *> &v_ir_collector) {
  bool is_mark_successfully = false;

  IR *root = v_ir_collector[v_ir_collector.size() - 1];
  IR *par_ir = nullptr;
  IR *par_par_ir = nullptr;
  IR *par_par_par_ir = nullptr; // If we find the correct selectnoparen, this
                                // should be the statementlist.
  for (auto ir : v_ir_collector) {
    if (ir != nullptr)
      ir->is_node_struct_fixed = false;
  }
  for (auto ir : v_ir_collector) {
    if (ir != nullptr && ir->type_ == kSelectCore) {
      par_ir = root->locate_parent(ir);
      if (par_ir != nullptr && par_ir->type_ == kSelectStatement) {
        par_par_ir = root->locate_parent(par_ir);
        if (par_par_ir != nullptr && par_par_ir->type_ == kStatement) {
          par_par_par_ir = root->locate_parent(par_par_ir);
          if (par_par_par_ir != nullptr &&
              par_par_par_ir->type_ == kStatementList) {
            string query = g_mutator->extract_struct(ir);
            if (!(this->is_oracle_select_stmt_str(query)))
              continue; // Not norec compatible. Jump to the next ir.
            query.clear();
            is_mark_successfully = this->mark_node_valid(ir);
            // cerr << "\n\n\nThe marked norec ir is: " <<
            // this->extract_struct(ir) << " \n\n\n";
            par_ir->is_node_struct_fixed = true;
            par_par_ir->is_node_struct_fixed = true;
            par_par_par_ir->is_node_struct_fixed = true;
          }
        }
      }
    }
  }

  return is_mark_successfully;
}

void SQL_OPT::compare_results(ALL_COMP_RES &res_out) {

  res_out.final_res = ORA_COMP_RES::Pass;
  bool is_all_err = true;

  for (COMP_RES &res : res_out.v_res) {
    if (res.v_res_str.size() < 3) {
      res.comp_res = ORA_COMP_RES::Error;
      res.res_int_0 = -1;
      res.res_int_1 = -1;
      res.res_int_2 = -1;
      res.v_res_int.push_back(-1);
      res.v_res_int.push_back(-1);
      res.v_res_int.push_back(-1);
      continue;
    }
    if (findStringIn(res.v_res_str[0], "Error") ||
        findStringIn(res.v_res_str[2], "Error") ||
        findStringIn(res.v_res_str[1], "Error")) {
      res.comp_res = ORA_COMP_RES::Error;
      res.res_int_0 = -1;
      res.res_int_1 = -1;
      res.res_int_2 = -1;
      res.v_res_int.push_back(-1);
      res.v_res_int.push_back(-1);
      res.v_res_int.push_back(-1);
      continue;
    }

    vector<string> v_res_a = string_splitter(res.v_res_str[0], '\n');
    vector<string> v_res_b = string_splitter(res.v_res_str[1], '\n');
    vector<string> v_res_c = string_splitter(res.v_res_str[2], '\n');

      if (v_res_a.size() > 50 || v_res_b.size() > 50) {
        res.comp_res = ORA_COMP_RES::Error;
          res.v_res_int.push_back(-1);
          res.v_res_int.push_back(-1);
          res.v_res_int.push_back(-1);
        continue;
      }

      res.res_int_0 = v_res_a.size();
      res.res_int_1 = v_res_b.size();
      res.res_int_2 = v_res_c.size();

      res.v_res_int.push_back(res.res_int_0);
      res.v_res_int.push_back(res.res_int_1);
      res.v_res_int.push_back(res.res_int_2);

    is_all_err = false;
    if (res.res_int_0 != res.res_int_1 || res.res_int_1 != res.res_int_2) { // Found mismatched.
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

bool SQL_OPT::is_oracle_select_stmt(IR* cur_IR) {

  if (
    ir_wrapper.is_exist_ir_node_in_stmt_with_type(cur_IR, kSelectStatement, false)
  ) {
      return true;
  }
  return false;
}

vector<IR*> SQL_OPT::post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) {

  vector<IR*> trans_IR_vec;

  cur_stmt = cur_stmt->deep_copy();

  trans_IR_vec.push_back(cur_stmt);

  return trans_IR_vec;

}

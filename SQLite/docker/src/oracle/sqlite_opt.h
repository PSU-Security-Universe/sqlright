#ifndef __SQLITE_OPT_H__
#define __SQLITE_OPT_H__

#include "../include/ast.h"
#include "../include/define.h"
#include "./sqlite_oracle.h"

#include <string>
#include <vector>

using namespace std;

class SQL_OPT : public SQL_ORACLE {
public:
  bool mark_all_valid_node(vector<IR *> &v_ir_collector) override;
  void compare_results(ALL_COMP_RES &res_out) override;

    unsigned get_mul_run_num() override { return 3; }

  bool is_oracle_select_stmt(IR* cur_IR) override;
  virtual vector<IR*> post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) override;

  string get_temp_valid_stmts() override { return temp_valid_stmts; };

  string get_oracle_type() override { return this->oracle_type; }

private:
  string temp_valid_stmts = "SELECT COUNT ( * ) FROM x WHERE x;";

  string oracle_type = "OPT";
};

#endif

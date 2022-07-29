#ifndef __POSTGRE_NOREC_H__
#define __POSTGRE_NOREC_H__

#include "../include/ast.h"
#include "../include/define.h"
#include "./postgres_oracle.h"

#include <string>
#include <vector>

using namespace std;

class SQL_NOREC : public SQL_ORACLE {
public:
  bool mark_all_valid_node(vector<IR *> &v_ir_collector) override;
  void compare_results(ALL_COMP_RES &res_out) override;

  bool is_oracle_select_stmt(IR* cur_IR) override;

  vector<IR*> post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) override;

  string get_template_select_stmts() override { return temp_valid_stmts; };

  string get_oracle_type() override { return this->oracle_type; }

private:

// Postgres need to generate
  string temp_valid_stmts = "SELECT COUNT ( * ) FROM x WHERE x=0;";

  string oracle_type = "NOREC";
  string post_fix_temp = "SELECT COALESCE( SUM(countt), 0) FROM ( SELECT ALL( true ) :: INT as countt FROM v2 ORDER BY ( v1 ) ) as ress;" ;
};

#endif

#ifndef __SQLITE_DEMO_H__
#define __SQLITE_DEMO_H__

#include "../include/ast.h"
#include "../include/define.h"
#include "./sqlite_oracle.h"

#include <string>
#include <vector>

using namespace std;

enum class VALID_STMT_TYPE_LIKELY { NORMAL, AGGR, ROWID_UNKNOWN };

class SQL_LIKELY : public SQL_ORACLE {
public:
  bool mark_all_valid_node(vector<IR *> &v_ir_collector) override;
  void compare_results(ALL_COMP_RES &res_out) override;

  string get_temp_valid_stmts() override { return temp_valid_stmts[get_rand_int(temp_valid_stmts.size())]; };

  string get_oracle_type() override { return this->oracle_type; }

  bool is_oracle_select_stmt(IR* cur_IR) override;
  vector<IR*> post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) override;

private:
  vector<string> temp_valid_stmts = {
      /* Complete set */
      "SELECT * FROM WHERE x;",
      "SELECT * FROM x WHERE x GROUP BY x;",
      "SELECT * FROM x WHERE x HAVING x;", 
      "SELECT DISTINCT * FROM x WHERE x;",
      "SELECT MIN(x) FROM x WHERE x;", 
      "SELECT MAX(x) FROM x WHERE x;",
      "SELECT SUM(x) FROM x WHERE x;", 
      "SELECT COUNT(x) FROM x WHERE x;",
      "SELECT AVG(x) FROM x WHERE x;"
  };

  void get_v_valid_type(const string &cmd_str,
                        vector<VALID_STMT_TYPE_LIKELY> &v_valid_type);

  bool compare_norm(COMP_RES &res); /* Handle normal valid stmt: SELECT * FROM
                                       ...; Return is_err */
  bool compare_aggr(COMP_RES &res);

  VALID_STMT_TYPE_LIKELY get_stmt_LIKELY_type (IR* cur_stmt);

  string oracle_type = "LIKELY";
};

#endif
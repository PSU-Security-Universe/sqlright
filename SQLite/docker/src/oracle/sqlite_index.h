#ifndef __SQLITE_INDEX_H__
#define __SQLITE_INDEX_H__

#include "../include/ast.h"
#include "../include/define.h"
#include "../include/utils.h"
#include "./sqlite_oracle.h"

#include <string>
#include <vector>

using namespace std;

enum class VALID_STMT_TYPE_INDEX { NORMAL, AGGR, ROWID_UNKNOWN };

class SQL_INDEX : public SQL_ORACLE {
public:
  bool mark_all_valid_node(vector<IR *> &v_ir_collector) override;
  void compare_results(ALL_COMP_RES &res_out) override;

  string get_temp_valid_stmts() override { return temp_valid_stmts[get_rand_int(temp_append_stmts.size())]; };

  /* Execute SQLite3 two times. Add or remove WITHOUT ROWID. Compare the
   * results. */
  unsigned get_mul_run_num() override { return 2; }

  string get_oracle_type() override { return this->oracle_type; }

  bool is_remove_oracle_normal_stmt_at_start() override {return true;}
  bool is_oracle_normal_stmt(IR* cur_IR) override;

  bool is_oracle_select_stmt(IR* cur_IR) override;

  IR* pre_fix_transform_normal_stmt(IR* cur_stmt) override;
  vector<IR*> post_fix_transform_normal_stmt(IR* cur_stmt, unsigned multi_run_id) override;

  vector<IR*> post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) override;

  int is_random_append_stmts() override {return 5;}
  IR* get_random_append_stmts_ir() override;

private:
  vector<string> temp_valid_stmts = {
      /* Complete set */
      "SELECT * FROM x;",
      "SELECT * FROM WHERE x = x;",
      "SELECT * FROM x WHERE x GROUP BY x;",
      "SELECT * FROM x WHERE x HAVING x;", 
      "SELECT DISTINCT * FROM x WHERE x;",
      "SELECT MIN(x) FROM x WHERE x;", 
      "SELECT MAX(x) FROM x WHERE x;",
      "SELECT SUM(x) FROM x WHERE x;", 
      "SELECT COUNT(x) FROM x WHERE x;",
      "SELECT AVG(x) FROM x WHERE x;"
  };
  vector<string> temp_append_stmts = {"CREATE INDEX x ON x(x)"};

  void get_v_valid_type(const string &cmd_str,
                        vector<VALID_STMT_TYPE_INDEX> &v_valid_type);

  VALID_STMT_TYPE_INDEX get_stmt_INDEX_type(IR*);

  bool compare_norm(COMP_RES &res); /* Handle normal valid stmt: SELECT * FROM
                                       ...; Return is_err */
  bool compare_aggr(COMP_RES &res);

  string oracle_type = "INDEX";
};

#endif
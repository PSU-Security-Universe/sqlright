#ifndef __SQLITE_ORACLE_H__
#define __SQLITE_ORACLE_H__

#include "../include/ast.h"
#include "../include/define.h"
#include "../include/mutator.h"
#include "../include/utils.h"
#include "../include/ir_wrapper.h"

#include <string>
#include <vector>

using namespace std;

class Mutator;

class SQL_ORACLE {
public:

  /* Helper function. */
  void set_mutator(Mutator *mutator);

  /* ====== Above have been checked ======================= */

  inline bool is_select_stmt(IR* cur_IR) {
    if (cur_IR->type_ == kSelectStatement) {
      return true;
    } else {
      return false;
    }
  }

  virtual void remove_all_select_stmt_from_ir(IR* ir_root);

  virtual int count_oracle_select_stmts(IR* ir_root);
  virtual int count_oracle_normal_stmts(IR* ir_root);
  /* Determine whether this SELECT statement is related to ORACLE */
  virtual bool is_oracle_select_stmt_str(const string &query);
  virtual bool is_oracle_select_stmt(IR* cur_IR);
  /* Determine whether this non-SELECT statement is related to ORACLE */
  virtual bool is_oracle_normal_stmt(IR* cur_IR) {return false;}

  /* Randomly add some statements into the query sets. Will append to the query
   * in a pretty early stage. Can be used to append some interesting or ORACLE  
   * related non-SELECT statements into the query set. 
   * For examples, can be used for randomly insert CREATE INDEX statements for the INDEX oracle.
   */
  virtual int is_random_append_stmts() {return 0;}
  virtual IR* get_random_append_stmts_ir() {return nullptr;}

  /* Mark all the IR node in the IR tree, that is related to the validation
  ** components that you do not want to mutate. 
  ** e.g. Fix "SELECT COUNT (*)" from the NOREC oracle.
  */
  virtual bool mark_all_valid_node(vector<IR *> &v_ir_collector) = 0;

  virtual string remove_oracle_select_stmts_from_str(string query);
  virtual void remove_oracle_select_stmts_from_ir(IR* ir_root);
  virtual void remove_oracle_normal_stmts_from_ir(IR* ir_root);

  /* 
  ** Transformation function for select statements. pre_fix_* functions work before concret value has been filled in to the 
  ** query. post_fix_* functions work after concret value filled into the query. (before/after validate() ) 
  ** If no transformation is necessary, return empty vector. 
  */
  virtual IR* pre_fix_transform_select_stmt(IR* cur_stmt) {return nullptr;}
  virtual vector<IR*> post_fix_transform_select_stmt(IR* cur_stmt, unsigned multi_run_id) {vector<IR*> tmp; return tmp;}
  virtual vector<IR*> post_fix_transform_select_stmt(IR* cur_stmt) {return this->post_fix_transform_select_stmt(cur_stmt, 0);}

  /* 
  ** Transformation function for normal (non-select) statements. pre_fix_* functions work before concret value has been filled in to the 
  ** query. post_fix_* functions work after concret value filled into the query. (before/after Mutator::validate() )
  ** If no transformation is necessary, return empty vector. 
  */

  virtual IR* pre_fix_transform_normal_stmt(IR* cur_stmt) {return nullptr;} //non-select stmt pre_fix transformation. 
  virtual vector<IR*> post_fix_transform_normal_stmt(IR* cur_stmt, unsigned multi_run_id) {vector<IR*> tmp; return tmp;} //non-select
  virtual vector<IR*> post_fix_transform_normal_stmt(IR* cur_stmt) {return this->post_fix_transform_normal_stmt(cur_stmt, 0);} //non-select

  /* Compare the results from the res_out. 
  */
  virtual void compare_results(ALL_COMP_RES &res_out) = 0;

  virtual IR* get_random_mutated_valid_stmt();

  virtual string get_temp_valid_stmts() = 0;

  virtual unsigned get_mul_run_num() { return 1; }

  virtual string get_oracle_type() = 0;

  /* Debug */
  unsigned long total_rand_valid = 0;
  unsigned long total_oracle_rand_valid_failed = 0;
  unsigned long total_temp = 0;

  /* IRWrapper related */
  /* Everytime we need to modify the IR tree, we need to call this function first. */
  virtual bool init_ir_wrapper(IR* ir_root) {this->ir_wrapper.set_ir_root(ir_root); return true;}
  virtual bool init_ir_wrapper(vector<IR*> ir_vec) {return this->init_ir_wrapper(ir_vec.back());}

  IRWrapper ir_wrapper; // Make it public, so that afl-fuzz.cpp can also call its function. 

  virtual bool is_remove_oracle_select_stmt_at_start() {return true;}
  virtual bool is_remove_oracle_normal_stmt_at_start() {return false;}
  virtual bool is_remove_all_select_stmt_at_start() {return true;}

protected:
  Mutator *g_mutator;

  virtual bool mark_node_valid(IR *root);
};

#endif

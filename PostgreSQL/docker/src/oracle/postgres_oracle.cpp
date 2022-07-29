#include "./postgres_oracle.h"
#include "../include/ast.h"
#include "../AFL/debug.h"

bool SQL_ORACLE::mark_node_valid(IR *root) {
  if (root == nullptr)
    return false;
  /* the following types do not added to the norec_select_stmt list. They should
   * be able to mutate as usual. */
  if (// root->type_ == kNewExpr || root->type_ == kTableOrSubquery ||
      root->type_ == kOptGroupClause || root->type_ == kWindowClause)
    return false;
  root->is_node_struct_fixed = true;
  if (root->left_ != nullptr)
    this->mark_node_valid(root->left_);
  if (root->right_ != nullptr)
    this->mark_node_valid(root->right_);
  return true;
}

void SQL_ORACLE::set_mutator(Mutator *mutator) { this->g_mutator = mutator; }


// TODO:: This function is a bit too long.
// guarantee to generate grammarly correct query
IR* SQL_ORACLE::get_random_mutated_select_stmt() {
  /* Read from the previously seen norec compatible select stmt.
   * For example, for NOREC: SELECT COUNT ( * ) FROM ... WHERE ...;
   * mutate them, and then return the string of the new generated
   * norec compatible SELECT query.
  */
  bool is_success = false;
  vector<IR *> ir_tree;
  IR *root = NULL;
  string new_valid_select_str = "";

  total_rand_valid += 1;
  bool use_temp = false;

  while (!is_success) {

    string ori_valid_select = "";
    use_temp = g_mutator->get_valid_str_from_lib(ori_valid_select);

    // cerr << "Inside the loop \n\n\n";

    ir_tree.clear();
    ir_tree = g_mutator->parse_query_str_get_ir_set(ori_valid_select);

    if (ir_tree.size() == 0) {
      // cerr << "Error: string: " << ori_valid_select << "parsing failed in Func: SQL_ORACLE::get_random_mutated_valid_stmt. \n\n\n";
      continue;
    }

    root = ir_tree.back();

    if (!g_mutator->check_node_num(root, 300)) {
      root->deep_drop();
      root = NULL;
      continue;
    }

    IR *cur_ir_stmt = ir_wrapper.get_first_stmt_from_root(root);

    if (!this->is_oracle_select_stmt(cur_ir_stmt))
      {
        // cerr << "Error: cur_ir_stmt is not oracle statement. cur_ir_stmt->to_stirng(): "<<  cur_ir_stmt->to_string() << "  In func: SQL_ORACLE::get_random_mutated_valid_stmt. \n\n\n";
        continue;
      }

    // cerr << "DEBUG: In get_random_mutated_select_stmt: getting ori_valid_select: \n" << ori_valid_select << " \nGetting cur_ir_stmt: \n" << cur_ir_stmt->to_string() << "\n\n\n\n";

    // if (!g_mutator->check_node_num(root, 400)) {
    //   /* The retrived norec stmt is too complicated to mutate, directly return
    //    * the retrived query. */
    //   IR* returned_stmt_ir = cur_ir_stmt -> deep_copy();
    //   root->deep_drop();
    //   // cerr << "Directly return oracle select because it is too complicated. \n";
    //   return returned_stmt_ir;
    // }

    /* If we are using a non template valid stmt from the p_oracle lib:
     *  2/3 of chances to return the stmt immediate without mutation.
     *  1/3 of chances to return with further mutation.
     */
    // cout << "ori_valid_select: " << ori_valid_select << endl;
    if (!use_temp && get_rand_int(3) < 2) {
      IR* returned_stmt_ir = cur_ir_stmt -> deep_copy();
      root->deep_drop();
      // cerr << "Successfully return original select: " << returned_stmt_ir << "\n\n\n";
      return returned_stmt_ir;
    }

    // cerr << "################################################\n";

    /* Restrict changes on the signiture norec select components. Could increase
     * mutation efficiency. */
    mark_all_valid_node(ir_tree);

    // cout << "root: " << root->to_string()  << endl;

    string ori_valid_select_struct = g_mutator->extract_struct(root);
    string new_valid_select_struct = "";

    /* For every retrived norec stmt, and its parsed IR tree, give it 100 trials
     * to mutate.
     */
    for (int trial_count = 0; trial_count < 30; trial_count++) {

      num_oracle_select_mutate++;

      /* Pick random ir node in the select stmt */
      bool is_mutate_ir_node_chosen = false;
      IR *mutate_ir_node = NULL;
      IR *new_mutated_ir_node = NULL;
      int choose_node_trial = 0;
      while (!is_mutate_ir_node_chosen) {
        if (choose_node_trial > 100)
          break;
        choose_node_trial++;
        mutate_ir_node = ir_tree[get_rand_int(
            ir_tree.size() - 1)]; // Do not choose the program_root to mutate.
        if (mutate_ir_node == NULL) {
          // cerr << "chosen mutate_ir_node is NULL\n\n\n";
          continue; 
        }
        if (mutate_ir_node->is_node_struct_fixed) {
          // cerr << "node strcut is fixed. \n\n\n";
          continue;
        }
        is_mutate_ir_node_chosen = true;
        break;
      }

      if (!is_mutate_ir_node_chosen)
        break; // The current ir tree cannot even find the node to mutate.
               // Ignored and retrive new norec stmt from lib or from library.
      // cout << "\n################################" << endl;
      // cout << "before_strategy: " << root->to_string() << endl;
      /* Pick random mutation methods. */
      // cerr << "The chosen IR node type_: " << mutate_ir_node->type_ << "  string: " << mutate_ir_node->to_string() << "\n\n\n";
      switch (get_rand_int(3)) {
      // switch (1) {
      case 0: {
        
        new_mutated_ir_node = g_mutator->strategy_delete(mutate_ir_node);
        // if (new_mutated_ir_node!=NULL) 
        //   cout << "strategy_delete: " << new_mutated_ir_node->to_string() << endl;
        
        break;
      }
      case 1:{
        new_mutated_ir_node = g_mutator->strategy_insert(mutate_ir_node);
        // if (new_mutated_ir_node!=NULL) 
        //   cout << "strategy_insert: " << new_mutated_ir_node->to_string() << endl;
        
        break;
      }
      case 2: {
        new_mutated_ir_node = g_mutator->strategy_replace(mutate_ir_node);
        // if (new_mutated_ir_node!=NULL) 
        //   cout << "strategy_replace: " << new_mutated_ir_node->to_string() << endl;
        break;
      }
      }

      if (new_mutated_ir_node==NULL) {
        // cerr << "new_mutated_ir_node is NULL\n\n\n";
        continue;
      }

      if (!root->swap_node(mutate_ir_node, new_mutated_ir_node)) {
        new_mutated_ir_node->deep_drop();
        // cerr << "swap node to new_mutated_ir_node failure. \n";
        continue;
      }
      // cout << "mutated query: " <<  root->to_string() << "\n";
      // cout << "################################" << endl;

      new_valid_select_str = root->to_string();

      if (new_valid_select_str != ori_valid_select) {
        new_valid_select_struct = g_mutator->extract_struct(root);
      }

      root->swap_node(new_mutated_ir_node, mutate_ir_node);
      // cout << "mutated query to_string(): "<<  new_valid_select_str << "\n\n\n\n";
      // cout << "ori query: " << root->to_string() << endl;
      new_mutated_ir_node->deep_drop();
      if (new_valid_select_str == ori_valid_select) {
        // cerr << "Mutated string is the same as before. \n";
        continue;
      }

      /* Final check and return string if compatible */
      vector<IR *> new_ir_verified =
          g_mutator->parse_query_str_get_ir_set(new_valid_select_str);
      

      if (new_ir_verified.size() <= 0) {
        // cerr << "new_ir_verified cannot pass the parser: ";
        continue;
      }

      // Make sure the mutated structure is different.
      IR* new_ir_verified_stmt = ir_wrapper.get_first_stmt_from_root(new_ir_verified.back());

      // /* Debug outputs.  */
      // cerr << "ori_valid_select_struct is: " << ori_valid_select_struct << "\n";
      // cerr << "new_valid_select_struct is: " << new_valid_select_struct << "\n";
      // if (new_ir_verified_stmt) {
      //   cerr << "Getting mutated query: " << new_ir_verified_stmt->to_string() << "\n";
      // } else {
      //   cerr << "Empty new_ir_verified_stmt. \n";
      //   cerr << "The new_ir_verified.back() is: " << new_ir_verified.back() << "\n";
      // }
      // cerr << "is_oracle_select_stmt: " << is_oracle_select_stmt(new_ir_verified_stmt) << "\n";

      // cerr << "Debug new_ir_verrified struct: ";
      // g_mutator->debug(new_ir_verified.back(), 0);
      // cerr << "\n\n\n\n\n\n";

      if (this->is_oracle_select_stmt(new_ir_verified_stmt) && new_valid_select_struct != ori_valid_select_struct) {
        root->deep_drop();
        is_success = true;

        if (use_temp)
          total_temp++;
        
        IR* returned_stmt_ir = new_ir_verified_stmt->deep_copy();
        new_ir_verified.back()->deep_drop();
        // cerr << "ori_valid_select is: " << ori_valid_select << "\n";
        // cerr << "Successfully return: " << returned_stmt_ir->to_string() << "\n\n\n";
        num_oracle_select_succeed++;
        return returned_stmt_ir;
      }
      else {
        // cerr << "Mutated query is the same as before. Or mutation doesn't change the query. \n\n\n";
        new_ir_verified.back()->deep_drop();
      }

      continue; // Retry mutating the current norec stmt and its IR tree.
    }

    /* Failed to mutate the retrived norec select stmt after 100 trials.
     * Maybe it is because the norec select stmt is too complex the mutate.
     * Grab another norec select stmt from the lib or from the template, try
     * again.
     */
    // cerr << "Mutation Failed. Failed to return Oracle SELECT in 100 trials. \n"
    root->deep_drop();
    root = NULL;
  }
  // FATAL("Unexpected code execution in '%s'", "SQL_ORACLE::get_random_mutated_valid_stmt()");
  return nullptr;
}

int SQL_ORACLE::count_oracle_select_stmts(IR* ir_root) {
  ir_wrapper.set_ir_root(ir_root);
  vector<IR*> stmt_vec = ir_wrapper.get_stmt_ir_vec();

  int oracle_stmt_num = 0;
  for (IR* cur_stmt : stmt_vec){
    if (this->is_oracle_select_stmt(cur_stmt)) {oracle_stmt_num++;}
  }
  return oracle_stmt_num;
}

int SQL_ORACLE::count_oracle_normal_stmts(IR* ir_root) {
  ir_wrapper.set_ir_root(ir_root);
  vector<IR*> stmt_vec = ir_wrapper.get_stmt_ir_vec();

  int oracle_stmt_num = 0;
  for (IR* cur_stmt : stmt_vec){
    if (this->is_oracle_normal_stmt(cur_stmt)) {oracle_stmt_num++;}
  }
  return oracle_stmt_num;
}

bool SQL_ORACLE::is_oracle_select_stmt(IR* cur_IR){
  if (cur_IR != NULL && cur_IR->type_ == kSelectStmt) {
    /* For dummy function, treat all SELECT stmt as oracle function.  */
    return true;
  }
  return false;
}

void SQL_ORACLE::remove_select_stmt_from_ir(IR* ir_root) {
  ir_wrapper.set_ir_root(ir_root);
  vector<IR*> stmt_vec = ir_wrapper.get_stmt_ir_vec(ir_root);
  for (IR* cur_stmt : stmt_vec) {
    if (cur_stmt->type_ == kSelectStmt) {
      ir_wrapper.remove_stmt_and_free(cur_stmt);
    }
  }
  return;
}

void SQL_ORACLE::remove_oracle_select_stmt_from_ir(IR* ir_root) {
  ir_wrapper.set_ir_root(ir_root);
  vector<IR*> stmt_vec = ir_wrapper.get_stmt_ir_vec(ir_root);
  for (IR* cur_stmt : stmt_vec) {
    if (this->is_oracle_select_stmt(cur_stmt)) {
      ir_wrapper.remove_stmt_and_free(cur_stmt);
    }
  }
  return;
}

string SQL_ORACLE::remove_select_stmt_from_str(string in) {
  vector<IR*> ir_set = g_mutator->parse_query_str_get_ir_set(in);
  if (ir_set.size()==0) {
    cerr << "Error: ir_set size is 0. \n";
  }
  IR* ir_root = ir_set.back();
  remove_select_stmt_from_ir(ir_root);
  string res_str = ir_root->to_string();
  ir_root->deep_drop();
  return res_str;
}

string SQL_ORACLE::remove_oracle_select_stmt_from_str(string in) {
  vector<IR*> ir_set = g_mutator->parse_query_str_get_ir_set(in);
  if (ir_set.size()==0) {
    cerr << "Error: ir_set size is 0. \n";
  }
  IR* ir_root = ir_set.back();
  remove_oracle_select_stmt_from_ir(ir_root);
  string res_str = ir_root->to_string();
  ir_root->deep_drop();
  return res_str;
}


bool SQL_ORACLE::is_oracle_select_stmt(string in) {
    vector<IR*> ir_vec = g_mutator->parse_query_str_get_ir_set(in);
    if(!ir_vec.size()) {
        cerr << "Error: getting empty ir_vec. Parsing failed. \n";
        return false;
    }
    IR* cur_stmt = ir_wrapper.get_first_stmt_from_root(ir_vec.back());
    if(cur_stmt == NULL) {
        cerr << "Error: Cannot find the stmt inside the ir_vec(). \n";
        return false;
    }
    bool res = is_oracle_select_stmt(cur_stmt);
    ir_vec.back()->deep_drop();
    return res;
}

bool SQL_ORACLE::is_oracle_normal_stmt(string in) {
    vector<IR*> ir_vec = g_mutator->parse_query_str_get_ir_set(in);
    if(!ir_vec.size()) {
        cerr << "Error: getting empty ir_vec. Parsing failed. \n";
        return false;
    }
    IR* cur_stmt = ir_wrapper.get_first_stmt_from_root(ir_vec.back());
    if(cur_stmt == NULL) {
        cerr << "Error: Cannot find the stmt inside the ir_vec(). \n";
        return false;
    }
    bool res = is_oracle_normal_stmt(cur_stmt);
    ir_vec.back()->deep_drop();
    return res;
}

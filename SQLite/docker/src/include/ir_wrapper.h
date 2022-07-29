#ifndef __IR_WRAPPER_H__
#define __IR_WRAPPER_H__

#include "define.h"
#include "ast.h"
#include <string>
#include "mutator.h"

typedef NODETYPE IRTYPE;

class IRWrapper {
public:

    void set_ir_root (IR* in) {this->ir_root = in;} 
    IR* get_ir_root () {return this->ir_root;}

    vector<IR*> get_all_ir_node (IR* cur_ir_root);
    vector<IR*> get_all_ir_node ();

    bool is_exist_ir_node_in_stmt_with_type(IRTYPE ir_type, bool is_subquery, int stmt_idx);
    vector<IR*> get_ir_node_in_stmt_with_type(IRTYPE ir_type, bool is_subquery = false, int stmt_idx = -1);

    bool is_exist_ir_node_in_stmt_with_type(IR* cur_stmt, IRTYPE ir_type, bool is_subquery);
    vector<IR*> get_ir_node_in_stmt_with_type(IR* cur_stmt, IRTYPE ir_type,
        bool is_subquery = false, bool is_ignore_subquery = false);

    vector<IR*> get_ir_node_in_stmt_with_id_type(IR* cur_stmt, IDTYPE id_type, 
        bool is_subquery = false, bool is_ignore_subquery = false);

    bool append_stmt_after_idx(string, int idx, Mutator& g_mutator);
    bool append_stmt_at_end(string, Mutator& g_mutator);
    bool append_stmt_after_idx(IR*, int idx); // Please provide with IR* (kStatement*) type, do not provide IR*(kStatementList*) type. If want to append at the start, use idx=-1; 
    bool append_stmt_at_end(IR*, Mutator& g_mutator);
    bool append_stmt_at_end(IR*); // Please provide with IR* (kStatement*) type, do not provide IR*(kStatementList*) type. 

    bool remove_stmt_at_idx_and_free(unsigned idx);
    bool remove_stmt_and_free(IR* rov_stmt);

    bool replace_stmt_and_free(IR* old_stmt, IR* cur_stmt);

    bool append_components_at_ir(IR*, IR*, bool is_left, bool is_replace = true);
    bool remove_components_at_ir(IR*);

    // bool swap_components_at_ir(IR*, bool is_left_f, IR*, bool is_left_l);

    IR* get_ir_node_for_stmt_with_idx(int idx);

    bool is_ir_before(IR* f, IR* l); // Check is IR f before IR l in query string.
    bool is_ir_after(IR* f, IR* l); // Check is IR f after IR l in query string.

    vector<IRTYPE> get_all_ir_type();
    int get_stmt_num();
    int get_stmt_num(IR* cur_root);
    int get_stmt_idx(IR*);

    vector<IR*> get_stmt_ir_vec();
    vector<IR*> get_stmt_ir_vec(IR* root) {this->set_ir_root(root); return this->get_stmt_ir_vec();}

    vector<IR*> get_stmtlist_IR_vec();
    vector<IR*> get_stmtlist_IR_vec(IR* root) {this->set_ir_root(root); return this->get_stmtlist_IR_vec();}

    bool is_in_subquery(IR* cur_stmt, IR* check_node);


    /*
    ** Iterately find the parent type. Skip kUnknown and keep iterating until not kUnknown is found. Return the parent IRTYPE. 
    ** If parent_ is NULL. Return kUnknown instead. 
    */
    IRTYPE get_parent_type(IR* cur_IR, int depth=0);
    IR* get_parent_with_a_type(IR* cur_IR, int depth=0);

    /* more specific features. */
    /*******************************************/
    /* Receive one knewexpr IR node, add cast(... AS type_); return the new knewexpr containing the cast expression. */
    IR* add_cast_expr(IR*, string);

    /* Receive one knewexpr IR node, add new function such as SUM(), COUNT(), MIN(), MAX(), AVG() etc; return the new knewexpr containing the ** added function. 
    */
    IR* add_func(IR*, string);

    /* Receive one knewexpr IR node, add new binary_op between left_stmt and right_stmt; return the new knewexpr containing 
    ** the added operations. 
    */
    IR* add_binary_op(IR* ori_expr, IR* left_stmt_expr, IR* right_stmt_expr,
        string op_value, bool is_free_left = false, bool is_free_right = false);

    /* 
    ** Given a statement IR, check whether the statment contains 'GROUP BY' or 'HAVING' clause. 
    */
    bool is_exist_group_by(IR* cur_stmt);
    bool is_exist_having(IR* cur_stmt);
    bool is_exist_distinct(IR* cur_stmt);

    /*
    ** Given a SELECT statement, get the knewexpr in the SELECT clause.  
    */ 
    IR* get_result_column_in_select_clause_in_select_stmt(IR* cur_stmt, int idx);

    /* 
    ** Given an IR node, return the statement IR that contains this certain cur_ir node. 
    */
    IR* get_stmt_ir_from_child_ir(IR* cur_ir);

    /**/
    int get_num_result_column_in_select_clause(IR* cur_stmt);

    /**/
    vector<IR*> get_result_column_list_in_select_clause(IR* cur_stmt);

    /**/
    bool add_without_rowid_to_stmt(IR* cur_stmt);
    bool remove_without_rowid_to_stmt(IR* cur_stmt);

    /**/
    bool combine_stmt_in_selectcore(IR* left_stmt, IR* right_stmt, string set_operator_str, bool is_free_left, bool is_free_right);

    /**/
    IR* get_alias_iden_from_tablename_iden(IR* tablename_iden);

    /**/
    IRTYPE get_cur_stmt_type(IR* cur_ir);

    /**/
    vector<IR*> get_selectcore_vec(IR* cur_stmt);

    /**/
    int get_num_selectcore(IR* cur_stmt);

    /*If want to append on the beginning, use idx=-1; */
    bool append_selectcore_clause_after_idx(IR* cur_stmt, IR* app_ir, string set_oper_str, int idx);

    /**/
    bool remove_selectcore_clause_at_idx_and_free(IR* cur_stmt, int idx);

    /**/
    IR* find_closest_node_exclude_child (IR* cur_node, IRTYPE type_);
    IR* find_closest_node_exclude_child (IR* cur_node, IDTYPE data_type_);

    /**/
    vector<IR*> get_common_table_expr_from_list(IR* cur_ir);
    vector<IR*> get_table_ir_in_with_clause(IR* cur_ir);

private:
    IR* ir_root = nullptr;

};

#endif

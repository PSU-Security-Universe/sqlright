#ifndef __IR_WRAPPER_H__
#define __IR_WRAPPER_H__

#include "utils.h"
#include "ast.h"
#include "../AFL/debug.h"
#include "../parser/parser_entry.h"
#include <string>

enum IRTYPE;
enum DATATYPE;

class IR;
class IROperator;

class IRWrapper {
public:
    void set_ir_root (IR* in) {this->ir_root = in;} 
    IR* get_ir_root () {return this->ir_root;}

    // All deep_copied. 
    IR* reconstruct_ir_with_stmt_vec(const vector<IR*>&);

    IR* get_first_stmtlist_from_root(IR* cur_root);
    IR* get_first_stmtlist_from_root();
    IR* get_first_stmt_from_root(IR* cur_root);
    IR* get_first_stmt_from_root();


    IR* get_last_stmtlist_from_root(IR* cur_root);
    IR* get_last_stmtlist_from_root();
    IR* get_last_stmt_from_root(IR* cur_root);
    IR* get_last_stmt_from_root();

    IR* get_stmt_ir_from_stmtlist(IR* cur_stmtlist);


    vector<IR*> get_all_ir_node (IR* cur_ir_root);
    void get_all_ir_node(IR* cur_ir, vector<IR*>& res);

    IRTYPE get_cur_stmt_type_from_sub_ir(IR* cur_ir);
    IR* get_cur_stmt_ir_from_sub_ir(IR* cur_ir);

    bool is_exist_ir_node_in_stmt_with_type(IRTYPE ir_type, bool is_subquery, 
        int stmt_idx);
    bool is_exist_ir_node_in_stmt_with_type(IR* cur_stmt, IRTYPE ir_type, 
        bool is_subquery = false, bool ignore_is_subquery = false);
    bool is_exist_ir_node_in_stmt_with_type(IR* cur_stmt, IRTYPE ir_type);

    /* By default, is_ignore_type_suffix == true.
     * Which means kSelectStmt_1 and kSelectStmt_2 is the same type
     */
    vector<IR*> get_ir_node_in_stmt_with_type(IR* cur_stmt, IRTYPE ir_type, 
        bool is_subquery = false, bool ignore_is_subquery = false, bool is_ignore_type_suffix = true);

    bool append_stmt_at_idx(string, int idx);
    bool append_stmt_at_end(string);
    bool append_stmt_at_idx(IR*, int idx); // Please provide with IR* (kStatement*) type, do not provide IR*(kStatementList*) type. If want to append at the start, use idx=-1; 
    bool append_stmt_at_end(IR*); // Please provide with IR* (kStatement*) type, do not provide IR*(kStatementList*) type. 

    bool remove_stmt_at_idx_and_free(unsigned idx);
    bool remove_stmt_and_free(IR* rov_stmt);

    bool replace_stmt_and_free(IR* old_stmt, IR* cur_stmt);

    bool append_components_at_ir(IR*, IR*, bool is_left, 
        bool is_replace = true);
    bool remove_components_at_ir(IR*);

    // bool swap_components_at_ir(IR*, bool is_left_f, IR*, bool is_left_l);

    IR* get_ir_node_for_stmt_by_idx(int idx);
    IR* get_ir_node_for_stmt_by_idx(IR* ir_root, int idx);

    vector<IRTYPE> get_all_stmt_ir_type();
    int get_stmt_num();
    int get_stmt_num(IR* cur_root);
    int get_stmt_idx(IR*);

    vector<IR*> get_stmt_ir_vec();
    vector<IR*> get_stmt_ir_vec(IR* root) {this->set_ir_root(root); return this->get_stmt_ir_vec();}

    vector<IR*> get_stmtlist_IR_vec();
    vector<IR*> get_stmtlist_IR_vec(IR* root) {this->set_ir_root(root); return this->get_stmtlist_IR_vec();}

    bool compare_ir_type(IRTYPE left,IRTYPE right, bool ignore_subtype = true);

    bool is_in_subquery(IR* cur_stmt, IR* check_node, bool output_debug = false);
    bool is_in_insert_rest(IR* cur_stmt, IR* check_node, bool output_debug=false);

    /*
    ** Iterately find the parent type. Skip kUnknown and keep iterating until not kUnknown is found. Return the parent IRTYPE. 
    ** If parent_ is NULL. Return kUnknown instead. 
    */
    string get_parent_type_str(IR* cur_IR, int depth=0);
    IR* get_p_parent_with_a_type(IR* cur_IR, int depth=0);

    /**/
    bool is_exist_group_clause(IR*);
    bool is_exist_having_clause(IR*);
    bool is_exist_limit_clause(IR*);

    /**/
    vector<IR*> get_selectclauselist_vec(IR*);
    bool append_selectclause_clause_at_idx(IR* cur_stmt, IR* app_ir, string set_oper_str, int idx);
    bool remove_selectclause_clause_at_idx_and_free(IR* cur_stmt, int idx);
    // int get_num_selectclause(IR* cur_stmt) {return this->get_selectclauselist_vec(cur_stmt).size();}
    bool is_exist_UNION(IR* cur_stmt);
    bool is_exist_set_operator(IR* cur_stmt);

    bool is_exist_window_func_call(IR* cur_stmt);

    bool is_exist_func_call_generic(IR* cur_stmt);

    vector<IR*> get_select_items_in_select_stmt(IR* cur_stmt);
    int get_num_select_items_in_select_stmt(IR* cur_stmt) { return this->get_select_items_in_select_stmt(cur_stmt).size(); }

    bool is_ir_in(IR*, IR*);
    bool is_ir_in(IR*, IRTYPE);


    bool add_fields_to_insert_stmt(IR* cur_stmt);
    bool drop_fields_to_insert_stmt(IR* cur_stmt);
    vector<IR*> get_fields_in_stmt(IR* cur_stmt);
    int get_num_fields_in_stmt(IR* cur_stmt);

    bool add_kvalues_to_insert_stmt(IR* cur_stmt);
    bool drop_kvalues_to_insert_stmt(IR* cur_stmt);
    vector<vector<IR*>> get_kvalues_in_stmt(IR* cur_stmt);
    vector<IR*> get_kvalueslist_in_stmt(IR* cur_stmt);
    vector<IR*> get_kvalues_in_kvaluelist(IR* cur_stmt);
    int get_num_kvalues_in_stmt(IR* cur_stmt);

    void debug(IR* root, unsigned level);


private:
    IR* ir_root = nullptr;

};

#endif

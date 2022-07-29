#include "../include/ir_wrapper.h"
#include "../include/define.h"
#include "../AFL/debug.h"
#include "../include/utils.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <algorithm>
#include <cstring>

typedef NODETYPE IRTYPE;

bool IRWrapper::is_exist_ir_node_in_stmt_with_type(IRTYPE ir_type, bool is_subquery, int stmt_idx){
    vector<IR*> matching_IR_vec = this->get_ir_node_in_stmt_with_type(ir_type, is_subquery, stmt_idx);
    if (matching_IR_vec.size() == 0){
        return false;
    } else {
        return true;
    }
}

bool IRWrapper::is_exist_ir_node_in_stmt_with_type(IR* cur_stmt, IRTYPE ir_type, bool is_subquery) {
    vector<IR*> matching_IR_vec = this->get_ir_node_in_stmt_with_type(cur_stmt, ir_type, is_subquery);
    if (matching_IR_vec.size() == 0){
        return false;
    } else {
        return true;
    }
}


vector<IR*> IRWrapper::get_ir_node_in_stmt_with_type(IR* cur_stmt, 
    IRTYPE ir_type, bool is_subquery, bool is_ignore_subquery) {

    // Iterate IR binary tree, left depth prioritized.
    bool is_finished_search = false;
    std::vector<IR*> ir_vec_iter;
    std::vector<IR*> ir_vec_matching_type;
    IR* cur_IR = cur_stmt; 
    // Begin iterating. 
    while (!is_finished_search) {
        ir_vec_iter.push_back(cur_IR);
        if (cur_IR->type_ == ir_type) {
            ir_vec_matching_type.push_back(cur_IR);
        }

        if (cur_IR->left_ != nullptr){
            cur_IR = cur_IR->left_;
            continue;
        } else { // Reaching the most depth. Consulting ir_vec_iter for right_ nodes. 
            cur_IR = nullptr;
            while (cur_IR == nullptr){
                if (ir_vec_iter.size() == 0){
                    is_finished_search = true;
                    break;
                }
                cur_IR = ir_vec_iter.back()->right_;
                ir_vec_iter.pop_back();
            }
            continue;
        }
    }

    if (is_ignore_subquery) {
        return ir_vec_matching_type;
    }

    // Check whether IR node is in a SELECT subquery. 
    std::vector<IR*> ir_vec_matching_type_depth;
    for (IR* ir_match : ir_vec_matching_type){
        if(this->is_in_subquery(cur_stmt, ir_match) == is_subquery) {
            ir_vec_matching_type_depth.push_back(ir_match);
        }
        continue;
    }

    return ir_vec_matching_type_depth;

}

vector<IR*> IRWrapper::get_ir_node_in_stmt_with_id_type(IR* cur_stmt, 
    IDTYPE id_type, bool is_subquery, bool is_ignore_subquery) {

    // Iterate IR binary tree, left depth prioritized.
    bool is_finished_search = false;
    std::vector<IR*> ir_vec_iter;
    std::vector<IR*> ir_vec_matching_type;
    IR* cur_IR = cur_stmt; 
    // Begin iterating. 
    while (!is_finished_search) {
        ir_vec_iter.push_back(cur_IR);
        if (cur_IR->id_type_ == id_type) {
            ir_vec_matching_type.push_back(cur_IR);
        }

        if (cur_IR->left_ != nullptr){
            cur_IR = cur_IR->left_;
            continue;
        } else { // Reaching the most depth. Consulting ir_vec_iter for right_ nodes. 
            cur_IR = nullptr;
            while (cur_IR == nullptr){
                if (ir_vec_iter.size() == 0){
                    is_finished_search = true;
                    break;
                }
                cur_IR = ir_vec_iter.back()->right_;
                ir_vec_iter.pop_back();
            }
            continue;
        }
    }

    if (is_ignore_subquery) {
        return ir_vec_matching_type;
    }

    // Check whether IR node is in a SELECT subquery. 
    std::vector<IR*> ir_vec_matching_type_depth;
    for (IR* ir_match : ir_vec_matching_type){
        if(this->is_in_subquery(cur_stmt, ir_match) == is_subquery) {
            ir_vec_matching_type_depth.push_back(ir_match);
        }
        continue;
    }

    return ir_vec_matching_type_depth;

}

bool IRWrapper::is_in_subquery(IR* cur_stmt, IR* check_node) {
    IR* cur_iter = check_node;
    while (cur_iter) {
        if (cur_iter->type_ == kStatementList) { // Iter to the parent node. This is Not a subquery. 
            return false;
        }
        else if (cur_iter->parent_ == NULL) {
            return false;
        }
        else if (cur_iter->type_ == kSelectStatement && this->get_parent_type(cur_iter, 1) != kStatement)  // This IS a subquery. 
        {
            return true;
        }
        cur_iter = cur_iter->get_parent(); // Assuming cur_iter->get_parent() will always get to kStatementList. Otherwise, it would be error. 
        continue;
    }
    return false;
}

vector<IR*> IRWrapper::get_ir_node_in_stmt_with_type(IRTYPE ir_type, 
    bool is_subquery, int stmt_idx) { // (IRTYPE, subquery_level)

    if (stmt_idx < 0) {
        FATAL("Checking on non-existing stmt. Function: IRWrapper::get_ir_node__in_stmt_with_type. Idx < 0. idx: '%d' \n", stmt_idx);
    }
    IR* cur_stmt = this->get_ir_node_for_stmt_with_idx(stmt_idx);

    return this->get_ir_node_in_stmt_with_type(cur_stmt, ir_type, is_subquery);
}

IR* IRWrapper::get_ir_node_for_stmt_with_idx(int idx) {

    if (idx < 0) {
        FATAL("Checking on non-existing stmt. Function: IRWrapper::get_ir_node_for_stmt_with_idx(). Idx < 0. idx: '%d' \n", idx);
    }

    if (this->ir_root == nullptr){
        FATAL("Root IR not found in IRWrapper::get_ir_node_for_stmt_with_idx(); Forgot to initilize the IRWrapper? \n");
    }

    vector<IR*> stmt_v = this->get_stmt_ir_vec();
    if (stmt_v.size() > 0 && idx >= 0 && idx < int(stmt_v.size()) ) { 
        return stmt_v[idx];
    } else {
        return NULL;
    }
}

bool IRWrapper::is_ir_before(IR* f, IR* l){
    return this->is_ir_after(l, f);
}

bool IRWrapper::is_ir_after(IR* f, IR* l){
    if (this->ir_root == nullptr){
        FATAL("Root IR not found in IRWrapper::is_ir_before/after(); Forgot to initilize the IRWrapper? \n");
    }

    // Left depth prioritized iteration. Should found l first if IR f is behind(after) l. 
    // Iterate IR binary tree, left depth prioritized.
    bool is_finished_search = false;
    std::vector<IR*> ir_vec_iter;
    IR* cur_IR = this->ir_root; 
    // Begin iterating. 
    while (!is_finished_search) {
        ir_vec_iter.push_back(cur_IR);
        if (cur_IR == l) {
            return true;
        } else if (cur_IR == f) {
            return false;
        }

        if (cur_IR->left_ != nullptr){
            cur_IR = cur_IR->left_;
            continue;
        } else { // Reaching the most depth. Consulting ir_vec_iter for right_ nodes. 
            cur_IR = nullptr;
            while (cur_IR == nullptr){
                if (ir_vec_iter.size() == 0){
                    is_finished_search = true;
                    break;
                }
                cur_IR = ir_vec_iter.back()->right_;
                ir_vec_iter.pop_back();
            }
            continue;
        }
    }

    FATAL("Cannot find curent IR in the IR tree. Function IRWrapper::is_ir_after(). \n");

}

vector<IRTYPE> IRWrapper::get_all_ir_type(){

    vector<IR*> stmt_v = this->get_stmt_ir_vec();

    vector<IRTYPE> all_types;
    for (auto iter = stmt_v.begin(); iter != stmt_v.end(); iter++){
        all_types.push_back((**iter).type_);
    }
    return all_types;

}

int IRWrapper::get_stmt_num(){
    return this->get_stmt_ir_vec().size();
}

int IRWrapper::get_stmt_num(IR* cur_root) {
    if (cur_root->type_ != kProgram) {
        cerr << "Error: Receiving NON-kProgram root. Func: IRWrapper::get_stmt_num(IR* cur_root). Aboard!\n";
        FATAL("Error: Receiving NON-kProgram root. Func: IRWrapper::get_stmt_num(IR* cur_root). Aboard!\n");
    }
    this->set_ir_root(cur_root);
    return this->get_stmt_num();
}

vector<IR*> IRWrapper::get_stmtlist_IR_vec(){
    IR* stmt_IR_p = this->ir_root->left_;
    vector<IR*> stmt_list_v_rev, stmt_list_v;


    while (true){ // Iterate from the last kstatementlist to the first. 
        stmt_list_v_rev.push_back(stmt_IR_p);
        if (stmt_IR_p->right_ == nullptr || stmt_IR_p->left_ == nullptr) break; // This is the first kstatementlist. 

        stmt_IR_p = stmt_IR_p -> left_; // Lead to the previous kstatementlist. 
    }

    // Reverse the list from the first statmentlist to the last. 
    for (auto v = stmt_list_v_rev.rbegin(); v != stmt_list_v_rev.rend(); v++){
        stmt_list_v.push_back(*v);
    }

    return stmt_list_v;
}

bool IRWrapper::append_stmt_after_idx(string app_str, int idx, Mutator& g_mutator){

    vector<IR*> stmt_list_v = this->get_stmtlist_IR_vec();

    if (idx < -1 || idx >= int(stmt_list_v.size())){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::append_stmt_after_idx(). \n";
        return false;
    }

    // Parse and get the new statement. 
    vector<IR*> app_IR_vec = g_mutator.parse_query_str_get_ir_set(app_str);
    IR* app_IR_node = app_IR_vec.back()->left_->left_->left_;  // Program -> kStatementlist -> kStatement -> kSpecificStmt 
    app_IR_node = app_IR_node->deep_copy();
    app_IR_vec.back()->deep_drop();
    app_IR_vec.clear();

    return this->append_stmt_after_idx(app_IR_node, idx);

}

bool IRWrapper::append_stmt_at_end(string app_str, Mutator& g_mutator) {

    vector<IR*> stmt_list_v = this->get_stmtlist_IR_vec();

    // Parse and get the new statement. 
    vector<IR*> app_IR_vec = g_mutator.parse_query_str_get_ir_set(app_str);
    IR* app_IR_node = app_IR_vec.back()->left_->left_->left_;  // Program -> Statementlist -> Statement -> kSpecificStmt
    app_IR_node = app_IR_node->deep_copy();
    app_IR_vec.back()->deep_drop();
    app_IR_vec.clear();

    return this->append_stmt_after_idx(app_IR_node, stmt_list_v.size()-1);
    
}

bool IRWrapper::append_stmt_after_idx(IR* app_IR_node, int idx) { // Please provide with IR* (Statement*) type, do not provide IR*(StatementList*) type. 
    vector<IR*> stmt_list_v = this->get_stmtlist_IR_vec();

    if (idx < -1 || idx >= int(stmt_list_v.size())  ){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::append_stmt_after_idx(). \n";
        std::cerr << "Error: Input index " << to_string(idx) << "; stmt_list_v size(): " << stmt_list_v.size() << ".\n";
        return false;
    }

    app_IR_node = new IR(kStatement, OP0(), app_IR_node);

    if (idx != -1) {
        IR* insert_pos_ir = stmt_list_v[idx];

        auto new_res = new IR(kStatementList, OPMID(";"), NULL, app_IR_node);

        if (!ir_root->swap_node(insert_pos_ir, new_res)){ // swap_node only rewrite the parent of insert_pos_ir, it will not affect     insert_pos_ir. 
            new_res->deep_drop();
            // FATAL("Error: Swap node failure? In function: IRWrapper::append_stmt_after_idx. \n");
            std::cerr << "Error: Swap node failure? In function: IRWrapper::append_stmt_after_idx. idx = " << idx << "\n";
            return false;
        }

        new_res->update_left(insert_pos_ir);

        return true;
    } else { // idx == -1
        IR * insert_before_pos_ir = stmt_list_v[0];

        auto starting_res = new IR(kStatementList, OP0(), NULL);
        auto second_res = new IR(kStatementList, OPMID(";"), starting_res, insert_before_pos_ir->left_->deep_copy());

        if (!ir_root->swap_node(insert_before_pos_ir, second_res)) {
            second_res->deep_drop();
            starting_res->deep_drop();
            std::cerr << "Error: Swap node failure? In function: IRWrapper::append_stmt_after_idx. idx = 0; \n";
            return false;
        }

        starting_res->update_left(app_IR_node);
        insert_before_pos_ir->deep_drop(); // We already deep_copied it. We use the new one, free the original. 

        return true;
        
    }

}

bool IRWrapper::append_stmt_at_end(IR* app_IR_node) { // Please provide with IR* (Statement*) type, do not provide IR*(StatementList*) type. 

    int total_num = this->get_stmt_num();
    return this->append_stmt_after_idx(app_IR_node, total_num-1);

    return false;

}

bool IRWrapper::remove_stmt_at_idx_and_free(unsigned idx){

    vector<IR*> stmt_list_v = this->get_stmtlist_IR_vec();

    if (idx >= int(stmt_list_v.size()) || idx < 0){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::remove_stmt_at_idx_and_free(). \n";
        return false;
    }

    if (stmt_list_v.size() == 1) {
        // std::cerr << "Error: Cannot remove stmt becuase there is only one stmt left in the query. \n In function IRWrapper::remove_stmt_at_idx_and_free(). \n";
        return false;
    }

    IR* rov_stmt = stmt_list_v[idx];

    // For removing idx 0, we need to rewrite idx 1 to fit in the specific format of statementlist idx 0. 
    if (idx == 0){
        IR* next_stmt = stmt_list_v[1];
        IR* new_next_stmt = new IR(kStatementList, OP0(), next_stmt->right_->deep_copy());
        if (!this->ir_root->swap_node(next_stmt, new_next_stmt)){
            cerr << "Error: swap_node failure. idx: " << idx << ". In function: IRWrapper::remove_stmt_at_idx_and_free(); \n";
            new_next_stmt->deep_drop();
            return false;
        }
        next_stmt->deep_drop(); // next_stmt->deep_drop() will lead to rov_stmt, because next_stmt->left_ is rov_stmt. 
        // rov_stmt->deep_drop();

    } else { 
        IR* prev_stmt = stmt_list_v[idx-1];
        if (!this->ir_root->swap_node(rov_stmt, prev_stmt)){
            cerr << "Error: swap_node failure. idx: " << idx << ". In function: IRWrapper::remove_stmt_at_idx_and_free(); \n";
            return false;
        }
        rov_stmt->left_ = nullptr; // Cut the connection between rov_stmt and prev_stmt, prevent accidentally deep_drop for prev_stmt. 
        rov_stmt->deep_drop();
    }

    return true;

}


vector<IR*> IRWrapper::get_stmt_ir_vec() {
    vector<IR*> stmtlist_vec = this->get_stmtlist_IR_vec(), stmt_vec;
    if (stmtlist_vec.size() == 0) return stmt_vec;

    stmt_vec.push_back(stmtlist_vec[0]->left_->left_); // kStatementlist -> kStatement -> specific_statement_type

    if (stmtlist_vec.size() > 1) {
        for (int i = 1; i < stmtlist_vec.size(); i++){
            stmt_vec.push_back(stmtlist_vec[i]->right_->left_); // kStatementlist -> kStatement -> specific_statement_type
        }
    }
    
    // // DEBUG
    // for (auto stmt : stmt_vec) {
    //     cerr << "In func: IRWrapper::get_stmt_ir_vec(), we have stmt_vec type_: " << get_string_by_ir_type(stmt->type_) << "\n";
    // }

    return stmt_vec;
}

bool IRWrapper::remove_stmt_and_free(IR* rov_stmt) {
    vector<IR*> stmt_vec = this->get_stmt_ir_vec();
    int stmt_idx = -1;
    for (int i = 0; i < stmt_vec.size(); i++) {
        if (stmt_vec[i] == rov_stmt) {stmt_idx = i; break;}
    }
    if (stmt_idx == -1) {return false;}
    else {
        return this->remove_stmt_at_idx_and_free(stmt_idx);
    }
}

bool IRWrapper::append_components_at_ir(IR* parent_node, IR* app_node, bool is_left, bool is_replace) {
    if (is_left) {
        if (parent_node->left_ != nullptr) {
            if (!is_replace) {
                cerr << "Append location has content, use is_replace=true if necessary. Function: IRWrapper::append_components_at_ir. \n";
                return false;
            }
            IR* old_node = parent_node->left_;
            parent_node->detach_node(old_node);
            old_node->deep_drop();
        }
        parent_node->update_left(app_node);
        return true;
    } else {
        if (parent_node->right_ != nullptr) {
            if (!is_replace) {
                cerr << "Append location has content, use is_replace=true if necessary. Function: IRWrapper::append_components_at_ir. \n";
                return false;
            }
            IR* old_node = parent_node->right_;
            parent_node->detach_node(old_node);
            old_node->deep_drop();
        }
        parent_node->update_right(app_node);
        return true;
    }
}

bool IRWrapper::remove_components_at_ir(IR* rov_ir) {
    if (rov_ir && rov_ir->parent_) {
        IR* parent_node = rov_ir->get_parent();
        parent_node->detach_node(rov_ir);
        rov_ir->deep_drop();
        return true;
    }
    cerr << "Error: rov_ir or rov_ir->parent_ are nullptr. Function IRWrapper::remove_components_at_ir() \n";
    return false;
}

vector<IR*> IRWrapper::get_all_ir_node (IR* cur_ir_root) {
    this->ir_root = cur_ir_root; 
    return this->get_all_ir_node();
}

vector<IR*> IRWrapper::get_all_ir_node() {
    if (this->ir_root == nullptr) {
        std::cerr << "Error: IRWrapper::ir_root is nullptr. Forget to initilized? \n";
    }
    // Iterate IR binary tree, depth prioritized. (not left depth prioritized)
    bool is_finished_search = false;
    std::vector<IR*> ir_vec_iter;
    std::vector<IR*> all_ir_node_vec;
    IR* cur_IR = this->ir_root;
    // Begin iterating. 
    while (!is_finished_search) {
        ir_vec_iter.push_back(cur_IR);
        if (cur_IR->type_ != kProgram) 
            {all_ir_node_vec.push_back(cur_IR);} // Ignore kProgram at the moment, put it at the end of the vector. 

        if (cur_IR->left_ != nullptr){
            cur_IR = cur_IR->left_;
            continue;
        } else { // Reaching the most depth. Consulting ir_vec_iter for right_ nodes. 
            cur_IR = nullptr;
            while (cur_IR == nullptr){
                if (ir_vec_iter.size() == 0){
                    is_finished_search = true;
                    break;
                }
                cur_IR = ir_vec_iter.back()->right_;
                ir_vec_iter.pop_back();
            }
            continue;
        }
    }
    all_ir_node_vec.push_back(this->ir_root);
    return all_ir_node_vec;
}

int IRWrapper::get_stmt_idx(IR* cur_stmt){
    vector<IR*> all_stmt_vec = this->get_stmt_ir_vec();
    int output_idx = -1;
    int count = 0;
    for (IR* iter_stmt : all_stmt_vec) {
        if (iter_stmt == cur_stmt) {
            output_idx = count;
            break;
        }
        count++;
    }
    return output_idx;
}

bool IRWrapper::replace_stmt_and_free(IR* old_stmt, IR* new_stmt) {
    int old_stmt_idx = this->get_stmt_idx(old_stmt);
    if (old_stmt_idx < 0) {
        // cerr << "Error: old_stmt_idx < 0. Old_stmt_idx: " << old_stmt_idx << ". In func: IRWrapper::replace_stmt_and_free. \n"; 
        return false;
    }
    if (!this->remove_stmt_at_idx_and_free(old_stmt_idx)){
        // cerr << "Error: child function remove_stmt_at_idx_and_free returns error. In func: IRWrapper::replace_stmt_and_free. \n"; 
        return false;
    }
    if (!this->append_stmt_after_idx(new_stmt, old_stmt_idx-1)){
        // cerr << "Error: child function append_stmt_after_idx returns error. In func: IRWrapper::replace_stmt_and_free. \n";
        return false;
    }
    return true;
}

IRTYPE IRWrapper::get_parent_type(IR* cur_IR, int depth){
    IR* output_IR = this->get_parent_with_a_type(cur_IR, depth);
    if (output_IR == nullptr) {
        return kUnknown;
    } else {
        return output_IR->type_;
    }
}

IR* IRWrapper::get_parent_with_a_type(IR* cur_IR, int depth) {
    while (cur_IR ->parent_ != nullptr) {
        IRTYPE parent_type = cur_IR->parent_->type_;
        if (parent_type != kUnknown) {
            depth--;
            if (depth <= 0) {
                return cur_IR->parent_;
            }   
        }
        cur_IR = cur_IR->parent_;
    }
    cerr << "Error: Find get_parent_type without parent_? \n";
    return nullptr;
}

IR* IRWrapper::add_cast_expr(IR* ori_expr, string column_type_str) {
    
    auto new_column_type_ir = new IR(kOptColumnNullable, column_type_str);
    auto res = new IR(kNewExpr, OP3("CAST (", "AS", ")"), ori_expr->deep_copy(), new_column_type_ir);

    if (!ir_root->swap_node(ori_expr, res)) {
        res->deep_drop();
        // FATAL("Error: Swap node failure? In function: IRWrapper::append_stmt_after_idx. \n");
        std::cerr << "Error: Swap node failure? In function: IRWrapper::add_cast_expr. \n";
        return nullptr;
    }

    ori_expr->deep_drop();
    return res;

}

IR* IRWrapper::add_func(IR* ori_expr, string func_name_str) {
    
    // For func_name
    auto new_identifier_ir = new IR(kIdentifier, func_name_str, id_whatever);
    auto func_name_ir = new IR(kFunctionName, OP0(), new_identifier_ir);
    // For func_args
    auto opt_distinct_ir = new IR(kOptDistinct, ""); // Do not use DISTINCT or ALL. 
    auto expr_list_ir = new IR(kExprList, OP0(), ori_expr->deep_copy());
    auto func_args_ir = new IR(kFunctionArgs, OP0(), opt_distinct_ir, expr_list_ir);
    // For opt_filter_clause
    auto opt_filter_ir = new IR(kOptFilterClause, string(""));
    // For opt_over_clause
    auto opt_over_ir = new IR(kOptOverClause, string(""));

    // Build the function ir
    auto new_expr_ir = new IR(kUnknown, OP3("", "(", ")"), func_name_ir, func_args_ir);
    new_expr_ir = new IR(kUnknown, OP0(), new_expr_ir, opt_filter_ir);
    new_expr_ir = new IR(kNewExpr, OP0(), new_expr_ir, opt_over_ir);


    if (!ir_root->swap_node(ori_expr, new_expr_ir)) {
        new_expr_ir->deep_drop();
        // FATAL("Error: Swap node failure? In function: IRWrapper::append_stmt_after_idx. \n");
        std::cerr << "Error: Swap node failure? In function: IRWrapper::add_func. \n";
        return nullptr;
    }

    ori_expr->deep_drop();
    return new_expr_ir;

}

IR* IRWrapper::add_binary_op(IR* ori_expr, IR* left_stmt_expr, IR*
    right_stmt_expr, string op_value, bool is_free_left,
    bool is_free_right) {

    // For Binary_op
    auto binary_op_ir = new IR(kBinaryOp, op_value);

    auto new_expr_ir = new IR(kUnknown, OP2("(", ")"), left_stmt_expr->deep_copy(), binary_op_ir);
    new_expr_ir = new IR(kNewExpr, OP0(), new_expr_ir, right_stmt_expr->deep_copy());

    if (!ir_root->swap_node(ori_expr, new_expr_ir)) {
        new_expr_ir->deep_drop();
        // FATAL("Error: Swap node failure? In function: IRWrapper::append_stmt_after_idx. \n");
        std::cerr << "Error: Swap node failure? In function: IRWrapper::add_binary_op. \n";
        return nullptr;
    }

    ori_expr->deep_drop();
    if (is_free_left) {left_stmt_expr->deep_drop();}
    if (is_free_right) {right_stmt_expr->deep_drop();}
    return new_expr_ir;

}


bool IRWrapper::is_exist_group_by(IR* cur_stmt){
    if (this->is_exist_ir_node_in_stmt_with_type(cur_stmt, kOptGroup, false)) {
        vector<IR *> all_opt_group = this->get_ir_node_in_stmt_with_type(cur_stmt, kOptGroup, false);
        for (IR *cur_opt_group : all_opt_group) {
            if (cur_opt_group != nullptr && cur_opt_group->op_ != nullptr && 
                strcmp(cur_opt_group->op_->prefix_, "GROUP BY") == 0) {
                return true;
            }
        }
    }
    return false;
}

bool IRWrapper::is_exist_having(IR* cur_stmt){
    if (this->is_exist_ir_node_in_stmt_with_type(cur_stmt, kOptGroup, false)) {
        vector<IR *> all_opt_group = this->get_ir_node_in_stmt_with_type(cur_stmt, kOptGroup, false);
        for (IR *cur_opt_group : all_opt_group) {
            if (cur_opt_group->right_ != nullptr) {
                IR* opt_having = cur_opt_group->right_;
                if (opt_having->op_ != nullptr && 
                    strcmp(opt_having->op_->prefix_, "HAVING") == 0) {
                    return true;
                }
            }
        }
    }
    return false;
}

bool IRWrapper::is_exist_distinct(IR* cur_stmt) {
    vector<IR*> opt_distinct_vec = this->get_ir_node_in_stmt_with_type(cur_stmt, kOptDistinct, false);
    for (IR* opt_distinct_ir : opt_distinct_vec) {
        if (opt_distinct_ir && 
            opt_distinct_ir->op_ &&
            strcmp(opt_distinct_ir->op_->prefix_, "DISTINCT") == 0) {
            return true;
        }
    }
    return false;
}

IR* IRWrapper::get_result_column_in_select_clause_in_select_stmt(IR* cur_stmt, int idx){
    // if (cur_stmt->type_ != kSelectStatement) {
    //     cerr << "Error: get_result_column_in_select_clause_in_select_stmt() not receiving kSelectStatement. \n";
    //     cerr << "Receiving " << cur_stmt->type_ << endl;
    //     return nullptr;
    // }
    vector<IR*> all_result_column_list = get_result_column_list_in_select_clause(cur_stmt);
    if (idx >= int(all_result_column_list.size()) || idx < 0) {
        cerr << "Error, idx exceeding the total number of ResultColumnList in the select clause. \n";
        return nullptr;
    }
    IR* cur_result_column_list = all_result_column_list[idx];
    if (idx == 0) {
        return cur_result_column_list->left_;
    } else {
        return cur_result_column_list->right_;
    }
}

vector<IR*> IRWrapper::get_result_column_list_in_select_clause(IR* cur_stmt){

    IR* match_column_list = nullptr;
    vector<IR*> match_column_list_vec_rev, match_column_list_vec;
    vector<IR*> select_result_column_list_vec = this->get_ir_node_in_stmt_with_type(cur_stmt, kResultColumnList, false);
    for (IR* cur_select_result_column_list : select_result_column_list_vec) {
      if (
        this->get_parent_type(cur_select_result_column_list, 1) == kSelectCore
      ) {match_column_list = cur_select_result_column_list;} // This is the last expr. 
    }

    if (match_column_list != nullptr) {
        match_column_list_vec_rev.push_back(match_column_list);
        while (match_column_list->right_ != nullptr) {
            match_column_list = match_column_list->right_;
            match_column_list_vec_rev.push_back(match_column_list);
        }
        for (auto iter = match_column_list_vec_rev.rbegin(); iter != match_column_list_vec_rev.rend(); iter++){
            match_column_list_vec.push_back(*iter);
        }
    }
    return match_column_list_vec;
}

int IRWrapper::get_num_result_column_in_select_clause(IR* cur_stmt) {
    return this->get_result_column_list_in_select_clause(cur_stmt).size();
}

bool IRWrapper::add_without_rowid_to_stmt(IR* cur_stmt){
    if (
        !this->is_exist_ir_node_in_stmt_with_type(cur_stmt, kCreateTableStatement, false) &&
        !this->is_exist_ir_node_in_stmt_with_type(cur_stmt, kCreateVirtualTableStatement, false)
    ) { 
        cerr << "Error: cur_stmt is not a CREATE statement. Func: IRWrapper::add_without_rowid_to_stmt(IR* cur_stmt). \n";
        return false;
    }

    vector<IR*> without_rowid_vec = this->get_ir_node_in_stmt_with_type(cur_stmt, kOptWithoutRowID, false);
    for (auto without_rowid_ir : without_rowid_vec) {
        if (without_rowid_ir == nullptr) {continue;}
        if (without_rowid_ir->op_ == nullptr) without_rowid_ir->op_ = new IROperator();
        without_rowid_ir->op_->prefix_ = "WITHOUT ROWID";
    }
    return true;
}

bool IRWrapper::remove_without_rowid_to_stmt(IR* cur_stmt){
    if (
        !this->is_exist_ir_node_in_stmt_with_type(cur_stmt, kCreateTableStatement, false) &&
        !this->is_exist_ir_node_in_stmt_with_type(cur_stmt, kCreateVirtualTableStatement, false)
    ) { 
        cerr << "Error: cur_stmt is not a CREATE statement. Func: IRWrapper::remove_without_rowid_to_stmt(IR* cur_stmt). \n";
        return false;
    }

    vector<IR*> without_rowid_vec = this->get_ir_node_in_stmt_with_type(cur_stmt, kOptWithoutRowID, false);
    for (auto without_rowid_ir : without_rowid_vec) {
        if (without_rowid_ir == nullptr) {continue;}
        if (without_rowid_ir->op_ == nullptr) without_rowid_ir->op_ = new IROperator();
        without_rowid_ir->op_->prefix_ = "";
    }
    return true;
}

bool IRWrapper::combine_stmt_in_selectcore(IR* left_stmt, IR* right_stmt, string set_operator_str, bool is_free_left, bool is_free_right) {
    if (!this->is_exist_ir_node_in_stmt_with_type(left_stmt, kSelectStatement, false)) {
        cerr << "Error: The left_stmt received is not a SELECT stmt. Cannot combine it to selectcore clause. "
             << "Func: IRWrapper::combine_stmt_in_selectcore(IR* left_stmt, IR* right_stmt, string set_operator_str). \n";
        return false;
    }
    if (!this->is_exist_ir_node_in_stmt_with_type(right_stmt, kSelectStatement, false)) {
        cerr << "Error: The right_stmt received is not a SELECT stmt. Cannot combine it to selectcore clause. "
             << "Func: IRWrapper::combine_stmt_in_selectcore(IR* left_stmt, IR* right_stmt, string set_operator_str). \n";
        return false;
    }

    IR* cur_stmt = left_stmt;
    IR* cur_selectcorelist = cur_stmt->left_->right_;  // This should be the last kselectcorelist or kselectcore in the stmt. 

    IR* right_selectcorelist = right_stmt->left_->right_;
    IR* right_selectcore;
    if (right_selectcorelist->type_ == kSelectCoreList) {
        // Iterate to the very first right_select_core_list in order. 
        while (right_selectcorelist->left_->type_ != kSelectCore ) {
            right_selectcorelist = right_selectcorelist->left_;
        }
        right_selectcore = right_selectcorelist->left_->deep_copy();
        right_selectcore->parent_ = nullptr;
    } else {
        right_selectcore = right_selectcorelist->deep_copy();
    }

    IR* set_op = new IR(kSetOperator, set_operator_str);
    IR* new_selectcorelist = new IR(kUnknown, OP0(), cur_selectcorelist->deep_copy(), set_op);
    new_selectcorelist = new IR(kSelectCoreList, OP0(), new_selectcorelist, right_selectcore);

    if(!cur_stmt->swap_node(cur_selectcorelist, new_selectcorelist)){
        new_selectcorelist->deep_drop();
        cerr << "Error: Swap node failure; in Func: IRWrapper::combine_stmt_in_selectcore(IR* left_stmt, IR* right_stmt, string set_operator_str, bool is_free_left, bool is_free_right)" << endl;
        return false;
    }
    cur_selectcorelist->deep_drop();

    if (is_free_left) {left_stmt->deep_drop();}
    if (is_free_right) {right_stmt->deep_drop();}
    
    return true;
}

IR* IRWrapper::get_alias_iden_from_tablename_iden(IR* tablename_iden){
    IR *opt_alias_ir = tablename_iden->parent_->parent_->right_; // identifier -> ktablename -> parent_ -> kOptTableAliasAs
    if (opt_alias_ir != nullptr &&
        opt_alias_ir->op_ != nullptr &&
        (opt_alias_ir->type_ == kOptTableAlias || opt_alias_ir->type_ == kOptTableAliasAs) &&
        strcmp(opt_alias_ir->op_->prefix_, "AS") == 0) {
        if (opt_alias_ir->left_ != nullptr && opt_alias_ir->left_->left_ != nullptr) { // kOptTableAliasAs -> kTableAlias ->  identifier.
            return opt_alias_ir->left_->left_;
        }
    }
    return nullptr;
}

IRTYPE IRWrapper::get_cur_stmt_type(IR* cur_ir) {
    while (cur_ir->parent_ != nullptr) {
        if (cur_ir->type_ == kStatement) {
            return cur_ir->left_->type_;
        }
        if (cur_ir->type_ == kStatementList) {
            if (cur_ir->right_ == nullptr) {
                if (cur_ir->left_->type_ == kStatement) {return cur_ir->left_->left_->type_;}
                else {return cur_ir->left_->type_;}
            }
            else {
                if (cur_ir->right_->type_ == kStatement) {return cur_ir->right_->left_->type_;}
                else {return cur_ir->right_->type_;}
            }
        }
        cur_ir = cur_ir->parent_;
    }
    return kUnknown;
}

vector<IR*> IRWrapper::get_selectcore_vec(IR* cur_stmt){
    if (cur_stmt->type_ != kSelectStatement) {
        // cerr << "Error: Not receiving kSelectStatement in the func: IRWrapper::get_selectcore_vec(). \n";
        vector<IR*> tmp; return tmp;
    }

    vector<IR*> res_selectcore_vec;
    IR* cur_selectcorelist = cur_stmt->left_->right_;

    // Only one entry. Doesn't have kSelectCoreList struct. 
    if (cur_selectcorelist->type_ == kSelectCore) {
        res_selectcore_vec.push_back(cur_selectcorelist); 
        return res_selectcore_vec;
    }

    bool is_finished = false;
    while (!is_finished) {
        if (cur_selectcorelist->type_ == kSelectCoreList) 
            {res_selectcore_vec.push_back(cur_selectcorelist->right_);}  // kSelectcoreList -> kSelectcore
        else if (cur_selectcorelist->type_ == kSelectCore) {
            res_selectcore_vec.push_back(cur_selectcorelist);  // The first kSelectcore. 
            is_finished = true; 
            break;
        }
        cur_selectcorelist = cur_selectcorelist->left_;
    }

    // Reverse the order of the list. After reversion, the order is from the first kSelectcore to the last one. 
    reverse(res_selectcore_vec.begin(), res_selectcore_vec.end()); 
    return res_selectcore_vec;
}

bool IRWrapper::append_selectcore_clause_after_idx(IR* cur_stmt, IR* app_ir, string set_oper_str, int idx) {
    if (app_ir->type_ != kSelectCore) {
        cerr << "Error: Not receiving kSelectCore in the func: IRWrapper::append_selectcore_clause(). \n";
        return false;
    }
    if (cur_stmt->type_ != kSelectStatement) {
        cerr << "Error: Not receiving kSelectStatement in the func: IRWrapper::append_selectcore_clause(). \n";
        return false;
    }

    vector<IR*> selectcore_vec = this->get_selectcore_vec(cur_stmt);
    if (int(selectcore_vec.size()) > idx) {
        cerr << "Idx exceeding the maximum number of selectcore in the statement. \n";
        return false;
    }

    if (idx >= 0) {
        IR* app_pos_ir;
        if (idx > 0) {app_pos_ir = selectcore_vec[idx]->parent_;}  // kSelectCore -> kSelectCoreList
        else {app_pos_ir = selectcore_vec[idx];} // There is no kSelectCoreList for the first entry. 
        IR* set_operator_ir = new IR(kSetOperator, set_oper_str);

        auto new_selectcorelist = new IR(kUnknown, OP0(), NULL, set_operator_ir);
        new_selectcorelist = new IR(kSelectCoreList, OP0(), new_selectcorelist, app_ir);

        if (!cur_stmt->swap_node(app_pos_ir, new_selectcorelist)) {
            new_selectcorelist->deep_drop();
            std::cerr << "IRWrapper::append_selectcore_clause_after_idx. idx = " << idx << "\n";
            return false;
        }
        new_selectcorelist->left_->update_left(app_pos_ir);
        return true;
    } else if (idx == -1) {

        IR* app_pos_ir = selectcore_vec[0]; // This is a kSelectCore, NOT A kSelectCoreList!!!

        IR* set_operator_ir = new IR(kSetOperator, set_oper_str);
        auto starting_res = app_ir;
        auto second_res = new IR(kUnknown, OP0(), starting_res, set_operator_ir);
        second_res = new IR(kSelectCoreList, OP0(), second_res, NULL);

        if (!cur_stmt->swap_node(app_pos_ir, second_res)) {
            second_res->deep_drop();
            std::cerr << "IRWrapper::append_selectcore_clause_after_idx. idx = " << idx << "\n";
            return false;
        }
        second_res->update_right(app_pos_ir);
        return true;

    } else {
        std::cerr << "In func: IRWrapper::append_selectcore_clause_after_idx(), Idx not making sense. idx: " << idx << ". \n";
        return false;
    }
}

bool IRWrapper::remove_selectcore_clause_at_idx_and_free(IR* cur_stmt, int idx) {
    vector<IR*> selectcore_vec = this->get_selectcore_vec(cur_stmt);
    if (idx >= int(selectcore_vec.size()) || idx < 0) {
        cerr << "Error: Idx exceeding selectcorelist size, or idx < 0. idx: " << idx 
             << ". Func: IRWrapper::remove_selectcore_clause_at_idx_and_free. \n";
        return false;
    }

    if (selectcore_vec.size() == 1) {
        cerr << "Cannot remove current selectcore becuase there is only one selectcore left in the select statement. \n In function IRWrapper::remove_selectcore_clause_at_idx_and_free.";
        return false;
    }

    if (idx == 0) {
        IR* next_selectcore_ir = selectcore_vec[1]->deep_copy();
        IR* next_selectcorelist_ir = selectcore_vec[1]->parent_; // kSelectCore -> kSelectCoreList
        if (!cur_stmt->swap_node(next_selectcorelist_ir, next_selectcore_ir)) {
            next_selectcore_ir->deep_drop();
            cerr << "swap_node failed: Func: IRWrapper::remove_selectcore_clause_at_idx_and_free(); \n";
            return false;
        }
        next_selectcorelist_ir->deep_drop(); // Remove the kSelectCore for the first statement, and the kSelectCorelist for the second statment. 
        return true;
    } else {
        IR* prev_selectcore_ir;
        if (idx == 1) { prev_selectcore_ir = selectcore_vec[0]->deep_copy(); }
        else { prev_selectcore_ir = selectcore_vec[idx-1]->parent_->deep_copy(); }
        IR* rov_selectcore_ir = selectcore_vec[idx]->parent_; // kSelectCore -> kSelectCoreList -> unknown_parent

        if (!cur_stmt->swap_node(rov_selectcore_ir, prev_selectcore_ir)) {
            prev_selectcore_ir->deep_drop();
            cerr << "swap_node failed: Func: IRWrapper::remove_selectcore_clause_at_idx_and_free(); \n";
            return false;
        }

        rov_selectcore_ir->deep_drop(); // Remove all the child nodes. Including the original prev_selectcore_ir. 
        return true;
    }
}

int IRWrapper::get_num_selectcore(IR* cur_stmt) {
    return this->get_selectcore_vec(cur_stmt).size();
}

IR* IRWrapper::get_stmt_ir_from_child_ir(IR* cur_ir) {
    while (cur_ir->type_ != kStatement && cur_ir->parent_ != nullptr) {
        if (cur_ir->type_ == kProgram) {return nullptr;}
        cur_ir = cur_ir->parent_;
    }

    if (cur_ir->type_ == kStatement) {return cur_ir->left_;}
    else {return nullptr;}
}

/* Not exactly accurate. */
IR* IRWrapper::find_closest_node_exclude_child (IR* cur_node, IRTYPE type_) {
    IR* v_res;
    if (cur_node->type_ == type_) {
        return cur_node;
    }

    bool is_left_ = false;
    IR* parent_cur_node = NULL;
    while (cur_node->parent_ != NULL) {
        parent_cur_node = cur_node->parent_;
        if (cur_node == parent_cur_node->right_) {
            is_left_ = true;
        } else {
            is_left_ = false;
        }
        cur_node = parent_cur_node;
        if (cur_node->type_ == type_) {
            return cur_node;
        }
        if (is_left_) {
            if (cur_node->left_ == NULL) {
                continue;
            }
            vector<IR*> matched_node = this -> get_ir_node_in_stmt_with_type(cur_node->left_, type_, false, true); // ignore is_in_subquery. 
            if (matched_node.size() > 0) {
                // TODO:: inaccurate here. 
                return matched_node[0];
            }
        } else {
            if (cur_node->right_ == NULL) {
                continue;
            }
            vector<IR*> matched_node = this -> get_ir_node_in_stmt_with_type(cur_node->right_, type_, false, true); // ignore is_in_subquery. 
            if (matched_node.size() > 0) {
                // TODO:: inaccurate here. 
                return matched_node[0];
            }
        }
    }

    return NULL;
}

/* Not exactly accurate. */
IR* IRWrapper::find_closest_node_exclude_child (IR* cur_node, IDTYPE id_type_) {
    IR* v_res;
    if (cur_node->id_type_ == id_type_) {
        return cur_node;
    }

    bool is_left_ = false;
    IR* parent_cur_node = NULL;
    while (cur_node->parent_ != NULL) {
        parent_cur_node = cur_node->parent_;
        if (cur_node == parent_cur_node->right_) {
            is_left_ = true;
        } else {
            is_left_ = false;
        }
        cur_node = parent_cur_node;
        if (cur_node->id_type_ == id_type_) {
            return cur_node;
        }
        if (is_left_) {
            if (cur_node->left_ == NULL) {
                continue;
            }
            vector<IR*> matched_node = this -> get_ir_node_in_stmt_with_id_type(cur_node->left_, id_type_, false, true); // ignore is_in_subquery. 
            if (matched_node.size() > 0) {
                // TODO:: inaccuracy here. 
                return matched_node[0];
            }
        } else {
            if (cur_node->right_ == NULL) {
                continue;
            }
            vector<IR*> matched_node = this -> get_ir_node_in_stmt_with_id_type(cur_node->right_, id_type_, false, true); // ignore is_in_subquery. 
            if (matched_node.size() > 0) {
                // TODO:: inaccuracy here. 
                return matched_node[0];
            }
        }
    }

    return NULL;
}

vector<IR*> IRWrapper::get_common_table_expr_from_list(IR* cur_ir) {
    vector<IR*> v_res_rev, v_res;
    if (cur_ir ->type_ != kCommonTableExprList) {
        cerr << "IRWrapper Error: not getting kCommonTableExprList in IRWrapper::get_common_table_expr_from_list();\n\n\n";
        return v_res;
    }

    while (cur_ir->right_) {
        v_res_rev.push_back(cur_ir->right_);
        cur_ir = cur_ir->left_;
    }

    v_res_rev.push_back(cur_ir->left_);

    /* Reverse the order. */
    for (auto iter = v_res_rev.rbegin(); iter != v_res_rev.rend(); iter++) {
        v_res.push_back(*iter);
    }

    return v_res;
}

vector<IR*> IRWrapper::get_table_ir_in_with_clause(IR* cur_ir) {
    vector<IR*> v_res;
    if (cur_ir ->type_ != kWithClause) {
        cerr << "IRWrapper Error: not getting kWithClause in IRWrapper::get_table_ir_in_with_clause();\n\n\n";
        return v_res;
    }

    IR* common_table_expr_list_ = cur_ir->right_;

    vector<IR*> v_common_table_expr = this->get_common_table_expr_from_list(common_table_expr_list_);

    for (auto common_table_expr : v_common_table_expr) {
        IR* table_name_ir = common_table_expr->left_->left_;
        v_res.push_back(table_name_ir);
    }

    return v_res;

}

#include "../include/ir_wrapper.h"
#include <chrono>

IR* IRWrapper::reconstruct_ir_with_stmt_vec(const vector<IR*>& stmt_vec) {
    if (stmt_vec.size() == 0) {
        return NULL;
    }
    if (!stmt_vec[0]) {
        return NULL;
    }

    IR* cur_root = new IR(kStartEntry, OP0(), NULL, NULL);
    IR* first_simple_stmt = new IR(kSimpleStatement, OP0(), stmt_vec[0]->deep_copy());
    IR* first_stmtlist = new IR(kStmtList, OP3("", ";", ""), first_simple_stmt);
    cur_root->update_left(first_stmtlist);

    set_ir_root(cur_root);

    for (int i = 1; i < stmt_vec.size(); i++) {
        if (stmt_vec[i] == NULL) continue;
        IR* new_stmt = stmt_vec[i]->deep_copy();
        append_stmt_at_end(new_stmt);
    }

    return cur_root;
}

bool IRWrapper::is_exist_ir_node_in_stmt_with_type(IR* cur_stmt,
    IRTYPE ir_type, bool is_subquery, bool ignore_is_subquery) {

    vector<IR*> matching_IR_vec = this->get_ir_node_in_stmt_with_type(cur_stmt,
        ir_type, is_subquery, ignore_is_subquery);
    if (matching_IR_vec.size() == 0){
        return false;
    } else {
        return true;
    }
}

vector<IR*> IRWrapper::get_ir_node_in_stmt_with_type(IR* cur_stmt,
    IRTYPE ir_type, bool is_subquery, bool ignore_is_subquery, bool ignore_type_suffix) {

    // auto get_ir_node_in_stmt_start_time = std::chrono::system_clock::now();


    // Iterate IR binary tree, left depth prioritized.
    bool is_finished_search = false;
    std::vector<IR*> ir_vec_iter;
    std::vector<IR*> ir_vec_matching_type;
    IR* cur_IR = cur_stmt; 
    // Begin iterating. 
    while (!is_finished_search) {
        ir_vec_iter.push_back(cur_IR);
        if (!ignore_type_suffix && cur_IR->type_ == ir_type) {
            ir_vec_matching_type.push_back(cur_IR);
        } else if (ignore_type_suffix && compare_ir_type(cur_IR->type_, ir_type)) {
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

    // cerr << "We have ir_vec_matching_type.size()" << ir_vec_matching_type.size() << "\n\n\n";
    // if (ir_vec_matching_type.size() > 0 ) {
    //     cerr << "We have ir_vec_matching_type.type_, parent->type_, parent->parent->type_: " << ir_vec_matching_type[0] ->type_ << "  "
    //          << get_parent_type(ir_vec_matching_type[0], 3)  << "   " << get_parent_type(ir_vec_matching_type[0], 4) << "\n\n\n";
    //     cerr << "is_sub_query: " << this->is_in_subquery(cur_stmt, ir_vec_matching_type[0]) << "\n\n\n";
    //     cerr << "ir_vec_matching_type->to_string: " << ir_vec_matching_type[0]->to_string() << "\n\n\n";
    // }

    // Check whether IR node is in a SELECT subquery. 
    if (!ignore_is_subquery) {
        std::vector<IR*> ir_vec_matching_type_depth;
        for (IR* ir_match : ir_vec_matching_type){
            if(this->is_in_subquery(cur_stmt, ir_match) == is_subquery) {
                ir_vec_matching_type_depth.push_back(ir_match);
            }
            continue;
        }
        // cerr << "We have ir_vec_matching_type_depth.size()" << ir_vec_matching_type_depth.size() << "\n\n\n";
        
        // auto get_ir_node_in_stmt_end_time = std::chrono::system_clock::now();
        // std::chrono::duration<double> get_ir_node_in_stmt_used_time = get_ir_node_in_stmt_end_time  - get_ir_node_in_stmt_start_time;
        // cerr << " get_ir_node_in_stmt time: " << get_ir_node_in_stmt_used_time.count() << "\n\n\n";

        return ir_vec_matching_type_depth;
    } else {

        // auto get_ir_node_in_stmt_end_time = std::chrono::system_clock::now();
        // std::chrono::duration<double> get_ir_node_in_stmt_used_time = get_ir_node_in_stmt_end_time  - get_ir_node_in_stmt_start_time;
        // cerr << " get_ir_node_in_stmt time: " << get_ir_node_in_stmt_used_time.count() << "\n\n\n";

        return ir_vec_matching_type;
    }
}

bool IRWrapper::is_in_subquery(IR* cur_stmt, IR* check_node,
    bool output_debug) {
    
    if (this->is_ir_in(check_node, kSubquery)) {
        return true;
    } else {
        return false;
    }
}

IR* IRWrapper::get_ir_node_for_stmt_by_idx(int idx) {

    if (idx < 0) {
        FATAL("Checking on non-existing stmt. Function: IRWrapper::get_ir_node_for_stmt_with_idx(). Idx < 0. idx: '%d' \n", idx);
    }

    if (this->ir_root == nullptr){
        FATAL("Root IR not found in IRWrapper::get_ir_node_for_stmt_with_idx(); Forgot to initilize the IRWrapper? \n");
    }

    vector<IR*> stmt_list_v = this->get_stmtlist_IR_vec();

    if (idx >= stmt_list_v.size()){
        std::cerr << "Statement with idx " << idx << " not found in the IR. " << std::endl;
        return nullptr;
    }
    IR* cur_stmt_list = stmt_list_v[idx];
    // cerr << "Debug: 136: cur_stmt_list type: " << get_string_by_ir_type(cur_stmt_list->get_ir_type()) << "\n";
    IR* cur_stmt = get_stmt_ir_from_stmtlist(cur_stmt_list);
    return cur_stmt;
}

IR* IRWrapper::get_ir_node_for_stmt_by_idx(IR* ir_root, int idx) {
    this->set_ir_root(ir_root);
    return this->get_ir_node_for_stmt_by_idx(idx);
}

vector<IRTYPE> IRWrapper::get_all_stmt_ir_type(){

    vector<IR*> stmt_list_v = this->get_stmtlist_IR_vec();

    vector<IRTYPE> all_types;
    for (auto iter = stmt_list_v.begin(); iter != stmt_list_v.end(); iter++){
        all_types.push_back((**iter).type_);
    }
    return all_types;

}

int IRWrapper::get_stmt_num(){
    return this->get_stmtlist_IR_vec().size();
}

int IRWrapper::get_stmt_num(IR* cur_root) {
    if (cur_root->type_ != kStartEntry) {
        cerr << "Error: Receiving NON-kProgram root. Func: IRWrapper::get_stmt_num(IR* cur_root). Aboard!\n";
        FATAL("Error: Receiving NON-kProgram root. Func: IRWrapper::get_stmt_num(IR* cur_root). Aboard!\n");
    }
    this->set_ir_root(cur_root);
    return this->get_stmt_num();
}

IR* IRWrapper::get_first_stmtlist_from_root() {

    /* First of all, given the root, we need to get to kStmtList. */

    if (ir_root == NULL ) {
        cerr << "Error: In ir_wrapper::get_stmtmulti_IR_vec, receiving empty IR root. \n";
        return NULL;
    }
    if (ir_root->get_left()->get_ir_type() == kStmtList) {  // This is the rewritten and reconstruct IR tree.
        return ir_root->get_left();
    }

    /* This is not a reconstructed IR tree. Do not have any kStmtList. */
    return NULL;
    
}

IR* IRWrapper::get_first_stmtlist_from_root(IR* cur_root) {
    this->ir_root = cur_root;
    return get_first_stmtlist_from_root();
}

IR* IRWrapper::get_first_stmt_from_root() {

    // cerr << "In IRWrapper::get_first_stmt_from_root(), get IR type: \n\n\n" << ir_root->get_left()->get_ir_type() << "\n\n\n";
    if (ir_root->get_left()->get_ir_type() == kStmtList) {  // This is the rewritten and reconstruct IR tree.
        IR* first_stmtmulti = this->get_first_stmtlist_from_root();
        if (first_stmtmulti == NULL) {
            return NULL;
        }
        return this->get_stmt_ir_from_stmtlist(first_stmtmulti);
    }

    /* Now, we try to return the first stmt from the original parser IR tree returns. */
    IR* sql_statement = ir_root->get_left();
    if (sql_statement->get_ir_type() != kSqlStatement) {
        return NULL;
    }

    IR* simple_statement_or_begin = sql_statement->get_left();
    if (!simple_statement_or_begin || simple_statement_or_begin->get_ir_type() != kSimpleStatementOrBegin) {
        return NULL;
    }

    if (simple_statement_or_begin->get_left() && simple_statement_or_begin->get_left()->get_ir_type() == kSimpleStatement) {
        return simple_statement_or_begin->get_left()->get_left();
    } 
    else if (simple_statement_or_begin->get_left() && simple_statement_or_begin->get_left()->get_ir_type() == kBeginStmt) {
        return simple_statement_or_begin->get_left();
    }

    return NULL;
}

IR* IRWrapper::get_first_stmt_from_root(IR* cur_root) {
    this->ir_root = cur_root;
    // debug(cur_root, 0);
    return get_first_stmt_from_root();
}

IR* IRWrapper::get_last_stmtlist_from_root() {

    /* First of all, given the root, we need to get to kStmtmulti. */

    if (ir_root == NULL ) {
        cerr << "Error: In ir_wrapper::get_stmtmulti_IR_vec, receiving empty IR root. \n";
        return NULL;
    }
    // if (ir_root->get_left()->get_ir_type() != kStmtList) {
    //     cerr << "Error: In ir_wrapper:get_stmtmulti_IR_vec, cannot find the kStmtmulti " \
    //         "structure from the current IR tree. Empty stmt? Or PLAssignStmt? " \
    //         "PLAssignStmt is not currently supported. \n";
    //     return NULL;
    // }

    vector<IR*> v_stmtlist = this->get_stmtlist_IR_vec();
    return v_stmtlist.back();
}

IR* IRWrapper::get_last_stmt_from_root(IR* cur_root) {
    this->ir_root = cur_root;
    return get_last_stmt_from_root();
}

IR* IRWrapper::get_last_stmt_from_root() {
    if (ir_root == NULL) {
        return NULL;
    }

    IR* last_stmtlist = get_last_stmtlist_from_root();
    if (!last_stmtlist) {
        return NULL;
    }
    IR* last_stmt = get_stmt_ir_from_stmtlist(last_stmtlist);
    if (!last_stmt) {
        return NULL;
    } else {
        return last_stmt;
    }

    return NULL;
}

vector<IR*> IRWrapper::get_stmtlist_IR_vec(){

    IR* stmt_IR_p = get_first_stmtlist_from_root();

    vector<IR*> stmt_list_v;

    while (stmt_IR_p && stmt_IR_p -> get_ir_type() == kStmtList){ // Iterate from the first kstatementlist to the last.
        stmt_list_v.push_back(stmt_IR_p);
        if (stmt_IR_p->get_right() == nullptr) break; // This is the last kstatementlist.
        stmt_IR_p = stmt_IR_p -> get_right(); // Lead to the next kstatementlist.
    }

    return stmt_list_v;
}

bool IRWrapper::append_stmt_at_idx(string app_str, int idx){
    /* idx = -1, append to the beginning of the query
    ** idx = stmt_num - 1, append to the ending of the query. 
    */ 

    IR* ori_root = this->ir_root;
    int stmt_num = get_stmt_num();

    if (idx < -1 && idx >= stmt_num ){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::append_stmt_at_idx(). \n";
        return false;
    }

    // Parse and get the new statement. 
    vector<IR*> ir_vec;
    IR* app_ir_root = NULL;
    int ret = run_parser_multi_stmt(app_str, ir_vec);
    if (ret == 0 && ir_vec.size() > 0) {
        app_ir_root = ir_vec.back();
    } else {
        return false;
    }

    IR* app_stmtlist = get_first_stmtlist_from_root(app_ir_root);

    if (!app_stmtlist) {
        cerr << "Error: get_first_stmtmulti_from_root returns NULL. \n";
        return false;
    }

    IR* app_IR_node = get_stmt_ir_from_stmtlist(app_stmtlist);
    if (!app_IR_node) {
        cerr << "Error: get_stmt_ir_from_stmtmulti returns NULL. \n";
        return false;
    }
    app_IR_node = app_IR_node->deep_copy();
    app_ir_root->deep_drop();

    /* Restore the modified ir_root in the previous function calls.  */ 
    set_ir_root(ori_root);

    return this->append_stmt_at_idx(app_IR_node, idx);

}

bool IRWrapper::append_stmt_at_end(string app_str) {

    IR* ori_root = this->ir_root;

    // Parse and get the new statement.
    vector<IR*> ir_vec;
    IR* app_ir_root = NULL;
    int ret = run_parser_multi_stmt(app_str, ir_vec);
    if (ret == 0 && ir_vec.size() > 0) {
        app_ir_root = ir_vec.back();
    } else {
        return false;
    }

    IR* app_stmtlist = get_first_stmtlist_from_root(app_ir_root);

    if (!app_stmtlist) {
        cerr << "Error: get_first_stmtlist_from_root returns NULL. \n";
        return false;
    }

    IR* app_ir_node = get_stmt_ir_from_stmtlist(app_stmtlist);
    if (!app_ir_node) {
        cerr << "Error: get_stmt_ir_from_stmtmulti returns NULL. \n";
        return false;
    }
    app_ir_node = app_ir_node->deep_copy();
    app_ir_root->deep_drop();

    /* Restore the modified ir_root in the previous function calls.  */ 
    set_ir_root(ori_root);

    return this->append_stmt_at_idx(app_ir_node, get_stmt_num()-1);
    
}

bool IRWrapper::append_stmt_at_end(IR* app_IR_node) { // Please provide with IR* (Statement*) type, do not provide IR*(StatementList*) type. 

    int total_num = this->get_stmt_num();
    // if (total_num < 1)  {
    //     cerr << "Error: total_num of stmt < 1. Directly deep_drop(); \n\n\n";
    //     app_IR_node->deep_drop();
    //     return false;
    // }
    return this->append_stmt_at_idx(app_IR_node, total_num - 1);

}

bool IRWrapper::append_stmt_at_idx(IR* app_IR_node, int idx) { // Please provide with IR* (Specific_Statement*) type, do not provide IR*(StatementList*) type.

    vector<IR*> stmt_list_v = this->get_stmtlist_IR_vec();

    if (stmt_list_v.size() == 0) {
        cerr << "Error: Getting stmt_list_v.size() == 0; \n";
        app_IR_node->deep_drop();
        return false;
    }

    // cerr << "Debug: Given root: " << ir_root->to_string() << ". \nWe have stmtmulti: \n";

    // for (IR* stmt_list : stmt_list_v) {
    //     cerr << "DEBUG: Stmtmulti is: " << stmt_list->to_string() << "\n";
    // }
    // cerr << "End stmtlist. \n";

    if (idx < -1 || idx > stmt_list_v.size()){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::append_stmt_at_idx(). \n";
        std::cerr << "Error: Input index " << to_string(idx) << "; stmt_list_v size(): " << stmt_list_v.size() << ".\n";
        return false;
    }

    app_IR_node = new IR(kSimpleStatement, OP0(), app_IR_node);

    if (idx < (stmt_list_v.size() - 1) ) {

        auto new_res = new IR(kStmtList, OPMID(";"), NULL, NULL);

        int next_idx = idx + 1;
        IR* next_ir_list = stmt_list_v[next_idx];

        if (!ir_root->swap_node(next_ir_list, new_res)) {
            new_res->deep_drop();
            app_IR_node->update_right(NULL);
            app_IR_node->deep_drop();
            std::cerr << "Error: Swap node failure? In function: IRWrapper::append_stmt_at_idx. idx = "  << idx << "\n";
            return false;
        }

        new_res->update_left(app_IR_node);
        new_res->update_right(next_ir_list);

        return true;
    } else {
        /* If idx == stmt_list_v.size() -1. Append new stmt to the end to the query sequence */

        auto new_res = new IR(kStmtList, OPMID(";"), app_IR_node, NULL);

        int last_idx = idx;
        IR* last_ir_list = stmt_list_v[last_idx];

        last_ir_list->update_right(new_res);

        return true;
    }
}

bool IRWrapper::remove_stmt_at_idx_and_free(unsigned idx){

    vector<IR*> stmt_list_v = this->get_stmtlist_IR_vec();

    if (idx >= stmt_list_v.size() || idx < 0){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::remove_stmt_at_idx_and_free(). \n";
        return false;
    }

    if (stmt_list_v.size() <= 1) {
        // std::cerr << "Error: Cannot remove stmt becuase there is only one stmt left in the query. \n In function IRWrapper::remove_stmt_at_idx_and_free(). \n";
        return false;
    }

    IR* rov_stmt = stmt_list_v[idx];

    // cerr << "\n\n\nBefore Removing stmt, we get root: \n";
    // debug(ir_root, 0);
    // cerr << ir_root->to_string() << "\n\n\n";

    // cerr << "\n\n\nRemoving stmt: \n";
    // debug(rov_stmt, 0);
    // cerr << rov_stmt->to_string() << "\n\n\n";

    if ( idx < stmt_list_v.size() - 1 ){
        IR* parent_node = rov_stmt->get_parent();
        IR* next_stmt = rov_stmt->get_right();
        parent_node->swap_node(rov_stmt, next_stmt);
        rov_stmt->right_ = NULL;
        rov_stmt->deep_drop();

    } else { // Remove the last statement from the sequence. 
        IR* parent_node = rov_stmt->get_parent();
        parent_node->update_right(NULL);
        rov_stmt->deep_drop();
    }

    // cerr << "\n\n\nAfter Removing stmt, we get root: \n";
    // debug(ir_root, 0);
    // cerr << ir_root->to_string() << "\n\n\n";

    return true;
}

vector<IR*> IRWrapper::get_stmt_ir_vec() {

    vector<IR*> stmtlist_vec = this->get_stmtlist_IR_vec(), stmt_vec;
    if (stmtlist_vec.size() == 0) return stmt_vec;

    for (int i = 0; i < stmtlist_vec.size(); i++){
        if (!stmtlist_vec[i]) {
            cerr << "Error: Found some stmtlist_vec == NULL. Return empty vector. \n";
            continue;
        }
        // cerr << "Debug: 407: stmtlist_vec type: " << get_string_by_ir_type(stmtlist_vec[i]->get_ir_type()) << "\n";

        IR* stmt_ir = get_stmt_ir_from_stmtlist(stmtlist_vec[i]);
        if (stmt_ir != NULL) {
            stmt_vec.push_back(stmt_ir);
        }
    }
    
    // // DEBUG
    // for (auto stmt : stmt_vec) {
    //     cerr << "In func: IRWrapper::get_stmt_ir_vec(), we have stmt_vec type_: " << get_string_by_ir_type(stmt->type_) << "\n";
    // }

    // cerr << "In get_stmt_ir_vec: we have: \n";
    // for (IR* stmt: stmt_vec) {
    //     cerr << stmt->to_string() << "\n";
    // }
    // cerr << "get_stmt finished. \n";

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

bool IRWrapper::append_components_at_ir(IR* parent_node, IR* app_node,
    bool is_left, bool is_replace) {

    if (is_left) {
        if (parent_node->left_ != nullptr) {
            if (!is_replace) {
                cerr << "Append location has content, use is_replace=true if necessary. Function: IRWrapper::append_components_at_ir. \n";
                return false;
            }
            IR* old_node = parent_node->left_;
            parent_node->detatch_node(old_node);
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
            parent_node->detatch_node(old_node);
            old_node->deep_drop();
        }
        parent_node->update_right(app_node);
        return true;
    }
}

bool IRWrapper::remove_components_at_ir(IR* rov_ir) {
    if (rov_ir && rov_ir->get_parent()) {
        IR* parent_node = rov_ir->get_parent();
        parent_node->detatch_node(rov_ir);
        rov_ir->deep_drop();
        return true;
    }
    cerr << "Error: rov_ir or rov_ir->parent_ are nullptr. Function IRWrapper::remove_components_at_ir() \n";
    return false;
}

vector<IR*> IRWrapper::get_all_ir_node (IR* cur_ir_root) {
    // this->set_ir_root(cur_ir_root);
    vector<IR*> res;
    this->get_all_ir_node(cur_ir_root, res);
    return res;
}

void IRWrapper::get_all_ir_node(IR* cur_ir, vector<IR*>& res) {

    if (cur_ir == NULL) {
        return;
    }

    if (cur_ir->get_left()) {
        this->get_all_ir_node(cur_ir->get_left(), res);
    }

    if (cur_ir->get_ir_type() != kStartEntry) {
        res.push_back(cur_ir);
    }

    if (cur_ir->get_right()) {
        this->get_all_ir_node(cur_ir->get_right(), res);
    }

    if (cur_ir->get_ir_type() == kStartEntry) {
        res.push_back(cur_ir);
    }

    return;
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
    if (!this->append_stmt_at_idx(new_stmt, old_stmt_idx-1)){
        // cerr << "Error: child function append_stmt_after_idx returns error. In func: IRWrapper::replace_stmt_and_free. \n";
        return false;
    }
    return true;
}

bool IRWrapper::compare_ir_type(IRTYPE left, IRTYPE right, bool ignore_subtype) {

    if (ignore_subtype) {
        if (left != right) {
            return false;
        } else {
            return true;
        }
    }

    /* Compare two IRTYPE, and see whether they are in the same type of stmt. */
    string left_str = get_string_by_ir_type(left);
    string right_str = get_string_by_ir_type(right);

    /* Cut suffix. */
    size_t cut_pos = left_str.find("_");
    if (cut_pos != -1) {
        left_str = left_str.substr(0, cut_pos);
    }

    cut_pos = right_str.find("_");
    if (cut_pos != -1) {
        right_str = right_str.substr(0, cut_pos);
    }

    // cerr << "Debug: Comparing " << left_str << " " << right_str << "\n";

    if (left_str == right_str) {return true;}
    else {return false;}
}

string IRWrapper::get_parent_type_str(IR* cur_IR, int depth){
    IR* output_IR = this->get_p_parent_with_a_type(cur_IR, depth);
    if (output_IR == nullptr) {
        return "kUnknown";
    } else {
        IRTYPE res_ir_type = output_IR->get_ir_type();
        string res_type_str = get_string_by_ir_type(res_ir_type);
        size_t suffix_pos = res_type_str.find("_");
        res_type_str = res_type_str.substr(0, suffix_pos);
        return res_type_str;
    }
}

IR* IRWrapper::get_p_parent_with_a_type(IR* cur_IR, int depth) {
    IRTYPE prev_ir_type = cur_IR->get_ir_type();
    while (cur_IR ->get_parent() != nullptr) {
        IRTYPE parent_type = cur_IR->get_parent()->get_ir_type();
        if (
            // There shouldn't be any exact same ir type nested with each other. 
            // If there is, they are from different nested structure. 
            parent_type == prev_ir_type
            ||
            (parent_type != kUnknown && !compare_ir_type(parent_type, prev_ir_type))
        ){
            prev_ir_type = parent_type;
            depth--;
            if (depth <= 0) {
                return cur_IR->get_parent();
            }   
        }
        cur_IR = cur_IR->get_parent();
    }
    return nullptr;
}

bool IRWrapper::is_exist_group_clause(IR* cur_stmt){
    vector<IR*> v_group_clause = get_ir_node_in_stmt_with_type(cur_stmt, kOptGroupClause, false);
    for (IR* group_clause : v_group_clause) {
        if (! group_clause->is_empty()) {
            return true;
        }
    }

    /* Debug: not sure whether this counts for group clause or not */
    vector<IR*> v_index_hint_clause = get_ir_node_in_stmt_with_type(cur_stmt, kIndexHintClause, false);
    for (IR* index_hint_clause : v_index_hint_clause) {
        if (index_hint_clause->get_prefix() == "FOR GROUP BY") {
            return true;
        }
    }

    return false;
}

bool IRWrapper::is_exist_having_clause(IR* cur_stmt){
    vector<IR*> v_having_clause = get_ir_node_in_stmt_with_type(cur_stmt, kOptHavingClause, false);
    for (IR* having_clause : v_having_clause) {
        if (! having_clause->is_empty()) {
            return true;
        }
    }

    return false;
}

bool IRWrapper::is_exist_limit_clause(IR* cur_stmt){
    vector<IR*> v_limit_clause = get_ir_node_in_stmt_with_type(cur_stmt, kLimitClause, false);
    for (IR* limit_clause : v_limit_clause) {
        if (! limit_clause->is_empty()) {
            return true;
        }
    }

    v_limit_clause = get_ir_node_in_stmt_with_type(cur_stmt, kOptSimpleLimit, false);
    for (IR* limit_clause : v_limit_clause) {
        if (! limit_clause->is_empty()) {
            return true;
        }
    }
    
    return false;
}

bool IRWrapper::is_exist_UNION(IR* cur_stmt) {
    if (!cur_stmt) {
        // cerr << "Error: Given cur_stmt is NULL. \n";
        return false;
    }

    vector<IR*> v_simple_select = get_ir_node_in_stmt_with_type(cur_stmt, kCreateTableOption, false, false, false);
    for (IR* cur_simple_select : v_simple_select){
        if (cur_simple_select->get_prefix() == "UNION") {
            return true;
        }
    }

    v_simple_select = get_ir_node_in_stmt_with_type(cur_stmt, kQueryExpressionBody_1, false, false, false);
    for (IR* cur_simple_select : v_simple_select){
        if (cur_simple_select->get_middle() == "UNION") {
            return true;
        }
    }

    v_simple_select = get_ir_node_in_stmt_with_type(cur_stmt, kQueryExpressionBody_2, false, false, false);
    for (IR* cur_simple_select : v_simple_select){
        if (cur_simple_select->get_middle() == "UNION") {
            return true;
        }
    }

    v_simple_select = get_ir_node_in_stmt_with_type(cur_stmt, kQueryExpressionBody_3, false, false, false);
    for (IR* cur_simple_select : v_simple_select){
        if (cur_simple_select->get_middle() == "UNION") {
            return true;
        }
    }

    v_simple_select = get_ir_node_in_stmt_with_type(cur_stmt, kQueryExpressionBody_4, false, false, false);
    for (IR* cur_simple_select : v_simple_select){
        if (cur_simple_select->get_middle() == "UNION") {
            return true;
        }
    }

    return false;
}

bool IRWrapper::is_exist_set_operator(IR* cur_stmt) {
    // return is_exist_UNION_SELECT(cur_stmt) || is_exist_INTERSECT_SELECT(cur_stmt) || is_exist_EXCEPT_SELECT(cur_stmt);
    return is_exist_UNION(cur_stmt);
}

bool IRWrapper::is_exist_window_func_call (IR* cur_stmt) {
    vector<IR*> v_window_func_call = get_ir_node_in_stmt_with_type(cur_stmt, kWindowFuncCall, false);
    if (v_window_func_call.size() > 0) {
        return true;
    } else {
        return false;
    }
}

bool IRWrapper::is_exist_func_call_generic(IR* cur_stmt) {
    if (!cur_stmt) { return false; }

    vector<IR*> v_func_call_generic = get_ir_node_in_stmt_with_type(cur_stmt, kFunctionCallGeneric, false);
    if (v_func_call_generic.size() > 0) {
        return true;
    } else {
        return false;
    }
}

vector<IR*> IRWrapper::get_select_items_in_select_stmt(IR* cur_stmt){

    vector<IR*> res_vec;
    if (cur_stmt->get_ir_type() != kSelectStmt) {
        return res_vec;
    }

    res_vec = this->get_ir_node_in_stmt_with_type(cur_stmt, kSelectItem, false);
    return res_vec;
}

IRTYPE IRWrapper::get_cur_stmt_type_from_sub_ir(IR* cur_ir) {
    IR* stmt_ir = get_cur_stmt_ir_from_sub_ir(cur_ir);
    if (!stmt_ir) {
        return kUnknown;
    } else {
        return stmt_ir->get_ir_type();
    }
}

IR* IRWrapper::get_cur_stmt_ir_from_sub_ir(IR* cur_ir) {
    while (cur_ir->get_parent() != nullptr) {
        if (cur_ir->get_ir_type() == kBeginStmt) {
            return cur_ir;
        }
        if (cur_ir->get_ir_type() == kSimpleStatement) {
            return cur_ir->get_left();
        }
        if (cur_ir->get_ir_type() == kStmtList) {
            if (cur_ir->get_left()->get_ir_type() == kSimpleStatement) {
                return cur_ir->get_left()->get_left();
            }
        }
        cur_ir = cur_ir->parent_;
    }
    return NULL;
}



IR* IRWrapper::get_stmt_ir_from_stmtlist(IR* cur_stmtlist){
    if (cur_stmtlist == NULL) {
        cerr << "Getting NULL cur_stmtmulti. \n";
        return NULL;
    }
    if (cur_stmtlist->get_ir_type() != kStmtList) {
        cerr << "Error: In IRWrapper::get_stmt_ir_from_stmtmulti(), not getting type kStmtmulti. \n";
        return NULL;
    }

    // cerr << "Stmt is: " << cur_stmtmulti->to_string() << "\n";


    if (
        cur_stmtlist->get_left() &&
        cur_stmtlist->get_left()->get_ir_type() == kSimpleStatement &&
        cur_stmtlist->get_left() -> get_left()
    ) {
        return cur_stmtlist->get_left()->get_left(); // Return the actual stmt type, not kSimpleStatement. 
    } else if (
        cur_stmtlist->get_left()
    ) {
        return cur_stmtlist->get_left(); // Return the actual stmt type, not kSimpleStatement. 
    } else {
        // cerr << "Error: Cannot find specific stmt from kStmtmulti. \n";
        return NULL;
    }
}

bool IRWrapper::is_ir_in(IR* sub_ir, IR* par_ir) {

    while (sub_ir) {
        // cerr << "Debug: in is_ir_in function, getting ir type: " << get_string_by_ir_type(sub_ir->get_ir_type()) << "\n to_string(): " << sub_ir->to_string() << "\n\n\n";

        // cerr << "Further outputs. \n\n\n";

        if (sub_ir == par_ir) {
            return true;
        }
        sub_ir = sub_ir->get_parent();
    }
    return false;
}

bool IRWrapper::is_ir_in(IR* sub_ir, IRTYPE par_type) {

    while (sub_ir) {
        // cerr << "Debug: in is_ir_in function, getting ir type: " << get_string_by_ir_type(sub_ir->get_ir_type()) << "\n to_string(): " << sub_ir->to_string() << "\n\n\n";
        // cerr << "Further outputs. \n\n\n";

        if (sub_ir->get_ir_type() == par_type) {
            return true;
        }
        sub_ir = sub_ir->get_parent();
    }
    return false;
}

void IRWrapper::debug(IR* root, unsigned level) {

    for (unsigned i = 0; i < level; i++) {
        cerr << " ";
    }

    cerr << level << ": "
         << get_string_by_ir_type(root->type_) << ": "
         << get_string_by_data_type(root->data_type_) << ": "
         << root -> to_string() << ": "
         << endl;

    if (root->left_) {
        debug(root->left_, level + 1);
    }
    if (root->right_) {
        debug(root->right_, level + 1);
    }
}

bool IRWrapper::add_fields_to_insert_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kInsertStmt) {
        return false;
    }

    vector<IR*> v_fields = get_fields_in_stmt(cur_stmt);

    if (v_fields.size() == 0 ) {
        // cerr << "v_fields is 0;\n\n\n";
        return false;
    }

    IR* last_field = v_fields.back();
    IR* last_field_content = last_field->get_left();
    if (!last_field_content) {
        return false;
    }
    IR* last_field_content_copy = last_field_content->deep_copy();

    IR* new_field = new IR(kFields, OP0(), last_field_content_copy);

    last_field->detatch_node(last_field_content);
    last_field->update_right(last_field_content);
    last_field->op_->middle_ = ",";
    last_field->update_left(new_field);
    
    return true;

}

bool IRWrapper::drop_fields_to_insert_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kInsertStmt) {
        return false;
    }

    vector<IR*> v_fields = get_fields_in_stmt(cur_stmt);

    if (v_fields.size() <= 1 ) {
        return false;
    }

    IR* last_field = v_fields.back();
    IR* parent_node = last_field->get_parent();

    if (!parent_node) {
        return false;
    }

    parent_node->detatch_node(last_field);

    IR* parent_node_fields = parent_node->get_right();
    parent_node->detatch_node(parent_node_fields);
    parent_node->update_left(parent_node_fields);

    parent_node->op_->middle_ = "";
    last_field->deep_drop();

    return true;

}

bool IRWrapper::add_kvalues_to_insert_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kValuesList) {
        return false;
    }

    vector<IR*> v_values = get_kvalues_in_kvaluelist(cur_stmt);

    if (v_values.size() == 0 ) {
        // cerr << "v_values is 0;\n\n\n";
        return false;
    }

    IR* last_values = v_values.back();
    IR* last_values_content = last_values->get_left();
    if (!last_values_content) {
        return false;
    }
    IR* last_values_content_copy = last_values_content->deep_copy();

    // cerr << "last_values_content_copy is: " << last_values_content_copy->to_string() << "\n\n\n";

    IR* new_values = new IR(kValues, OP0(), last_values_content_copy);

    last_values->detatch_node(last_values_content);
    last_values->update_right(last_values_content);
    last_values->op_->middle_ = ",";
    last_values->update_left(new_values);
    
    return true;

}

bool IRWrapper::drop_kvalues_to_insert_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kValuesList) {
        return false;
    }

    vector<IR*> v_values = get_kvalues_in_kvaluelist(cur_stmt);

    if (v_values.size() <= 1 ) {
        return false;
    }

    IR* last_values = v_values.back();
    IR* parent_node = last_values->get_parent();

    if (!parent_node) {
        return false;
    }

    parent_node->detatch_node(last_values);

    IR* parent_node_values = parent_node->get_right();
    parent_node->detatch_node(parent_node_values);
    parent_node->update_left(parent_node_values);

    parent_node->op_->middle_ = "";
    last_values->deep_drop();

    return true;

}


vector<IR*> IRWrapper::get_fields_in_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kInsertStmt) {
        vector<IR*> tmp;
        return tmp;
    }

    return this->get_ir_node_in_stmt_with_type(cur_stmt, kFields, false);
}

int IRWrapper::get_num_fields_in_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kInsertStmt) {
        return false;
    }

    return this->get_ir_node_in_stmt_with_type(cur_stmt, kFields, false).size();

}

vector<IR*> IRWrapper::get_kvalues_in_kvaluelist(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kValuesList) {
        vector<IR*> tmp;
        return tmp;
    }

    vector<IR*> res;

    res = this->get_ir_node_in_stmt_with_type(cur_stmt, kValues, false);

    return res;
}

vector<vector<IR*>> IRWrapper::get_kvalues_in_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kInsertStmt) {
        vector<vector<IR*>> tmp;
        return tmp;
    }

    vector<vector<IR*>> res;

    vector<IR*> v_value_list = this->get_ir_node_in_stmt_with_type(cur_stmt, kValuesList, false);
    for (IR* value_list : v_value_list) {
        vector<IR*> v_values = this->get_ir_node_in_stmt_with_type(value_list, kValues, false);
        res.push_back(v_values);
    }

    return res;
}

vector<IR*>  IRWrapper::get_kvalueslist_in_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kInsertStmt) {
        vector<IR*> tmp;
        return tmp;
    }

    return this->get_ir_node_in_stmt_with_type(cur_stmt, kValuesList, false);
}

int IRWrapper::get_num_kvalues_in_stmt(IR* cur_stmt) {
    if (cur_stmt->get_ir_type() != kInsertStmt) {
        return 0;
    }

    vector<int> res;

    vector<IR*> v_value_list = this->get_ir_node_in_stmt_with_type(cur_stmt, kValuesList, false);
    if (v_value_list.size() == 0) {
        return 0;
    }
    IR* value_list = v_value_list.back();
    int num_values = this->get_ir_node_in_stmt_with_type(value_list, kValues, false).size();

    return num_values;

}
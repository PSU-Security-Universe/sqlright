#include "../include/ir_wrapper.h"
#include "../include/define.h"
#include "../AFL/debug.h"
#include "../include/utils.h"
#include <iostream>
#include <fstream>
#include <vector>
#include <algorithm>
#include <cstring>

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
        return ir_vec_matching_type_depth;
    } else {
        return ir_vec_matching_type;
    }

    

}

bool IRWrapper::is_in_subquery(IR* cur_stmt, IR* check_node,
    bool output_debug) {

    IR* cur_iter = check_node;
    while (1) {
        if (cur_iter == NULL) { // Iter to the parent node. This is Not a subquery. 
            return false;
        }
        else if (cur_iter == cur_stmt) { // Iter to the cur_stmt node already. Not in a  subquery.
            return false;
        }
        else if (cur_iter->type_ == kStmtmulti) { // Iter to the parent node. This is Not a subquery.
            return false;
        }
        else if (
                cur_iter->get_ir_type() == kSelectStmt &&
                cur_iter->get_parent() != NULL &&
                get_parent_type_str(cur_iter) != "kStmt"
                ) {
            // cerr << "Debug: for " << cur_iter->to_string() << ", kSelectStmt return true. returns " << get_parent_type_str(cur_iter) << "\n";
            return true; //In a subquery.
        }
        else if (
            cur_iter->get_ir_type() == kSelectWithParens &&
            get_parent_type_str(cur_iter) != "kSelectWithParens" &&
            get_parent_type_str(cur_iter) != "kSelectStmt" &&
            get_parent_type_str(cur_iter) != "kSelectClause"
        ){
            // cerr << "Debug: for " << cur_iter->to_string() << ", kSelectWithParens return true \n";
            return true; // In a subquery.
        }
        cur_iter = cur_iter->get_parent(); // Assuming cur_iter->get_parent() will always get to kStatementList. Otherwise, it would be error.
        continue;
    }
    /* Unexpected, should not happen. */
    return false;
}

IR* IRWrapper::get_ir_node_for_stmt_with_idx(int idx) {

    if (idx < 0) {
        FATAL("Checking on non-existing stmt. Function: IRWrapper::get_ir_node_for_stmt_with_idx(). Idx < 0. idx: '%d' \n", idx);
    }

    if (this->ir_root == nullptr){
        FATAL("Root IR not found in IRWrapper::get_ir_node_for_stmt_with_idx(); Forgot to initilize the IRWrapper? \n");
    }

    vector<IR*> stmt_list_v = this->get_stmtmulti_IR_vec();

    if (idx >= stmt_list_v.size()){
        std::cerr << "Statement with idx " << idx << " not found in the IR. " << std::endl;
        return nullptr;
    }
    IR* cur_stmt_list = stmt_list_v[idx];
    // cerr << "Debug: 136: cur_stmt_list type: " << get_string_by_ir_type(cur_stmt_list->get_ir_type()) << "\n";
    IR* cur_stmt = get_stmt_ir_from_stmtmulti(cur_stmt_list);
    return cur_stmt;
}

IR* IRWrapper::get_ir_node_for_stmt_with_idx(IR* ir_root, int idx) {
    this->set_ir_root(ir_root);
    return this->get_ir_node_for_stmt_with_idx(idx);
}

/* Not accurate within query. */
bool IRWrapper::is_ir_before(IR* f, IR* l){
    return this->is_ir_after(l, f);
}

/* Not accurate within query. */
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


vector<IRTYPE> IRWrapper::get_all_stmt_ir_type(){

    vector<IR*> stmt_list_v = this->get_stmtmulti_IR_vec();

    vector<IRTYPE> all_types;
    for (auto iter = stmt_list_v.begin(); iter != stmt_list_v.end(); iter++){
        all_types.push_back((**iter).type_);
    }
    return all_types;

}

int IRWrapper::get_stmt_num(){
    return this->get_stmtmulti_IR_vec().size();
}

int IRWrapper::get_stmt_num(IR* cur_root) {
    if (cur_root->type_ != kParseToplevel) {
        cerr << "Error: Receiving NON-kProgram root. Func: IRWrapper::get_stmt_num(IR* cur_root). Aboard!\n";
        FATAL("Error: Receiving NON-kProgram root. Func: IRWrapper::get_stmt_num(IR* cur_root). Aboard!\n");
    }
    this->set_ir_root(cur_root);
    return this->get_stmt_num();
}

IR* IRWrapper::get_first_stmtmulti_from_root() {

    /* First of all, given the root, we need to get to kStmtmulti. */

    if (ir_root == NULL ) {
        cerr << "Error: In ir_wrapper::get_stmtmulti_IR_vec, receiving empty IR root. \n";
        return NULL;
    }
    if (ir_root->get_left()->get_ir_type() != kStmtmulti) {
        cerr << "Error: In ir_wrapper:get_stmtmulti_IR_vec, cannot find the kStmtmulti " \
            "structure from the current IR tree. Empty stmt? Or PLAssignStmt? " \
            "PLAssignStmt is not currently supported. \n";
        return NULL;
    }

    vector<IR*> stmtmulti_v = get_stmtmulti_IR_vec();
    if (stmtmulti_v.size() != 0) {
        return stmtmulti_v.front();
    } else {
        return NULL;
    }
}

IR* IRWrapper::get_first_stmtmulti_from_root(IR* cur_root) {
    this->ir_root = cur_root;
    return get_first_stmtmulti_from_root();
}

IR* IRWrapper::get_first_stmt_from_root() {
    IR* first_stmtmulti = this->get_first_stmtmulti_from_root();
    if (first_stmtmulti == NULL) {
        return NULL;
    }

    return this->get_stmt_ir_from_stmtmulti(first_stmtmulti);
}

IR* IRWrapper::get_first_stmt_from_root(IR* cur_root) {
    this->ir_root = cur_root;
    return get_first_stmt_from_root();
}

IR* IRWrapper::get_last_stmtmulti_from_root() {

    /* First of all, given the root, we need to get to kStmtmulti. */

    if (ir_root == NULL ) {
        cerr << "Error: In ir_wrapper::get_stmtmulti_IR_vec, receiving empty IR root. \n";
        return NULL;
    }
    if (ir_root->get_left()->get_ir_type() != kStmtmulti) {
        cerr << "Error: In ir_wrapper:get_stmtmulti_IR_vec, cannot find the kStmtmulti " \
            "structure from the current IR tree. Empty stmt? Or PLAssignStmt? " \
            "PLAssignStmt is not currently supported. \n";
        return NULL;
    }

    return ir_root->get_left();
}

IR* IRWrapper::get_last_stmtmulti_from_root(IR* cur_root) {
    this->ir_root = cur_root;
    return get_last_stmtmulti_from_root();
}

IR* IRWrapper::get_last_stmt_from_root() {
    IR* last_stmtmulti = this->get_last_stmtmulti_from_root();
    if (last_stmtmulti == NULL) {
        // cerr << "Getting empty last_stmtmulti;\n";
        return NULL;
    }

    return this->get_stmt_ir_from_stmtmulti(last_stmtmulti);
}

IR* IRWrapper::get_last_stmt_from_root(IR* cur_root) {
    this->ir_root = cur_root;
    return get_last_stmt_from_root();
}


vector<IR*> IRWrapper::get_stmtmulti_IR_vec(){

    IR* stmt_IR_p = get_last_stmtmulti_from_root();

    vector<IR*> stmt_list_v;

    while (stmt_IR_p && stmt_IR_p -> get_ir_type() == kStmtmulti){ // Iterate from the first kstatementlist to the last.
        stmt_list_v.push_back(stmt_IR_p);
        if (stmt_IR_p->get_right() == nullptr) break; // This is the last kstatementlist.
        stmt_IR_p = stmt_IR_p -> get_left(); // Lead to the next kstatementlist.
    }

    vector<IR*> res_stmt_list_v;
    for (auto iter = stmt_list_v.rbegin(); iter != stmt_list_v.rend(); iter++) {
        res_stmt_list_v.push_back(*iter);
    }

    /* Ignore the last kStmtmulti, the last one is just a semicolon.  */
    res_stmt_list_v.pop_back();

    stmt_list_v.clear();

    // cerr << "In get_stmtmulti: we have: \n";
    // for (IR* stmtmulti: res_stmt_list_v) {
    //     cerr << stmtmulti->to_string() << "\n";
    // }
    // cerr << "get_stmtmulti finished. \n\n";

    return res_stmt_list_v;
}



bool IRWrapper::append_stmt_at_idx(string app_str, int idx, Mutator& g_mutator){

    vector<IR*> stmt_list_v = this->get_stmtmulti_IR_vec();

    if (idx != -1 && idx > stmt_list_v.size()){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::append_stmt_at_idx(). \n";
        return false;
    }

    // Parse and get the new statement. 
    IR* app_IR_root = g_mutator.parse_query_str_get_ir_set(app_str).back();
    IR* app_stmtmulti = get_first_stmtmulti_from_root();

    if (!app_stmtmulti) {
        cerr << "Error: get_first_stmtmulti_from_root returns NULL. \n";
        return false;
    }

    // cerr << "Debug: 276: app_stmtmulti type: " << get_string_by_ir_type(app_stmtmulti->get_ir_type()) << "\n";

    IR* app_IR_node = get_stmt_ir_from_stmtmulti(app_stmtmulti);
    if (!app_IR_node) {
        cerr << "Error: get_stmt_ir_from_stmtmulti returns NULL. \n";
        return false;
    }
    app_IR_node = app_IR_node->deep_copy();
    app_IR_root->deep_drop();

    return this->append_stmt_at_idx(app_IR_node, idx);

}

bool IRWrapper::append_stmt_at_end(string app_str, Mutator& g_mutator) {


    vector<IR*> stmt_list_v = this->get_stmtmulti_IR_vec();

    // Parse and get the new statement.
    IR* app_IR_root = g_mutator.parse_query_str_get_ir_set(app_str).back();

    IR* app_stmtmulti = get_first_stmtmulti_from_root();

    if (!app_stmtmulti) {
        cerr << "Error: get_first_stmtmulti_from_root returns NULL. \n";
        return false;
    }


    // cerr << "Debug: 306: app_stmtmulti type: " << get_string_by_ir_type(app_stmtmulti->get_ir_type()) << "\n";

    IR* app_IR_node = get_stmt_ir_from_stmtmulti(app_stmtmulti);
    if (!app_IR_node) {
        cerr << "Error: get_stmt_ir_from_stmtmulti returns NULL. \n";
        return false;
    }
    app_IR_node = app_IR_node->deep_copy();
    app_IR_root->deep_drop();

    return this->append_stmt_at_idx(app_IR_node, stmt_list_v.size());
    
}


bool IRWrapper::append_stmt_at_end(IR* app_IR_node) { // Please provide with IR* (Statement*) type, do not provide IR*(StatementList*) type. 

    int total_num = this->get_stmt_num();
    if (total_num < 1)  {
        cerr << "Error: total_num of stmt < 1. Directly deep_drop(); \n\n\n";
        app_IR_node->deep_drop();
        return false;
    }
    return this->append_stmt_at_idx(app_IR_node, total_num);

}

bool IRWrapper::append_stmt_at_idx(IR* app_IR_node, int idx) { // Please provide with IR* (Specific_Statement*) type, do not provide IR*(StatementList*) type.
    vector<IR*> stmt_list_v = this->get_stmtmulti_IR_vec();

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

    if (idx < 0 || idx > stmt_list_v.size()){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::append_stmt_at_idx(). \n";
        std::cerr << "Error: Input index " << to_string(idx) << "; stmt_list_v size(): " << stmt_list_v.size() << ".\n";
        app_IR_node->deep_drop();
        return false;
    }

    app_IR_node = new IR(kStmt, OP0(), app_IR_node);

    if (idx <= stmt_list_v.size()) {
        IR* insert_pos_ir = stmt_list_v[idx];

        auto new_res = new IR(kStmtmulti, OPMID(";"), NULL, app_IR_node);

        if (!ir_root->swap_node(insert_pos_ir, new_res)){ // swap_node only rewrite the parent of insert_pos_ir, it will not affect     insert_pos_ir. 
            new_res->deep_drop();
            // FATAL("Error: Swap node failure? In function: IRWrapper::append_stmt_at_idx. \n");
            std::cerr << "Error: Swap node failure? In function: IRWrapper::append_stmt_at_idx. idx = " << idx << "\n";
            return false;
        }

        new_res->update_left(insert_pos_ir);

        return true;
    } else { // idx == 0
        IR* insert_pos_ir = stmt_list_v[0];
        if (insert_pos_ir -> right_ != NULL ){
            std::cerr << "Error: The first stmt_list is having right_ sub-node. In function IRWrapper::append_stmt_at_idx. \n";
            app_IR_node->deep_drop();
            return false;
        }

        auto new_res = new IR(kStmtmulti, OPMID(";"), app_IR_node, NULL);
        insert_pos_ir->update_right(insert_pos_ir->get_left());
        insert_pos_ir->update_left(new_res);

        return true;
    
    }
}

bool IRWrapper::remove_stmt_at_idx_and_free(unsigned idx){

    vector<IR*> stmt_list_v = this->get_stmtmulti_IR_vec();

    if (idx >= stmt_list_v.size() || idx < 0){
        std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::remove_stmt_at_idx_and_free(). \n";
        return false;
    }

    if (stmt_list_v.size() <= 1) {
        // std::cerr << "Error: Cannot remove stmt becuase there is only one stmt left in the query. \n In function IRWrapper::remove_stmt_at_idx_and_free(). \n";
        return false;
    }

    IR* rov_stmt = stmt_list_v[idx];

    // cerr << "Removing stmt: " << rov_stmt->to_string() << "\n";

    if ( idx != 0 && idx < stmt_list_v.size() ){
        IR* parent_node = rov_stmt->get_parent();
        IR* next_stmt = rov_stmt->left_;
        parent_node->swap_node(rov_stmt, next_stmt);
        rov_stmt->left_ = NULL;
        rov_stmt->deep_drop();

    } else { // idx == 0. Remove the first stmt.
        IR* parent_node = rov_stmt->get_parent();
        parent_node->update_left(parent_node->get_right());
        parent_node->right_ = NULL;
        rov_stmt->deep_drop();
    }

    return true;
}

vector<IR*> IRWrapper::get_stmt_ir_vec() {

    vector<IR*> stmtlist_vec = this->get_stmtmulti_IR_vec(), stmt_vec;
    if (stmtlist_vec.size() == 0) return stmt_vec;

    for (int i = 0; i < stmtlist_vec.size(); i++){
        if (!stmtlist_vec[i]) {
            cerr << "Error: Found some stmtlist_vec == NULL. Return empty vector. \n";
            continue;
        }
        // cerr << "Debug: 407: stmtlist_vec type: " << get_string_by_ir_type(stmtlist_vec[i]->get_ir_type()) << "\n";

        IR* stmt_ir = get_stmt_ir_from_stmtmulti(stmtlist_vec[i]);
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
    this->set_ir_root(cur_ir_root);
    return this->get_all_ir_node();
}

vector<IR*> IRWrapper::get_all_ir_node() {
    if (this->ir_root == nullptr) {
        std::cerr << "Error: IRWrapper::ir_root is nullptr. Forget to initilized? \n";
    }
    // Iterate IR binary tree, depth prioritized.
    bool is_finished_search = false;
    std::vector<IR*> ir_vec_iter;
    std::vector<IR*> all_ir_node_vec;
    IR* cur_IR = this->ir_root;
    // Begin iterating. 
    while (!is_finished_search) {
        ir_vec_iter.push_back(cur_IR);
        if (cur_IR->type_ != kParseToplevel)
            {all_ir_node_vec.push_back(cur_IR);} // Ignore kParserTopLevel at the moment, put it at the end of the vector.

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
    if (!this->append_stmt_at_idx(new_stmt, old_stmt_idx-1)){
        // cerr << "Error: child function append_stmt_after_idx returns error. In func: IRWrapper::replace_stmt_and_free. \n";
        return false;
    }
    return true;
}

bool IRWrapper::compare_ir_type(IRTYPE left, IRTYPE right) {
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
    vector<IR*> v_group_clause = get_ir_node_in_stmt_with_type(cur_stmt, kGroupClause, false);
    for (IR* group_clause : v_group_clause) {
        if (! group_clause->is_empty()) {
            return true;
        }
    }
    return false;
}

bool IRWrapper::is_exist_having_clause(IR* cur_stmt){
    vector<IR*> v_having_clause = get_ir_node_in_stmt_with_type(cur_stmt, kHavingClause, false);
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
    return false;
}

bool IRWrapper::is_exist_UNION_SELECT(IR* cur_stmt) {
    if (!cur_stmt) {
        cerr << "Error: Given cur_stmt is NULL. \n";
        return false;
    }
    // Do not ignore suffix.
    vector<IR*> v_simple_select = get_ir_node_in_stmt_with_type(cur_stmt, kSimpleSelect_13, false, false, false);
    for (IR* cur_simple_select : v_simple_select){
        if (cur_simple_select->get_middle() == "UNION") {
            return true;
        }
    }
    return false;
}


bool IRWrapper::is_exist_INTERSECT_SELECT(IR* cur_stmt) {
    if (!cur_stmt) {
        cerr << "Error: Given cur_stmt is NULL. \n";
        return false;
    }
    // Do not ignore suffix.
    vector<IR*> v_simple_select = get_ir_node_in_stmt_with_type(cur_stmt, kSimpleSelect_14, false, false, false);
    for (IR* cur_simple_select : v_simple_select){
        if (cur_simple_select->get_middle() == "INTERSECT") {
            return true;
        }
    }
    return false;
}

bool IRWrapper::is_exist_EXCEPT_SELECT(IR* cur_stmt) {
    if (!cur_stmt) {
        cerr << "Error: Given cur_stmt is NULL. \n";
        return false;
    }
    // Do not ignore suffix.
    vector<IR*> v_simple_select = get_ir_node_in_stmt_with_type(cur_stmt, kSimpleSelect_15, false, false, false);
    for (IR* cur_simple_select : v_simple_select){
        if (cur_simple_select->get_middle() == "EXCEPT") {
            return true;
        }
    }
    return false;
}

bool IRWrapper::is_exist_set_operator(IR* cur_stmt) {
    return is_exist_UNION_SELECT(cur_stmt) || is_exist_INTERSECT_SELECT(cur_stmt) || is_exist_EXCEPT_SELECT(cur_stmt);
}

/* Remove get_selectclauselist_vec functions and its related functions.
 * They are too complicated to use.
 * */
// vector<IR*> IRWrapper::get_selectclauselist_vec(IR* cur_stmt){
//     if (cur_stmt->type_ != kSelectStmt) {
//         // cerr << "Error: Not receiving kSelectStatement in the func: IRWrapper::get_selectcore_vec(). \n";
//         vector<IR*> tmp; return tmp;
//     }
//     // cerr << "In Func: IRWrapper::get_selectclauselist_vec(IR*), we have cur_stmt to_string: " << cur_stmt->to_string() << "\n\n\n";

//     vector<IR*> res_selectcore_vec;
//     vector<IR*> select_clause_list_vec = this->get_ir_node_in_stmt_with_type(cur_stmt, kSimpleSelect, false);
//     vector<IR*> res_select_clause_list_vec;

//     /* Should be able to return the list directly. */
//     // return select_clause_list_vec;

//     IR *p_r;
//     for (IR* select_clause_ir : select_clause_list_vec) {
//         if (select_clause_ir->right_){
//             p_r = select_clause_ir->right_;
//         } else {
//             continue;
//         }
//         if (select_clause_ir->left_ &&
//             select_clause_ir->left_->type_ == kUnknown &&
//             select_clause_ir->left_->op_ &&
//             select_clause_ir->left_->left_ &&
//             (
//                 strcmp(select_clause_ir->left_->op_->middle_, "UNION") == 0 ||
//                 strcmp(select_clause_ir->left_->op_->middle_, "INTERSECT") == 0 ||
//                 strcmp(select_clause_ir->left_->op_->middle_, "EXCEPT") == 0
//             )
//         ) {
//             res_select_clause_list_vec.push_back(select_clause_ir->left_->left_);
//             res_select_clause_list_vec.push_back(p_r);
//         }
//     }

//     return res_select_clause_list_vec;
// }

// bool IRWrapper::append_selectclause_clause_at_idx(IR* cur_stmt, IR* app_ir, string set_oper_str, int idx){
//     if (app_ir->type_ != kSelectClause) {
//         cerr << "Error: Not receiving kSelectCore in the func: IRWrapper::append_selectcore_clause(). \n";
//         return false;
//     }
//     if (cur_stmt->type_ != kSelectStmt) {
//         cerr << "Error: Not receiving kSelectStatement in the func: IRWrapper::append_selectcore_clause(). \n";
//         return false;
//     }

//     vector<IR*> selectclause_vec = this->get_selectclauselist_vec(cur_stmt);
//     if (selectclause_vec.size() > idx) {
//         cerr << "Idx exceeding the maximum number of selectcore in the statement. \n";
//         return false;
//     }

//     if (idx < selectclause_vec.size()) {
//         IR* insert_pos_ir = selectclause_vec[idx];

//         IR* combineClauseIR = new IR(kCombineClause, OP3(set_oper_str.c_str(), "", ""));
//         IR* new_res = new IR(kUnknown, OP3("", "", ""), app_ir, combineClauseIR);
//         new_res = new IR(kSelectClauseList, OP3("", "", ""), new_res, NULL);

//         if (!ir_root->swap_node(insert_pos_ir, new_res)){ // swap_node only rewrite the parent of insert_pos_ir, it will not affect     insert_pos_ir.
//             new_res->deep_drop();
//             // FATAL("Error: Swap node failure? In function: IRWrapper::append_stmt_at_idx. \n");
//             std::cerr << "Error: Swap node failure? In function: IRWrapper::append_stmt_at_idx. idx = " << idx << "\n";
//             return false;
//         }

//         new_res->update_right(insert_pos_ir);

//         return true;
//     } else { // idx == selectclause_vec.size()
//         IR* new_res = new IR(kSelectClauseList, OP3("", "", ""), app_ir);

//         IR* insert_pos_ir = selectclause_vec[idx-1];
//         if (insert_pos_ir->right_ != NULL) {
//             std::cerr << "Error: The last selectclause_vec is having right_ sub-node. In function IRWrapper::append_stmt_at_idx. \n";
//             return false;
//         }

//         insert_pos_ir->update_right(new_res);

//         return true;
//     }
// }

// bool IRWrapper::remove_selectclause_clause_at_idx_and_free(IR* cur_stmt, int idx) {
//     vector<IR*> selectclause_vec = this->get_selectclauselist_vec(cur_stmt);

//     if (idx >= selectclause_vec.size() && idx < 0){
//         std::cerr << "Error: Input index exceed total statement number. \n In function IRWrapper::remove_stmt_at_idx_and_free(). \n";
//         return false;
//     }

//     if (selectclause_vec.size() == 1) {
//         // std::cerr << "Error: Cannot remove stmt becuase there is only one stmt left in the query. \n In function IRWrapper::remove_stmt_at_idx_and_free(). \n";
//         return false;
//     }

//     IR* rov_clause = selectclause_vec[idx];

//     if (idx < selectclause_vec.size()-1){
//         IR* parent_node = rov_clause->get_parent();
//         IR* next_clause = rov_clause->right_;
//         parent_node->swap_node(rov_clause, next_clause);
//         rov_clause->right_ = NULL;
//         rov_clause->deep_drop();

//     } else { // idx == stmt_list_v.size()-1. Remove the last stmt.
//         IR* parent_node = rov_clause->get_parent();
//         parent_node->detach_node(rov_clause);
//         rov_clause->deep_drop();
//     }

//     return true;
// }

vector<IR*> IRWrapper::get_target_el_in_select_target(IR* cur_stmt){
    vector<IR*> res_vec;

    vector<IR*> select_target_list = this->get_ir_node_in_stmt_with_type(cur_stmt, kTargetList, false);

    if (select_target_list.size() > 0) {
        IR* cur_list = select_target_list[0];
        if (cur_list->get_right()) {
            res_vec.push_back(cur_list->get_right());
        } else {
            res_vec.push_back(cur_list->get_left());
        }
    }

    return res_vec;
}


IRTYPE IRWrapper::get_cur_stmt_type_from_sub_ir(IR* cur_ir) {
    while (cur_ir->parent_ != nullptr) {
        if (cur_ir->type_ == kStmt) {
            return cur_ir->left_->type_;
        }
        if (cur_ir->type_ == kStmtmulti) {
            if (cur_ir->right_ == nullptr) {
                if (cur_ir->left_->type_ == kStmt) {return cur_ir->left_->left_->type_;}
                else {return cur_ir->left_->type_;}
            }
            else {
                if (cur_ir->right_->type_ == kStmt) {return cur_ir->right_->left_->type_;}
                else {return cur_ir->right_->type_;}
            }
        }
        cur_ir = cur_ir->parent_;
    }
    return kUnknown;
}


IR* IRWrapper::get_stmt_ir_from_stmtmulti(IR* cur_stmtmulti){
    if (cur_stmtmulti == NULL) {
        cerr << "Getting NULL cur_stmtmulti. \n";
        return NULL;
    }
    if (cur_stmtmulti->get_ir_type() != kStmtmulti) {
        cerr << "Error: In IRWrapper::get_stmt_ir_from_stmtmulti(), not getting type kStmtmulti. \n";
        return NULL;
    }

    // cerr << "Stmt is: " << cur_stmtmulti->to_string() << "\n";


    if (cur_stmtmulti->get_right()
    ) {

        if (cur_stmtmulti->get_right()->get_left()) {
            return cur_stmtmulti->get_right()->get_left();
        } else {
            /* Yu: If a stmt has right node, but the right node is an empty stmt, ignored.  */
            return NULL;
        }

    } else if (cur_stmtmulti->get_left() && cur_stmtmulti->get_left()->get_ir_type() == kStmt && cur_stmtmulti->get_left()->get_left()
    ) {

        return cur_stmtmulti->get_left()->get_left();

    } else if (cur_stmtmulti->get_left() &&
               cur_stmtmulti->get_left()->get_ir_type() == kTransactionStmtLegacy
    ) {

        return cur_stmtmulti->get_left();

    } else {
        // cerr << "Error: Cannot find specific stmt from kStmtmulti. \n";
        return NULL;
    }
}

bool IRWrapper::is_ir_in(IR* sub_ir, IR* par_ir) {

    while (sub_ir) {
        if (sub_ir == par_ir) {
            return true;
        }
        sub_ir = sub_ir->get_parent();
    }
    return false;
}

bool IRWrapper::is_ir_in(IR* sub_ir, IRTYPE par_type) {

    while (sub_ir) {
        // cerr << "DEBUG: is_ir_in: looking at: " << get_string_by_ir_type(sub_ir->get_ir_type()) << "\n";
        if (sub_ir->get_ir_type() == par_type) {
            return true;
        }
        sub_ir = sub_ir->get_parent();
    }
    return false;
}

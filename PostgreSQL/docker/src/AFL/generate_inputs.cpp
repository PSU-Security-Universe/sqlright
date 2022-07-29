#include "../include/ast.h"
#include "../include/define.h"
#include "../include/mutate.h"
#include "../include/utils.h"
#include "../include/ir_wrapper.h"

#include "../oracle/postgres_oracle.h"
#include "../oracle/postgres_norec.h"
#include "../oracle/postgres_tlp.h"


#include <fstream>
#include <iostream>
#include <ostream>
#include <string>

using namespace std;

Mutator g_mutator;
SQL_ORACLE* p_oracle;

IRWrapper ir_wrapper;

int total_gen_inputs_num = 10000;

vector<string*> v_create_stmt;
vector<string*> v_insert_stmt;
vector<string*> v_set_stmt;
vector<string*> v_other_stmt;


void init_stmts(string f_testcase) {
    ifstream input_test(f_testcase);
    string line;

    while (getline(input_test, line)) {

        vector<IR *> v_ir = g_mutator.parse_query_str_get_ir_set(line);
        if (v_ir.size() <= 0) {
        // cerr << "failed to parse: " << line << endl;
        continue;
        }

        IR* v_ir_root = v_ir.back();
        string strip_sql = g_mutator.extract_struct(v_ir_root);
        v_ir.back()->deep_drop();
        v_ir.clear();

        v_ir = g_mutator.parse_query_str_get_ir_set(strip_sql);
        if (v_ir.size() <= 0) {
            // cerr << "failed to parse after extract_struct:" << endl
            //     << line << endl
            //     << strip_sql << "\n\n\n";
            continue;
        }

        IR* cur_root = v_ir.back();
        IR* cur_stmt = ir_wrapper.get_first_stmt_from_root(cur_root);
        if (cur_stmt == NULL) {
            cur_root->deep_drop();
            continue;
        }

        string* saved_str = new string(strip_sql);

        switch (cur_stmt->get_ir_type()) {
            case kCreateStmt: {
                // cout << "For str: " << strip_sql << ", kCreateStmt. \n";
                v_create_stmt.push_back(saved_str);
                v_other_stmt.push_back(saved_str);
            }
                break;
            case kInsertStmt: {
                // cout << "For str: " << strip_sql << ", kInsertStmt. \n";
                v_insert_stmt.push_back(saved_str);
                v_other_stmt.push_back(saved_str);
            }
                break;
            case kVariableSetStmt: {
                // cout << "For str: " << strip_sql << ", kSetStmt. \n";
                v_set_stmt.push_back(saved_str);
                v_other_stmt.push_back(saved_str);
            }
                break;
            case kSelectStmt: {
            }
                break;
            default: {
                // cout << "For str: " << strip_sql << ", kOtherStmt. \n";
                v_other_stmt.push_back(saved_str);
            }
        }
        cur_root->deep_drop();
    }
}

void gen_inputs(string out_name) {

    fstream out_fd(out_name, std::fstream::out | std::fstream::trunc);

    bool is_transaction = false;
    if (get_rand_int(10) < 1) {
        is_transaction = true;
    }

    if (is_transaction){
        out_fd << "BEGIN TRANSACTION; \n";
    }

    /* Get 2 set stmts */
    for (int idx = 0; idx < 2; idx++) {
        out_fd << *(vector_rand_ele(v_set_stmt)) << "\n";
    }

    /* Get 5 create table stmts */
    for (int idx = 0; idx < 5; idx++) {
        out_fd << *(vector_rand_ele(v_create_stmt)) << "\n";
    }

    /* Get 5 insert stmts */
    for (int idx = 0; idx < 5; idx++) {
        out_fd << *(vector_rand_ele(v_insert_stmt)) << "\n";
    }

    /* Get 12 other statements */
    for (int idx = 0; idx < 15; idx++) {
        out_fd << *(vector_rand_ele(v_other_stmt)) << "\n";
    }

    if (is_transaction){
        out_fd << "END TRANSACTION; \n";
    }


    out_fd.close();

    return;

}

int main() {

    p_oracle = new SQL_NOREC();
    g_mutator.set_p_oracle(p_oracle);
    p_oracle->set_mutator(&g_mutator);


    vector<string> init_file_list = get_all_files_in_dir("./postgres_initlib");


    for (auto &f : init_file_list) {
        string file_path = "./postgres_initlib/" + f;
        cerr << "init filename: " << file_path << endl;
        init_stmts(file_path);
    }

    for (int idx = 0; idx < total_gen_inputs_num; idx++) {
        string out_str = "./test_inputs/" + to_string(idx) + ".sql";
        cout << "Writing to out_str: " << out_str << "\n";
        gen_inputs(out_str);
    }

    cout << "\n\n\n####################\nDone! \n\n\n";

    return 0;

}

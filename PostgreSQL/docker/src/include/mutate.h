#ifndef __MUTATOR_H__
#define __MUTATOR_H__

#include "ast.h"
#include "define.h"
#include "utils.h"
#include "../AFL/types.h"

#include <map>
#include <set>
#include <vector>

#define LUCKY_NUMBER 500

using namespace std;

class SQL_ORACLE;

enum RELATIONTYPE {
  kRelationElement,
  kRelationSubtype,
  kRelationAlias,
};

enum STMT_TYPE {
  NOT_ORACLE = 0,
  ORACLE_SELECT = 1,
  ORACLE_NORMAL = 2
};

enum DEF_ARG_TYPE {
  boolean = 0,
  integer = 1,
  floating_point = 2,
  str = 3,
  on_off_auto = 4
};

class Mutator {

public:
  Mutator() { srand(time(nullptr)); }

  IR *deep_copy_with_record(const IR *root, const IR *record);
  unsigned long hash(IR *);
  unsigned long hash(string &);

  IR *ir_random_generator(vector<IR *> v_ir_collector);

  vector<IR *> mutate_all(IR* ori_ir_root, IR* ir_to_mutate, u64& total_mutate_failed, u64& total_mutate_num);

  vector<IR *> mutate_stmtlist(IR *input);
  vector<IR *> mutate(IR *input);                              
  IR *strategy_delete(IR *cur);                                
  IR *strategy_insert(IR *cur);                                
  IR *strategy_replace(IR *cur);                               
  bool lucky_enough_to_be_mutated(unsigned int mutated_times); 

  bool replace(IR *root, IR *old_ir, IR *new_ir); 
  IR *locate_parent(IR *root, IR *old_ir);        

  void init(string f_testcase = "", string f_common_string = "",
            string file2d = "", string file1d = "",
            string f_gen_type = "");
  void init_library();

  void init_ir_library(string filename);         
  inline void init_value_library();                     
  void init_common_string(string filename);      
  void init_data_library(string filename);       
  void init_data_library_2d(string filename);    
  void init_not_mutatable_type(string filename); 
  // void init_safe_generate_type(string filename);
  void add_ir_to_library(IR *); 

  string get_a_string();           
  unsigned long get_a_val();       
  IR *get_ir_from_library(IRTYPE); 
  // IR *generate_ir_by_type(IRTYPE); 

  string get_data_by_type(DATATYPE);
  pair<string, string> get_data_2d_by_type(DATATYPE, DATATYPE); 

  void reset_data_library(); 
  void reset_data_library_single_stmt();

  string parse_data(string &);
  string extract_struct(IR *root);
  void _extract_struct(IR *);  
  void extract_struct2(IR *); 

  vector<IR*> pre_fix_transform(IR*, vector<STMT_TYPE>&);
  vector<vector<vector<IR*>>> post_fix_transform(vector<IR*>& all_pre_trans_vec, vector<STMT_TYPE>& stmt_type_vec);
  vector<vector<IR*>> post_fix_transform(vector<IR*>& all_pre_trans_vec, vector<STMT_TYPE>& stmt_type_vec, int run_count);

  bool fix_one_stmt(IR *cur_stmt, bool is_debug_info = false);

  vector<IR *> split_to_substmt(IR *root, map<IR *, pair<bool, IR*>> &m_save,
                             set<IRTYPE> &split_set); 
  bool connect_back(map<IR *, pair<bool, IR*>> &m_save);

  void analyze_scope(IR *stmt_root);
  void fix_preprocessing(IR *stmt_root,
                     vector<IR*> &ordered_all_subquery_ir);
  bool fix_dependency(IR* cur_stmt_root, const vector<vector<IR*>> ir_to_fix, bool is_debug_info = false);   
  void reset_scope_library(bool clear_define);                      
  IR *find_closest_node(IR *stmt_root, IR *node, DATATYPE type);    
  bool fill_one(IR *parent);                                        
  // bool fill_one_pair(IR *parent, IR *child);                        
  // bool fill_stmt_graph_one(map<IR *, vector<IR *>> &graph, IR *ir); 
  void pre_validate();
  bool validate(IR *&root, bool is_debug_info = false);                                       
  string validate(string query, bool is_debug_info = false);

  pair<string, string> ir_to_string(IR* root, vector<vector<IR*>> all_post_trans_vec, const vector<STMT_TYPE>& stmt_type_vec);

  unsigned int calc_node(IR *root);
  bool replace_one_value_from_datalibray_2d(DATATYPE p_datatype,
                                            DATATYPE c_data_type, string &p_key,
                                            string &old_c_value,
                                            string &new_c_value);
  bool remove_one_pair_from_datalibrary_2d(DATATYPE p_datatype,
                                           DATATYPE c_data_type, string &p_key);
  bool replace_one_from_datalibrary(DATATYPE datatype, string &old_str,
                                    string &new_str);
  bool remove_one_from_datalibrary(DATATYPE datatype, string &key);
  ~Mutator();
  void debug(IR *root);
  void debug(IR *root, unsigned level);
  int try_fix(char *buf, int len, char *&new_buf, int &new_len);

  void add_ir_to_library_no_deepcopy(IR *); 

  // added by vancir
  bool get_valid_str_from_lib(string &);
  vector<IR *> parse_query_str_get_ir_set(string &query_str);
  bool check_node_num(IR *root, unsigned int limit);
  vector<IR *> extract_statement(IR *root);
  void set_p_oracle(SQL_ORACLE *oracle) { this->p_oracle = oracle; }
  void set_dump_library(bool);
  int get_ir_libary_2D_hash_kStatement_size();
  bool is_stripped_str_in_lib(string stripped_str);

  void add_all_to_library(IR *, const vector<int> &);
  void add_all_to_library(IR *ir) {
    vector<int> dummy_vec;
    add_all_to_library(ir, dummy_vec);
  }
  void add_all_to_library(string, const vector<int> &);
  void add_all_to_library(string whole_query_str) {
    vector<int> dummy_vec;
    add_all_to_library(whole_query_str, dummy_vec);
  }
  void add_to_valid_lib(IR *, string &, const bool);
  void add_to_library(IR *, string &);
  void add_to_library_core(IR *, string *);
  int get_valid_collection_size();
  int get_cri_valid_collection_size();
  IR *get_from_libary_with_type(IRTYPE);
  IR *get_from_libary_with_left_type(IRTYPE);
  IR *get_from_libary_with_right_type(IRTYPE);

  IR* get_ir_with_type(const IRTYPE type_);
  bool add_missing_create_table_stmt(IR*);

  IR *record_ = NULL;
  IR *mutated_root_ = NULL;
  map<IRTYPE, vector<IR *>> ir_library_;
  map<IRTYPE, set<unsigned long>> ir_library_hash_;

  vector<string> string_library_;
  set<unsigned long> string_library_hash_;
  vector<unsigned long> value_library_;

  map<DATATYPE, map<DATATYPE, RELATIONTYPE>> relationmap_;

  vector<string> common_string_library_;
  set<IRTYPE> not_mutatable_types_;
  set<IRTYPE> string_types_;
  set<IRTYPE> int_types_;
  set<IRTYPE> float_types_;

  set<IRTYPE> safe_generate_type_;
  set<IRTYPE> split_stmt_types_;
  set<IRTYPE> split_substmt_types_;

  map<DATATYPE, vector<string>> data_library_;
  map<DATATYPE, map<string, map<DATATYPE, vector<string>>>> data_library_2d_;

  map<DATATYPE, vector<string>> g_data_library_;
  map<DATATYPE, set<unsigned long>> g_data_library_hash_;
  map<DATATYPE, map<string, map<DATATYPE, vector<string>>>> g_data_library_2d_;
  map<DATATYPE, map<string, map<DATATYPE, vector<string>>>>
      g_data_library_2d_hash_;

  /*
  ** Not sure its usage yet. Might delete later. 
  ** Save all scope -> DATATYPE -> pIR in one query sequence. 
  */
  map<int, map<DATATYPE, vector<IR *>>> scope_library_;

  set<unsigned long> global_hash_;

  /* New data library. Without using dependency graph */
  static map<string, vector<string>> m_tables;   // Table name to column name mapping. 
  static map<string, vector<string>> m_table2index;   // Table name to index mapping. 
  static vector<string> v_table_names;  // All saved table names
  static vector<string> v_table_names_single; // All used table names in one query statement. 
  static vector<string> v_create_table_names_single; // All table names just created in the current stmt. 
  static vector<string> v_alias_names_single; // All alias name local to one query statement.  
  static map<string, vector<string>> m_table2alias_single;   // Table name to alias mapping.
  static map<string, COLTYPE> m_column2datatype;   // Column name mapping to column type. 0 means unknown, 1 means numerical, 2 means character_type_, 3 means boolean_type_.
  static vector<string> v_column_names_single; // All used column names in one query statement. Used to confirm literal type.
  static vector<string> v_table_name_follow_single; // All used table names follow type in one query stmt.
  static vector<string> v_statistics_name; // All statistic names defined in the current SQL.
  static vector<string> v_sequence_name; // All sequence names defined in the current SQL.
  static vector<string> v_view_name; // All saved view names.
  static vector<string> v_constraint_name; // All constraint names defined in the current SQL.
  static vector<string> v_create_foreign_table_names_single; // All foreign table names created in the current SQL.
  static vector<string> v_foreign_table_name; // All foreign table names defined inthe current SQL.
  static vector<string> v_table_with_partition_name; // All table names that contiains TABLE PARTITIONING.

  static vector<int> v_int_literals;
  static vector<double> v_float_literals;
  static vector<string> v_string_literals;

  static map<IRTYPE, vector<pair<string, DEF_ARG_TYPE>>> m_reloption;
  static vector<string> v_sys_column_name;
  static vector<string> v_sys_catalogs_name;

  static vector<string> v_saved_reloption_str;

  static vector<string> v_aggregate_func;

  // added by vancir
  map<unsigned long, bool> norec_hash;
  vector<string *> all_valid_pstr_vec;
  vector<string *> all_cri_valid_pstr_vec;
  set<string *> all_query_pstr_set;
  bool dump_library = false;
  SQL_ORACLE *p_oracle;
  map<IRTYPE, set<unsigned long>> ir_libary_2D_hash_;
  set<unsigned long> stripped_string_hash_;

  /* The interface of saving the required context for the mutator. Giving the
    IRTYPE, we should be able to extract all the related IR nodes from this
    library. The string* points to the string of the complete query stmt where
    the current NODE is from. And the int is the unique ID for the specific
    node, can be used to identify and extract the specific node from the IR
    tree when the tree is being reconstructed.
  */
  map<IRTYPE, vector<pair<string *, int>>> real_ir_set;
  map<IRTYPE, vector<pair<string *, int>>> left_lib_set;
  map<IRTYPE, vector<pair<string *, int>>> right_lib_set;

  static set<IR *> visited;

};

#endif

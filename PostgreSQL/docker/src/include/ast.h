#ifndef __AST_H__
#define __AST_H__

#include "define.h"
#include "relopt_generator.h"
#include <map>
#include <set>
#include <string>
#include <vector>

using namespace std;

// enum NODETYPE {
// #define DECLARE_TYPE(v) v,
//   ALLTYPE(DECLARE_TYPE)
// #undef DECLARE_TYPE
// };

enum IRTYPE {
  kconst_str,
  kconst_int,
  kconst_float,
#define DECLARE_TYPE(v) v,
  ALLTYPE(DECLARE_TYPE)
#undef DECLARE_TYPE
};

enum COLTYPE {
UNKNOWN_T,
INT_T,
FLOAT_T,
BOOLEAN_T,
STRING_T
};

enum DATATYPE {
#define DECLARE_TYPE(v) k##v,
  ALLDATATYPE(DECLARE_TYPE)
#undef DECLARE_TYPE
};

enum DATAFLAG {
  kUse = 0x8,
  kMapToClosestOne = 0x10,
  kNoSplit = 0x100,
  kGlobal = 0x4,
  kReplace = 0x40,
  kUndefine = 0x2,
  kAlias = 0x80,
  kMapToAll = 0x20,
  kDefine = 0x1,
  kNoModi = 0x200,
  kFlagUnknown = 0x0
};

#define GEN_NAME() name_ = gen_id_name();

static unsigned long g_id_counter;

static inline void reset_id_counter() { g_id_counter = 0; }

static inline void clear_id() { g_id_counter = 0; }

static string gen_id_name() { return "v" + to_string(g_id_counter++); }
static string gen_column_name() {return "c" + to_string(g_id_counter++); }
static string gen_index_name() {return "i" + to_string(g_id_counter++); }
static string gen_alias_name() { return "a" + to_string(g_id_counter++); }
static string gen_statistic_name() {return "s" + to_string(g_id_counter++);}
static string gen_sequence_name() {return "seq" + to_string(g_id_counter++);}
static string gen_view_name() {return "view" + to_string(g_id_counter++);}


string get_string_by_ir_type(IRTYPE type);
string get_string_by_data_type(DATATYPE type);
string get_string_by_option_type(RelOptionType);
string get_string_by_data_flag(DATAFLAG flag_type_);

class IROperator {
public:
  IROperator(const char *prefix = "",
             const char *middle = "",
             const char *suffix = "")
      : prefix_(prefix), middle_(middle), suffix_(suffix) {}

  const char *prefix_;
  const char *middle_;
  const char *suffix_;
};

enum UnionType {
  kUnionUnknown = 0,
  kUnionString = 1,
  kUnionFloat,
  kUnionInt,
  kUnionLong,
  kUnionBool,
};

#define isUse(a) ((a)&kUse)
#define isMapToClosestOne(a) ((a)&kMapToClosestOne)
#define isNoSplit(a) ((a)&kNoSplit)
#define isGlobal(a) ((a)&kGlobal)
#define isReplace(a) ((a)&kReplace)
#define isUndefine(a) ((a)&kUndefine)
#define isAlias(a) ((a)&kAlias)
#define isMapToAll(a) ((a)&kMapToAll)
#define isDefine(a) ((a)&kDefine)

class IR {
public:
  IR(IRTYPE type, IROperator *op, IR *left = NULL, IR *right = NULL)
      : type_(type), op_(op), left_(left), right_(right), parent_(NULL),
        operand_num_((!!right) + (!!left)), data_type_(kDataWhatever) {
    GEN_NAME();
    if (left_)
      left_->parent_ = this;
    if (right_)
      right_->parent_ = this;
  }

  IR(IRTYPE type, string str_val, DATATYPE data_type = kDataWhatever,
     int scope = -1, DATAFLAG flag = kUse)
      : type_(type), str_val_(str_val), op_(NULL), left_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), data_type_(data_type), scope_(scope),
        data_flag_(flag) {
    GEN_NAME();
  }

  IR(IRTYPE type, bool b_val, DATATYPE data_type = kDataWhatever,
     int scope = -1, DATAFLAG flag = kUse)
      : type_(type), bool_val_(b_val), left_(NULL), op_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), data_type_(data_type),
        scope_(scope), data_flag_(flag) {
    GEN_NAME();
  }

  IR(IRTYPE type, unsigned long long_val, DATATYPE data_type = kDataWhatever,
     int scope = -1, DATAFLAG flag = kUse)
      : type_(type), long_val_(long_val), left_(NULL), op_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), data_type_(data_type),
        scope_(scope), data_flag_(flag) {
    GEN_NAME();
  }

  IR(IRTYPE type, int int_val, DATATYPE data_type = kDataWhatever,
     int scope = -1, DATAFLAG flag = kUse)
      : type_(type), int_val_(int_val), left_(NULL), op_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), data_type_(data_type),
        scope_(scope), data_flag_(flag) {
    GEN_NAME();
  }

  IR(IRTYPE type, double f_val, DATATYPE data_type = kDataWhatever,
     int scope = -1, DATAFLAG flag = kUse)
      : type_(type), float_val_(f_val), left_(NULL), op_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), data_type_(data_type),
        scope_(scope), data_flag_(flag) {
    GEN_NAME();
  }

  IR(IRTYPE type, IROperator *op, IR *left, IR *right, double f_val,
     string str_val, string name, unsigned int mutated_times, int scope = -1,
     DATAFLAG flag = kUse)
      : type_(type), op_(op), left_(left), right_(right),
        operand_num_((!!right) + (!!left)), name_(name), str_val_(str_val),
        float_val_(f_val), mutated_times_(mutated_times),
        data_type_(kDataWhatever), scope_(scope), data_flag_(flag) {
    if (left_)
      left_->parent_ = this;
    if (right_)
      right_->parent_ = this;
  }

  IR(const IR *ir, IR *left, IR *right) {
    this->type_ = ir->type_;
    if (ir->op_ != NULL)
      this->op_ = OP3(ir->op_->prefix_, ir->op_->middle_, ir->op_->suffix_);
    else {
      this->op_ = OP0();
    }

    this->left_ = left;
    this->right_ = right;
    if (this->left_)
      this->left_->parent_ = this;
    if (this->right_)
      this->right_->parent_ = this;

    this->str_val_ = ir->str_val_;
    this->long_val_ = ir->long_val_;
    this->data_type_ = ir->data_type_;
    this->scope_ = ir->scope_;
    this->data_flag_ = ir->data_flag_;
    this->option_type_ = ir->option_type_;
    this->name_ = ir->name_;
    this->operand_num_ = ir->operand_num_;
    this->mutated_times_ = ir->mutated_times_;
  }

  union {
    int int_val_;
    unsigned long long_val_;
    double float_val_;
    bool bool_val_;
  };

  int scope_;
  int uniq_id_in_tree_ = -1;
  DATAFLAG data_flag_ = DATAFLAG::kFlagUnknown;
  DATATYPE data_type_ = DATATYPE::kDataWhatever;
  RelOptionType option_type_ = RelOptionType::Unknown;
  IRTYPE type_;
  string name_;

  string str_val_;

  IROperator *op_;
  IR *left_;
  IR *right_;
  IR *parent_;
  bool is_node_struct_fixed = false; // Do not mutate this IR if this set to be true.
  int operand_num_;
  unsigned int mutated_times_ = 0;

  string to_string();
  void to_string_core(string&);

  // delete this IR and necessary clean up
  void drop();
  // delete the IR tree
  void deep_drop();
  // copy the IR tree
  IR *deep_copy();
  // find the parent node of child inside this IR tree
  IR *locate_parent(IR *child);
  // find the root node of this node
  IR *get_root();
  // find the parent node of this node
  IR *get_parent();
  // unlink the node from this IR tree, but keep the node
  bool detach_node(IR *node);
  // swap the node, keep both
  bool swap_node(IR *old_node, IR *new_node);

  void update_left(IR *);
  void update_right(IR *);

  void print_ir();

  const char* get_prefix();
  const char* get_middle();
  const char* get_suffix();
  string get_str_val();

  IR* get_left();
  IR* get_right();

  IRTYPE get_ir_type();
  DATATYPE get_data_type();
  DATAFLAG get_data_flag();
  RelOptionType get_rel_option_type();


  bool is_empty();

  void set_str_val(string);

  void set_ir_type(IRTYPE);
  void set_data_type(DATATYPE);
  void set_data_flag(DATAFLAG);

  /* helper functions for the IR type */

  // Return is_succeed.
  bool set_type(DATATYPE, DATAFLAG); // Set type regardless of its node type.
  bool set_iden_type(DATATYPE, DATAFLAG);
  bool set_qualified_name_type(DATATYPE, DATAFLAG);
  bool set_qualified_name_list_type(DATATYPE, DATAFLAG);
  bool set_reloption_elem_type(DATATYPE, DATAFLAG);
  bool set_any_name_type(DATATYPE, DATAFLAG);
  bool set_any_name_list_type(DATATYPE, DATAFLAG);

  bool set_generic_set_type(DATATYPE, DATAFLAG);

  bool set_opt_columnlist_type(DATATYPE, DATAFLAG);
  bool set_columnlist_type(DATATYPE, DATAFLAG);
  bool set_insert_columnlist_type(DATATYPE, DATAFLAG);
  bool set_rolelist_type(DATATYPE, DATAFLAG);
  bool set_opt_name_list_type(DATATYPE, DATAFLAG);
  bool set_name_list_type(DATATYPE, DATAFLAG);
  bool set_cluster_index_specification_type(DATATYPE, DATAFLAG);
  bool set_relation_expr_type(DATATYPE, DATAFLAG);



  bool set_opt_reloptions_option_type(RelOptionType);
  bool set_reloptions_option_type(RelOptionType);
  bool set_reloption_list_option_type(RelOptionType);
  bool set_reloption_elem_option_type(RelOptionType);
  bool set_rel_option_type(RelOptionType);

  bool add_drop_is_add();
  int get_object_type_any_name();
  int get_object_type();
  int get_reindex_target_type();

  bool target_el_is_exist_alias();
  bool target_el_set_alias(string);
  bool func_name_set_str(string);

  bool replace_op(IROperator*);

  /* From the kTypename ir, return the int representing the Postgres column type.
  */
  COLTYPE typename_ir_get_type();

};

DATATYPE get_datatype_by_string(string s);

IRTYPE get_nodetype_by_string(string s);

IR *deep_copy(const IR *root);

void deep_delete(IR *root);

#endif

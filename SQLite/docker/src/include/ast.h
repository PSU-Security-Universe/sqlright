#ifndef __AST_H__
#define __AST_H__

#include "define.h"
#include <iostream>
#include <map>
#include <set>
#include <string>
#include <vector>

using namespace std;

#define DECLARE_CLASS(v) class v;

ALLCLASS(DECLARE_CLASS);
#undef DECLARE_CLASS

//#include "../parser/bison_parser.h"
//#include "../parser/flex_lexer.h"

#define reset_counter() g_id_counter = 0;

static unsigned long g_id_counter;

static inline void clear_id() { g_id_counter = 0; }

static string gen_id_name() { return "v" + to_string(g_id_counter++); }
static string gen_table_name() { return "t" + to_string(g_id_counter++); }
static string gen_column_name() { return "c" + to_string(g_id_counter++); }
static string gen_index_name() { return "i" + to_string(g_id_counter++); }
static string gen_alias_name() { return "a" + to_string(g_id_counter++); }

enum CASEIDX {
  CASE0,
  CASE1,
  CASE2,
  CASE3,
  CASE4,
  CASE5,
  CASE6,
  CASE7,
  CASE8,
  CASE9,
  CASE10,
  CASE11,
  CASE12,
  CASE13,
  CASE14,
  CASE15,
  CASE16,
  CASE17,
  CASE18,
  CASE19,
};

enum NODETYPE {
  kconst_str,
  kconst_int,
  kconst_float,
#define DECLARE_TYPE(v) v,
  ALLTYPE(DECLARE_TYPE)
#undef DECLARE_TYPE
};

enum IDTYPE {
  id_whatever,

  id_create_table_name,
  id_create_view_name,
  id_create_table_name_with_tmp, // In with clause, the table_name created are temporary. Only effective for one single stmt. Thus the id_type_.
  id_create_column_name_with_tmp, // In with clause, the column_name created are temporary. Only effective for one single stmt. Thus the id_type_.
  id_top_table_name,
  id_table_name,

  id_create_column_name,
  id_column_name,
  id_top_column_name,

  id_pragma_name,
  id_pragma_value,

  id_create_index_name,
  id_index_name,

  id_create_trigger_name,
  id_trigger_name,

  id_create_window_name,
  id_window_name,
  id_base_window_name,

  id_create_savepoint_name,
  id_savepoint_name,

  id_schema_name,
  id_module_name,
  id_collation_name,
  id_database_name,
  id_alias_name,
  id_table_alias_name,
  id_column_alias_name,
  id_function_name,
  id_table_constraint_name,
};

typedef NODETYPE IRTYPE;

class IROperator {
public:
  IROperator(const char *prefix = NULL,
             const char *middle = NULL,
             const char *suffix = NULL)
      : prefix_(prefix), middle_(middle), suffix_(suffix) {}

  const char *prefix_;
  const char *middle_;
  const char *suffix_;
};

class IR {
public:
  IR(IRTYPE type, IROperator *op, IR *left = NULL, IR *right = NULL)
      : type_(type), op_(op), left_(left), right_(right), parent_(NULL),
        operand_num_((!!right) + (!!left)), id_type_(id_whatever) {
    if (left_)
      left_->parent_ = this;
    if (right_)
      right_->parent_ = this;
  }

  IR(IRTYPE type, string str_val, IDTYPE id_type = id_whatever)
      : type_(type), str_val_(str_val), op_(NULL), left_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), id_type_(id_type) {
  }

  IR(IRTYPE type, bool b_val)
      : type_(type), b_val_(b_val), left_(NULL), op_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), id_type_(id_whatever) {
  }

  IR(IRTYPE type, unsigned long int_val)
      : type_(type), int_val_(int_val), left_(NULL), op_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), id_type_(id_whatever) {
  }

  IR(IRTYPE type, double f_val)
      : type_(type), f_val_(f_val), left_(NULL), op_(NULL), right_(NULL),
        parent_(NULL), operand_num_(0), id_type_(id_whatever) {
  }

  IR(IRTYPE type, IROperator *op, IR *left, IR *right, double f_val,
     string str_val, unsigned int mutated_times)
      : type_(type), op_(op), left_(left), right_(right), parent_(NULL),
        operand_num_((!!right) + (!!left)), str_val_(str_val),
        f_val_(f_val), mutated_times_(mutated_times), id_type_(id_whatever) {
    if (left_)
      left_->parent_ = this;
    if (right_)
      right_->parent_ = this;
  }

  union {
    unsigned long int_val_;
    double f_val_;
    bool b_val_;
  };

  int uniq_id_in_tree_;
  IDTYPE id_type_;
  IRTYPE type_;
  string str_val_;
  IROperator *op_;
  IR *left_;
  IR *right_;
  IR *parent_;
  bool is_node_struct_fixed = false; // Do not mutate this IR if this set to be true.
  int operand_num_;
  unsigned int mutated_times_ = 0;
  string to_string();
  void _to_string(string &);

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

};

class IRCollector {
public:
  vector<IR *> parse(Program *entry);
};

class Node {
public:
  void set_sub_type(unsigned int i) { sub_type_ = i; }
  NODETYPE type_;
  unsigned int sub_type_;
  virtual IR *translate(vector<IR *> &v_ir_collector);
};

class Opt : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  bool is_existed_;
};

class OptString : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  string str_;
};

class Program : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptSemicolon *opt_semicolon_prefix_;
  StatementList *statement_list_;
  OptSemicolon *opt_semicolon_suffix_;
};

class StatementList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<Statement *> v_statement_list_;
  vector<OptSemicolon *> v_opt_semicolon_list_;
};

class Statement : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  PreparableStatement *preparable_statement_;
};

class PragmaKey : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  PragmaName *pragma_name_;
  SchemaName *schema_name_;
};

class PragmaValue : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  SignedNumber *signed_number_;
  StringLiteral *string_literal_;
  Identifier *identifier_;
};

class PragmaName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_;
};

class SchemaName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_;
};

class PreparableStatement : public Statement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
};

class AnalyzeStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableName *table_name_;
};

class SelectStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptWithClause *opt_with_clause_;
  SelectCoreList *select_core_list_;
  OptOrder *opt_order_;
  OptLimit *opt_limit_;
};

class CreateStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
};

class CreateVirtualTableStatement : public CreateStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptIfNotExists *opt_if_not_exists_;
  TableName *table_name_;
  ModuleName *module_name_;
  OptColumnListParen *opt_column_list_paren_;
  OptWithoutRowID *opt_without_rowid_;
};

class CreateTriggerStatement : public CreateStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptTmp *opt_tmp_;
  OptIfNotExists *opt_if_not_exists_;
  TriggerName *trigger_name_;
  OptTriggerTime *opt_trigger_time_;
  TriggerEvent *trigger_event_;
  TableName *table_name_;
  OptForEach *opt_for_each_;
  OptWhen *opt_when_;
  TriggerCmdList *trigger_cmd_list_;
};

class CreateIndexStatement : public CreateStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptUnique *opt_unique_;
  OptIfNotExists *opt_if_not_exists_;
  IndexName *index_name_;
  TableName *table_name_;
  IndexedColumnList *indexed_column_list_;
  OptWhere *opt_where_;
};

class CreateViewStatement : public CreateStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptTmp *opt_tmp_;
  OptIfNotExists *opt_if_not_exists_;
  TableName *view_name_;
  OptColumnListParen *opt_column_list_paren_;
  SelectStatement *select_statement_;
};

class CreateTableStatement : public CreateStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptTmp *opt_tmp_;
  OptIfNotExists *opt_if_not_exists_;
  TableName *table_name_;
  SelectStatement *select_statement_;
  ColumnDefList *column_def_list_;
  OptWithoutRowID *opt_without_rowid_;
  TableConstraintList *table_constraint_list_;
  OptStrict *opt_strict_;
};

class InsertStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptWithClause *opt_with_clause_;
  InsertType *insert_type_;
  TableName *table_name_;
  OptTableAliasAs *opt_table_alias_as_;
  OptColumnListParen *opt_column_list_paren_;
  InsertValue *insert_value_;
  OptReturningClause *opt_returning_clause_;
};

class DeleteStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptWithClause *opt_with_clause_;
  QualifiedTableName *qualified_table_name_;
  OptWhere *opt_where_;
  OptReturningClause *opt_returning_clause_;
};

class UpdateStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptWithClause *opt_with_clause_;
  UpdateType *update_type_;
  QualifiedTableName *qualified_table_name_;
  UpdateClauseList *update_clause_list_;
  OptFromClause *opt_from_clause_;
  OptWhere *opt_where_;
  OptReturningClause *opt_returning_clause_;
};

class ReindexStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableName *table_name_;
};

class PragmaStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  PragmaKey *pragma_key_;
  PragmaValue *pragma_value_;
  TableName *table_name_;
};

class DetachStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  SchemaName *schema_name_;
};

class AttachStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
  SchemaName *schema_name_;
};

class DropStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
};

class DropViewStatement : public DropStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptIfExists *opt_if_exists_;
  TableName *view_name_;
};

class DropTableStatement : public DropStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptIfExists *opt_if_exists_;
  TableName *table_name_;
};

class DropIndexStatement : public DropStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptIfExists *opt_if_exists_;
  IndexName *index_name_;
};

class DropTriggerStatement : public DropStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptIfExists *opt_if_exists_;
  TriggerName *trigger_name_;
};

class FilePath : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  string str_val_;
};

class OptRecursive : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptIfNotExists : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class ColumnDefList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<ColumnDef *> v_column_def_list_;
};

class ColumnDef : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_;
  ColumnType *column_type_;
  OptColumnConstraintlist *opt_column_constraintlist_;
};

class ColumnType : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  string str_val_;
};

class OptColumnNullable : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptIfExists : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptColumnListParen : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ColumnNameList *column_name_list_;
};

class UpdateClauseList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<UpdateClause *> v_update_clause_list_;
};

class UpdateClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ColumnName *column_name_;
  ColumnNameList *column_name_list_;
  NewExpr *expr_;
};

class SetOperator : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class SelectCoreList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<SelectCore *> v_select_core_list_;
  vector<SetOperator *> v_set_operator_list_;
};

class SelectCore : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptDistinct *opt_distinct_;
  ResultColumnList *result_column_list_;
  OptFromClause *opt_from_clause_;
  OptWhere *opt_where_;
  OptGroup *opt_group_;
  OptWindowClause *opt_window_clause_;
  ExprListParenList *expr_list_paren_list_;
};

class OptDistinct : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptStoredVirtual : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class SelectList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ExprList *expr_list_;
};

class FromClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  // TableRef * table_ref_;
  JoinClause *join_clause_;
  TableOrSubqueryList *table_or_subquery_list_;
};

class OptFromClause : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  FromClause *from_clause_;
  OptColumnAlias *opt_column_alias_;
};

class OptWhere : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  WhereExpr *where_expr_;
};

class OptElseExpr : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ElseExpr *else_expr_;
};

class OptEscapeExpr : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  EscapeExpr *escape_expr_;
};

class OptGroup : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ExprList *expr_list_;
  OptHaving *opt_having_;
};

class OptHaving : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
};

class OptOrder : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OrderList *order_list_;
};

class OrderList : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<OrderTerm *> v_order_term_;
};

class OrderTerm : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
  OptCollate *opt_collate_;
  OptOrderType *opt_order_type_;
  OptOrderOfNull *opt_order_of_null_;
};

class OptOrderType : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptLimit : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr1_;
  NewExpr *expr2_;
};

class ExprList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<NewExpr *> v_expr_list_;
};

class ExprListParen : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ExprList *expr_list_;
};

class ExprListParenList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<ExprListParen *> v_expr_list_paren_list_;
};

class NewExpr : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Literal *literal_;
  ColumnName *column_name_;
  UnaryOp *unary_op_;
  NewExpr *new_expr1_;
  NewExpr *new_expr2_;
  NewExpr *new_expr3_;
  BinaryOp *binary_op_;
  FunctionName *function_name_;
  FunctionArgs *function_args_;
  OptFilterClause *opt_filter_clause_;
  OptOverClause *opt_over_clause_;
  ExprList *expr_list_;
  ColumnType *column_type_;
  Collate *collate_;
  OptNot *opt_not_;
  OptEscapeExpr *opt_escape_expr_;
  NullOfExpr *null_of_expr_;
  InTarget *in_target_;
  SelectStatement *select_statement_;
  ExistsOrNot *exists_or_not_;
  OptExpr *opt_expr_;
  CaseConditionList *case_condition_list_;
  OptElseExpr *opt_else_expr_;
  RaiseFunction *raise_function_;
};

class OptExpr : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
};

class UnaryOp : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class InTarget : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  SelectStatement *select_statement_;
  ExprList *expr_list_;
  TableName *table_name_;
};

class BinaryOp : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class CaseCondition : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *when_expr_;
  NewExpr *then_expr_;
};

class CaseConditionList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<CaseCondition *> v_case_condition_list_;
};

class FunctionName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_;
};

class ColumnName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_col_;
  Identifier *identifier_tbl_;
};

class Literal : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
};

class StringLiteral : public Literal {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  string str_val_;
};

class BlobLiteral : public Literal {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  string str_val_;
};

class NumericLiteral : public Literal {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  string value_;
};

class OptDeferrableClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  DeferrableClause *deferrable_clause_;
};

class DeferrableClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
  OptNot *opt_not_;
};

class OptForeignKeyOnList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ForeignKeyOnList *foreign_key_on_list_;
};

class ForeignKeyOnList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<ForeignKeyOn *> v_foreign_key_on_list_;
};

class ForeignKeyOn : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
  Identifier *identifier_;
};

class ForeignKeyClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *foreign_table_;
  OptColumnListParen *opt_column_list_paren_;
  OptForeignKeyOnList *opt_foreign_key_on_list_;
  OptDeferrableClause *opt_deferrable_clause_;
};

class SignedNumber : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char * str_sign_;
  NumericLiteral *numeric_literal_;
};

class NullLiteral : public Literal {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
};

class ParamExpr : public Literal {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
};

class Identifier : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier(string s, IDTYPE id_type = id_whatever)
      : id_str_(s), id_type_(id_type) {}
  string id_str_;
  IDTYPE id_type_;
};

class TableRefCommaList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<TableRefAtomic *> v_table_ref_comma_list_;
};

class TableRefAtomic : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NonjoinTableRefAtomic *nonjoin_table_ref_atomic_;
  JoinClause *join_clause_;
};

class NonjoinTableRefAtomic : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableRefName *table_ref_name_;
  SelectStatement *select_statement_;
  OptTableAlias *opt_table_alias_;
};

class TableRefName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableName *table_name_;
  OptTableAlias *opt_table_alias_;
};

class OptReturningClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ResultColumnList *returning_column_list_;
};

class ResultColumnList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<ResultColumn *> v_result_column_list_;
};

class ResultColumn : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
  OptColumnAlias *opt_column_alias_;
  TableName *table_name_;
};

class QualifiedTableName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableName *table_name_;
  OptTableAliasAs *opt_table_alias_as_;
  OptIndex *opt_index_;
};

class OptColumnAlias : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ColumnAlias *column_alias_;
  ;
};

class ColumnAlias : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *alias_id_;
};

class TableAlias : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *alias_id_;
};

class OptTableAlias : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableAlias *table_alias_;
  bool has_as_;
};

class OptTableAliasAs : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableAlias *table_alias_;
};

class WithClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptRecursive *opt_recursive_;
  CommonTableExprList *common_table_expr_list_;
};

class OptWithClause : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  WithClause *with_clause_;
};

class CommonTableExprList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<CommonTableExpr *> v_common_table_expr_list_;
};

class CommonTableExpr : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableName *table_name_;
  SelectStatement *select_statement_;
  OptColumnListParen *opt_column_list_paren_;
};

class JoinSuffix : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  JoinOp *join_op_;
  TableOrSubquery *table_or_subquery_;
  JoinConstraint *join_constraint_;
};

class JoinSuffixList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<JoinSuffix *> v_join_suffix_list_;
};

class JoinClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  TableOrSubquery *table_or_subquery_;
  JoinSuffixList *join_suffix_list_;
};

class OptJoinType : public OptString {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  string str_val_;
};

class JoinConstraint : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OnExpr *on_expr_;
  ColumnNameList *column_name_list_;
};

class OptSemicolon : public OptString {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptSemicolon *opt_semicolon_;
  const char *str_val_;
};

class OptWithoutRowID : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptStrict: public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptColumnConstraintlist : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ColumnConstraintlist *column_constraintlist_;
};

class ColumnConstraintlist : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<ColumnConstraint *> v_column_constraint_;
};

class ColumnConstraint : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptConflictClause *opt_conflict_clause_;
  OptOrderType *opt_order_type_;
  OptAutoinc *opt_autoinc_;
  OptNot *opt_not_;
  NewExpr *expr_;
  Literal *literal_;
  SignedNumber *signed_number_;
  Collate *collate_;
  ForeignKeyClause *foreign_key_clause_;
  Identifier *identifier_;
  OptStoredVirtual *opt_stored_virtual_;
  OptConstraintName * opt_constraint_name_;
};

class TableConstraintList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<TableConstraint *> v_table_constraint_list_;
};

class TableConstraint : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptConstraintName *opt_constraint_name_;
  NewExpr *expr_;
  OptConflictClause *opt_conflict_clause_;
  IndexedColumnList *indexed_column_list_;
  ColumnNameList *column_name_list_;
  ForeignKeyClause *foreign_key_clause_;
};

class OptConflictClause : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ResolveType *resolve_type_;
};

class ResolveType : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptAutoinc : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptUnique : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class TableName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *database_id_;
  Identifier *identifier_;
};

class TriggerName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *database_id_;
  Identifier *identifier_;
};

class IndexName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *database_id_;
  Identifier *identifier_;
};

class OptTmp : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptTriggerTime : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class TriggerEvent : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptOfColumnList *opt_of_column_list_;
};

class OptOfColumnList : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ColumnNameList *column_name_list_;
};

class OptForEach : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptWhen : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
};

class TriggerCmdList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<TriggerCmd *> v_trigger_cmd_list_;
};

class TriggerCmd : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  PreparableStatement *stmt_;
};

class ModuleName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_;
};

class OptOverClause : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  WindowName *window_name_;
  WindowBody *window_body_;
};

class FilterClause : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  WhereExpr *where_expr_;
};
class OptFilterClause : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  FilterClause *filter_clause_;
};

class OptWindowClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  WindowClause *window_clause_;
};

class WindowClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  WindowDefnList *windowdefn_list_;
};

class WindowDefnList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<WindowDefn *> v_windowdefn_list_;
};

class WindowDefn : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  WindowName *window_name_;
  WindowBody *window_body_;
};

class WindowBody : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptBaseWindowName *opt_base_window_name_;
  OptPartitionBy *opt_partition_by_;
  OptOrder *opt_order_;
  OptFrame *opt_frame_;
};

class WindowName : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_;
};

class OptBaseWindowName : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_;
};

class OptFrame : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  RangeOrRows *range_or_rows_;
  FrameBoundS *frame_bound_s_;
  OptFrameExclude *opt_frame_exclude_;
  FrameBoundE *frame_bound_e_;
  FrameBound *frame_bound_;
};

class RangeOrRows : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class FrameBoundS : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
  NewExpr *expr_;
};

class FrameBoundE : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
  NewExpr *expr_;
};

class FrameBound : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
  const char *str_val_;
};

class FrameExclude : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptFrameExclude : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  FrameExclude *frame_exclude_;
};

class InsertValue : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ExprListParenList *expr_list_paren_list_;
  SelectStatement *select_statement_;
  OptUpsertClause *opt_upsert_clause_;
};

class UpdateType : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
  ResolveType *resolve_type_;
};

class InsertType : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
  ResolveType *resolve_type_;
};

class TableOrSubquery : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  SelectStatement *select_statement_;
  OptTableAlias *opt_table_alias_;
  TableOrSubqueryList *table_or_subquery_list_;
  TableName *table_name_;
  OptIndex *opt_index_;
  JoinClause *join_clause_;
};

class TableOrSubqueryList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<TableOrSubquery *> v_table_or_subquery_list_;
};

class JoinOp : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptIndex : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *index_name_;
};

class WhereExpr : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
};

class EscapeExpr : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
};

class ElseExpr : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
};

class OnExpr : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  NewExpr *expr_;
};

class SavepointStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *savepoint_name_;
};

class ReleaseStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *savepoint_name_;
};

class AlterStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ColumnDef *column_def_;
  TableName *table_name1_;
  TableName *table_name2_;
  ColumnName *column_name1_;
  ColumnName *column_name2_;
  OptColumn *opt_column_;
};

class OptColumn : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class VacuumStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptSchemaName *opt_schema_name_;
  FilePath *file_path_;
};

class OptSchemaName : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  SchemaName *schema_name_;
};

class RollbackStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptTransaction *opt_transaction_;
  OptToSavepoint *opt_to_savepoint_;
};

class OptTransaction : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptToSavepoint : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *savepoint_name_;
};

class BeginStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptTransaction *opt_transaction_;
};

class CommitStatement : public PreparableStatement {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptTransaction *opt_transaction_;
};

class OptUpsertClause : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  UpsertClause *upsert_clause_;
};

class UpsertClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<UpsertItem *> v_upsert_item_list_;
};

class UpsertItem : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptConflictTarget *opt_conflict_target_;
  AssignList *assign_list_;
  OptWhere *opt_where_;
};

class IndexedColumnList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<IndexedColumn *> v_indexed_column_list_;
};

class IndexedColumn : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  OptOrderType *opt_order_type_;
  NewExpr *expr_;
  OptCollate *opt_collate_;
};

class Collate : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *collate_name_;
};

class OptCollate : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Collate *collate_;
};

class AssignList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<AssignClause *> v_assign_list_;
};

class NullOfExpr : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class ExistsOrNot : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class OptOrderOfNull : public Opt {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *str_val_;
};

class AssignClause : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ColumnName *column_name_;
  ColumnNameList *column_name_list_;
  NewExpr *expr_;
};

class ColumnNameList : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  vector<ColumnName *> v_column_name_list_;
};

class OptConstraintName : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  Identifier *identifier_;
};

class PartitionBy : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ExprList *expr_list_;
};

class OptPartitionBy : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  PartitionBy *partition_by_;
};

class FunctionArgs : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  string str_val_;
  ExprList *expr_list_;
  OptDistinct *opt_distinct_;
};

class OptNot : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
};

class RaiseFunction : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  const char *to_raise_;
  Identifier *error_msg_;
};

class ConflictTarget : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  IndexedColumnList *indexed_column_list_;
  OptWhere *opt_where_;
};

class OptConflictTarget : public Node {
public:
  virtual void deep_delete();
  virtual IR *translate(vector<IR *> &v_ir_collector);
  ConflictTarget *conflict_target_;
};

string get_string_by_ir_type(IRTYPE);
string get_string_by_id_type(IDTYPE);

#endif

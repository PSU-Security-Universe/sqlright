#include "../include/ast.h"
#include "../include/utils.h"
#include <cassert>
#include <cstdio>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <vector>

static string s_table_name;

string get_string_by_ir_type(IRTYPE type) {

#define DECLARE_CASE(classname)                                                \
  if (type == k##classname)                                                    \
    return #classname;

  ALLCLASS(DECLARE_CASE);
#undef DECLARE_CASE

  return "";
}

string get_string_by_id_type(IDTYPE type) {

  switch (type) {
  case id_whatever:
    return "id_whatever";

  case id_create_table_name:
    return "id_create_table_name";
  case id_top_table_name:
    return "id_top_table_name";
  case id_table_name:
    return "id_table_name";

  case id_create_column_name:
    return "id_create_column_name";
  case id_column_name:
    return "id_column_name";

  case id_pragma_name:
    return "id_pragma_name";
  case id_pragma_value:
    return "id_pragma_value";

  case id_create_index_name:
    return "id_create_index_name";
  case id_index_name:
    return "id_index_name";

  case id_create_trigger_name:
    return "id_create_trigger_name";
  case id_trigger_name:
    return "id_trigger_name";

  case id_create_window_name:
    return "id_create_window_name";
  case id_window_name:
    return "id_window_name";
  case id_base_window_name:
    return "id_base_window_name";

  case id_create_savepoint_name:
    return "id_create_savepoint_name";
  case id_savepoint_name:
    return "id_savepoint_name";

  case id_schema_name:
    return "id_schema_name";
  case id_module_name:
    return "id_moudle_name";
  case id_collation_name:
    return "id_collation_name";
  case id_database_name:
    return "id_database_name";
  case id_alias_name:
    return "id_alias_name";
  case id_table_alias_name:
    return "id_table_alias_name";
  case id_column_alias_name:
    return "id_column_alias_name";
  case id_function_name:
    return "id_function_name";
  case id_table_constraint_name:
    return "id_table_constraint_name";
  case id_create_table_name_with_tmp:
    return "id_create_table_name_with_tmp";
  case id_create_column_name_with_tmp:
    return "id_create_column_name_with_tmp";
  default:
    return "unknown identifier type";
  }
}

string IR::to_string() {

  string res = "";
  _to_string(res);
  trim_string(res);
  return res;
}

// recursive function, frequently called. Must be very fast
void IR::_to_string(string &res) {

  if (type_ == kColumnName && str_val_ == "*") {
    res += str_val_;
    return;
  }

  if (type_ == kFilePath ||
      type_ == kNumericLiteral || type_ == kIdentifier ||
      type_ == kOptOrderType || type_ == kColumnType || type_ == kSetOperator ||
      type_ == kOptJoinType || type_ == kOptDistinct || type_ == kNullLiteral ||
      type_ == kconst_str) {
    res += str_val_;
    return;
  }

  if (type_ == kStringLiteral) {
     res += str_val_;
     return;
   }

  if (!str_val_.empty()) {
    res += str_val_;
    return;
  }

  if (op_ && op_->prefix_) {
    res += op_->prefix_;
    res +=  " ";
  }

  if (left_) {
    left_->_to_string(res);
    res += " ";
  }

  if (op_ && op_->middle_) {
    res += op_->middle_;
    res += " ";
  }

  if (right_) {
    right_->_to_string(res);
    res += " ";
  }

  if (op_ && op_->suffix_) {
    res += op_->suffix_;
  }

  return;
}

bool IR::detach_node(IR *node) { return swap_node(node, NULL); }

bool IR::swap_node(IR *old_node, IR *new_node) {

  IR *parent = this->locate_parent(old_node);

  if (parent == NULL) {
    // cerr << "Error: parent is null. Locate_parent error. In func: IR::swap_node(). \n";
    return false;
  }
  else if (parent->left_ == old_node)
    parent->update_left(new_node);
  else if (parent->right_ == old_node)
    parent->update_right(new_node);
  else {
    // cerr << "Error: parent-child not matching. In func: IR::swap_node(). \n";
    return false;
  }

  old_node->parent_ = NULL;

  return true;
}

IR *IR::locate_parent(IR *child) {

  for (IR *p = child; p; p = p->parent_)
    if (p->parent_ == this)
      return child->parent_;

  return NULL;
}

IR *IR::get_root() {

  IR *node = this;

  while (node->parent_ != NULL)
    node = node->parent_;

  return node;
}

IR *IR::get_parent() {

  return this->parent_;
}

void IR::update_left(IR *new_left) {

  // we do not update the parent_ of the old left_
  // we do not update the child of the old parent_ of new_left

  this->left_ = new_left;
  if (new_left)
    new_left->parent_ = this;
}

void IR::update_right(IR *new_right) {

  // we do not update the parent_ of the old right_
  // we do not update the child of the old parent_ of new_right

  this->right_ = new_right;
  if (new_right)
    new_right->parent_ = this;
}

void IR::drop() {

  if (this->op_)
    delete this->op_;
  delete this;
}

void IR::deep_drop() {

  if (this->left_)
    this->left_->deep_drop();

  if (this->right_)
    this->right_->deep_drop();

  this->drop();
}

IR *IR::deep_copy() {

  IR *left = NULL, *right = NULL, *copy_res;
  IROperator *op = NULL;

  if (this->left_)
    left = this->left_->deep_copy();
  if (this->right_)
    right = this->right_->deep_copy();

  if (this->op_ != NULL)
    op = OP3(this->op_->prefix_, this->op_->middle_, this->op_->suffix_);

  copy_res = new IR(this->type_, op, left, right, this->f_val_, this->str_val_,
                    this->mutated_times_);
  copy_res->id_type_ = this->id_type_;
  copy_res->parent_ = this->parent_;
  copy_res->str_val_ = this->str_val_;
  copy_res->uniq_id_in_tree_ = this->uniq_id_in_tree_;
  copy_res->operand_num_ = this->operand_num_;
  copy_res->is_node_struct_fixed = this->is_node_struct_fixed;

  return copy_res;
}

IR *QualifiedTableName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(table_name_);
  auto tmp1 = SAFETRANSLATE(opt_table_alias_as_);
  auto tmp2 = SAFETRANSLATE(opt_index_);

  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  res = new IR(kQualifiedTableName, OP0(), res, tmp2);

  TRANSLATEEND
}

void QualifiedTableName::deep_delete() {
  SAFEDELETE(table_name_);
  SAFEDELETE(opt_table_alias_as_);
  SAFEDELETE(opt_index_);
  delete this;
}

IR *TableName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  IR *tmp1 = SAFETRANSLATE(identifier_);
  res = new IR(kTableName, OP0(), tmp1);
  CASEEND
  CASESTART(1)
  IR *tmp1 = SAFETRANSLATE(database_id_);
  IR *tmp2 = SAFETRANSLATE(identifier_);
  res = new IR(kTableName, OPMID("."), tmp1, tmp2);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void TableName::deep_delete() {
  SAFEDELETE(identifier_);
  SAFEDELETE(database_id_);
  delete this;
}

IR *TriggerName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  IR *tmp1 = SAFETRANSLATE(identifier_);
  res = new IR(kTableName, OP0(), tmp1);
  CASEEND
  CASESTART(1)
  IR *tmp1 = SAFETRANSLATE(database_id_);
  IR *tmp2 = SAFETRANSLATE(identifier_);
  res = new IR(kTableName, OPMID("."), tmp1, tmp2);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void TriggerName::deep_delete() {
  SAFEDELETE(identifier_);
  SAFEDELETE(database_id_);
  delete this;
}

IR *IndexName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  IR *tmp1 = SAFETRANSLATE(identifier_);
  res = new IR(kTableName, OP0(), tmp1);
  CASEEND
  CASESTART(1)
  IR *tmp1 = SAFETRANSLATE(database_id_);
  IR *tmp2 = SAFETRANSLATE(identifier_);
  res = new IR(kTableName, OPMID("."), tmp1, tmp2);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void IndexName::deep_delete() {
  SAFEDELETE(identifier_);
  SAFEDELETE(database_id_);
  delete this;
}

IR *DropViewStatement::translate(vector<IR *> &v_ir_collector) {

  TRANSLATESTART

  IR *tmp1 = SAFETRANSLATE(opt_if_exists_);
  IR *tmp2 = SAFETRANSLATE(view_name_);
  res = new IR(kDropViewStatement, OPSTART("DROP VIEW"), tmp1, tmp2);

  TRANSLATEEND
}

void DropViewStatement::deep_delete() {
  SAFEDELETE(opt_if_exists_);
  SAFEDELETE(view_name_);
  delete this;
}

IR *DropTriggerStatement::translate(vector<IR *> &v_ir_collector) {

  TRANSLATESTART

  IR *tmp1 = SAFETRANSLATE(opt_if_exists_);
  IR *tmp2 = SAFETRANSLATE(trigger_name_);
  res = new IR(kDropTriggerStatement, OPSTART("DROP TRIGGER"), tmp1, tmp2);

  TRANSLATEEND
}

void DropTriggerStatement::deep_delete() {
  SAFEDELETE(opt_if_exists_);
  SAFEDELETE(trigger_name_);
  delete this;
}

IR *DropIndexStatement::translate(vector<IR *> &v_ir_collector) {

  TRANSLATESTART

  IR *tmp1 = SAFETRANSLATE(opt_if_exists_);
  IR *tmp2 = SAFETRANSLATE(index_name_);
  res = new IR(kDropIndexStatement, OPSTART("DROP INDEX"), tmp1, tmp2);

  TRANSLATEEND
}

void DropIndexStatement::deep_delete() {
  SAFEDELETE(opt_if_exists_);
  SAFEDELETE(index_name_);
  delete this;
}

IR *DropTableStatement::translate(vector<IR *> &v_ir_collector) {

  TRANSLATESTART

  IR *tmp1 = SAFETRANSLATE(opt_if_exists_);
  IR *tmp2 = SAFETRANSLATE(table_name_);
  res = new IR(kDropTableStatement, OPSTART("DROP TABLE"), tmp1, tmp2);

  TRANSLATEEND
}

void DropTableStatement::deep_delete() {
  SAFEDELETE(opt_if_exists_);
  SAFEDELETE(table_name_);
  delete this;
}

IR *DropStatement::translate(vector<IR *> &v_ir_collector) { assert(0); }

IR *OptIfExists::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptIfExists, OP1(str_val_));

  TRANSLATEEND
}

IR *Node::translate(vector<IR *> &v_ir_collector) { return NULL; }

IR *Opt::translate(vector<IR *> &v_ir_collector) { return NULL; }

IR *OptString::translate(vector<IR *> &v_ir_collector) { return NULL; }

IR *Program::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(statement_list_);
  auto tmp = SAFETRANSLATE(opt_semicolon_suffix_);
  res = new IR(kProgram, OP0(), res, tmp);

  TRANSLATEEND
}

IR *StatementList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kStatementList, v_statement_list_, ";");
  TRANSLATEENDNOPUSH
}

IR *Statement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(preparable_statement_);
  res = new IR(kStatement, OP0(), res);

  TRANSLATEEND
}

IR *PreparableStatement::translate(vector<IR *> &v_ir_collector) { assert(0); }

IR *SelectStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(opt_with_clause_);
  auto tmp1 = SAFETRANSLATE(select_core_list_);
  auto tmp2 = SAFETRANSLATE(opt_order_);
  //auto tmp3 = SAFETRANSLATE(opt_limit_);

  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  res = new IR(kSelectStatement, OP0(), res, tmp2);

  TRANSLATEEND
}

IR *CreateTriggerStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(opt_tmp_);
  auto tmp1 = SAFETRANSLATE(opt_if_not_exists_);
  res = new IR(kUnknown, OP2("CREATE", "TRIGGER"), tmp0, tmp1);
  PUSH(res);

  auto tmp2 = SAFETRANSLATE(trigger_name_);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);

  auto tmp3 = SAFETRANSLATE(opt_trigger_time_);
  res = new IR(kUnknown, OP0(), res, tmp3);
  PUSH(res);

  auto tmp4 = SAFETRANSLATE(trigger_event_);
  res = new IR(kUnknown, OP0(), res, tmp4);
  PUSH(res);

  auto tmp5 = SAFETRANSLATE(table_name_);
  res = new IR(kUnknown, OPMID("ON"), res, tmp5);
  PUSH(res);

  auto tmp6 = SAFETRANSLATE(opt_for_each_);
  res = new IR(kUnknown, OP0(), res, tmp6);
  PUSH(res);

  auto tmp7 = SAFETRANSLATE(opt_when_);
  res = new IR(kUnknown, OP0(), res, tmp7);
  PUSH(res);

  auto tmp8 = SAFETRANSLATE(trigger_cmd_list_);
  res = new IR(kCreateTriggerStatement, OP3("", "BEGIN", "END"), res, tmp8);

  TRANSLATEEND
}

void CreateTriggerStatement::deep_delete() {
  SAFEDELETE(opt_tmp_);
  SAFEDELETE(opt_if_not_exists_);
  SAFEDELETE(trigger_name_);
  SAFEDELETE(opt_trigger_time_);
  SAFEDELETE(trigger_event_);
  SAFEDELETE(table_name_);
  SAFEDELETE(opt_for_each_);
  SAFEDELETE(opt_when_);
  SAFEDELETE(trigger_cmd_list_);
  delete this;
}

IR *CreateVirtualTableStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp1 = SAFETRANSLATE(opt_if_not_exists_);
  auto tmp2 = SAFETRANSLATE(table_name_);
  res = new IR(kUnknown, OP1("CREATE VIRTUAL TABLE"), tmp1, tmp2);
  PUSH(res);
  auto tmp3 = SAFETRANSLATE(module_name_);
  res = new IR(kUnknown, OPMID("USING"), res, tmp3);
  PUSH(res);
  auto tmp4 = SAFETRANSLATE(opt_column_list_paren_);
  res = new IR(kUnknown, OP0(), res, tmp4);
  PUSH(res);
  auto tmp5 = SAFETRANSLATE(opt_without_rowid_);
  res = new IR(kCreateVirtualTableStatement, OP0(), res, tmp5);

  TRANSLATEEND;
}

void CreateVirtualTableStatement::deep_delete() {
  SAFEDELETE(opt_if_not_exists_);
  SAFEDELETE(table_name_);
  SAFEDELETE(module_name_);
  SAFEDELETE(opt_column_list_paren_);
  SAFEDELETE(opt_without_rowid_);
  delete this;
}

IR *CreateIndexStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp1 = SAFETRANSLATE(opt_unique_);
  auto tmp2 = SAFETRANSLATE(opt_if_not_exists_);
  res = new IR(kUnknown, OP2("CREATE", "INDEX"), tmp1, tmp2);
  PUSH(res);
  auto tmp3 = SAFETRANSLATE(index_name_);
  res = new IR(kUnknown, OP0(), res, tmp3);
  PUSH(res);
  auto tmp4 = SAFETRANSLATE(table_name_);
  res = new IR(kUnknown, OPMID("ON"), res, tmp4);
  PUSH(res);
  auto tmp5 = SAFETRANSLATE(indexed_column_list_);
  res = new IR(kUnknown, OP3("", "(", ")"), res, tmp5);
  PUSH(res);
  auto tmp6 = SAFETRANSLATE(opt_where_);
  res = new IR(kCreateIndexStatement, OP0(), res, tmp6);

  TRANSLATEEND;
}

void CreateIndexStatement::deep_delete() {
  SAFEDELETE(opt_unique_);
  SAFEDELETE(opt_if_not_exists_);
  SAFEDELETE(index_name_);
  SAFEDELETE(table_name_);
  SAFEDELETE(indexed_column_list_);
  SAFEDELETE(opt_where_);
  delete this;
}

IR *CreateViewStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(opt_tmp_);
  auto tmp1 = SAFETRANSLATE(opt_if_not_exists_);
  res = new IR(kUnknown, OPMID("VIEW"), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(view_name_);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);
  auto tmp3 = SAFETRANSLATE(opt_column_list_paren_);
  res = new IR(kUnknown, OP0(), res, tmp3);
  PUSH(res);
  auto tmp5 = SAFETRANSLATE(select_statement_);
  res = new IR(kCreateViewStatement, OP2("CREATE", "AS"), res, tmp5);

  TRANSLATEEND;
}

void CreateViewStatement::deep_delete() {
  SAFEDELETE(opt_tmp_);
  SAFEDELETE(opt_if_not_exists_);
  SAFEDELETE(view_name_);
  SAFEDELETE(opt_column_list_paren_);
  SAFEDELETE(select_statement_);
  delete this;
}

IR *CreateTableStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  //auto tmp0 = SAFETRANSLATE(opt_tmp_);
  auto tmp1 = SAFETRANSLATE(opt_if_not_exists_);
  auto tmp2 = SAFETRANSLATE(table_name_);

  res = new IR(kUnknown, OP1("CREATE TABLE"), tmp1, tmp2);
  PUSH(res);

  SWITCHSTART
  CASESTART(0)
  auto tmp3 = SAFETRANSLATE(select_statement_);
  res = new IR(kCreateTableStatement, OPMID("AS"), res, tmp3);
  CASEEND
  CASESTART(1)
  auto tmp3 = SAFETRANSLATE(column_def_list_);
  res = new IR(kUnknown, OP3("", "(", ")"), res, tmp3);
  PUSH(res);
  auto tmp4 = SAFETRANSLATE(opt_without_rowid_);
  res = new IR(kUnknown, OP0(), res, tmp4);
  PUSH(res);
  auto tmp5 = SAFETRANSLATE(opt_strict_);
  res = new IR(kCreateTableStatement, OP0(), res, tmp5);
  CASEEND
  CASESTART(2)
  auto tmp3 = SAFETRANSLATE(column_def_list_);
  auto tmp4 = SAFETRANSLATE(table_constraint_list_);
  auto tmp = new IR(kUnknown, OPMID(","), tmp3, tmp4);
  PUSH(tmp);
  res = new IR(kUnknown, OP3("", "(", ")"), res, tmp);
  PUSH(res);
  auto tmp5 = SAFETRANSLATE(opt_without_rowid_);
  res = new IR(kUnknown, OP0(), res, tmp5);
  PUSH(res);
  auto tmp6 = SAFETRANSLATE(opt_strict_);
  res = new IR(kCreateTableStatement, OP0(), res, tmp6);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void CreateTableStatement::deep_delete() {
  SAFEDELETE(opt_tmp_);
  SAFEDELETE(opt_if_not_exists_);
  SAFEDELETE(table_name_);
  SAFEDELETE(select_statement_);
  SAFEDELETE(column_def_list_);
  SAFEDELETE(opt_without_rowid_);
  SAFEDELETE(table_constraint_list_);
  SAFEDELETE(opt_strict_);
  delete this;
}

IR *CreateStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  assert(0);

  TRANSLATEEND
}

IR *InsertStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(opt_with_clause_);
  auto tmp1 = SAFETRANSLATE(insert_type_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);

  auto tmp = SAFETRANSLATE(table_name_);
  auto tmp2 = SAFETRANSLATE(opt_table_alias_as_);
  auto tmp3 = new IR(kUnknown, OP0(), tmp, tmp2);
  PUSH(tmp3);

  res = new IR(kUnknown, OP0(), res, tmp3);
  PUSH(res);

  tmp = SAFETRANSLATE(opt_column_list_paren_);
  res = new IR(kUnknown, OP0(), res, tmp);
  PUSH(res);

  tmp = SAFETRANSLATE(insert_value_);
  res = new IR(kUnknown, OP0(), res, tmp);
  PUSH(res);

  tmp = SAFETRANSLATE(opt_returning_clause_);
  res = new IR(kInsertStatement, OP0(), res, tmp);

  TRANSLATEEND
}

IR *InsertValue::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(expr_list_paren_list_);
  auto tmp1 = SAFETRANSLATE(opt_upsert_clause_);
  res = new IR(kInsertValue, OP1("VALUES"), tmp0, tmp1);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(select_statement_);
  auto tmp1 = SAFETRANSLATE(opt_upsert_clause_);
  res = new IR(kInsertValue, OP0(), tmp0, tmp1);
  CASEEND
  CASESTART(2)
  res = new IR(kInsertValue, OP1("DEFAULT VALUES"));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void InsertValue::deep_delete() {
  SAFEDELETE(expr_list_paren_list_);
  SAFEDELETE(select_statement_);
  SAFEDELETE(opt_upsert_clause_);
  delete this;
}

IR *UpdateType::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kUpdateType, OP1(str_val_));
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(resolve_type_);
  res = new IR(kUpdateType, OP1("UPDATE OR"), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void UpdateType::deep_delete() {
  SAFEDELETE(resolve_type_);
  delete this;
}

IR *InsertType::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kInsertType, OP1(str_val_));
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(resolve_type_);
  res = new IR(kInsertType, OP2("INSERT OR", "INTO"), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void InsertType::deep_delete() {
  SAFEDELETE(resolve_type_);
  delete this;
}

IR *DeleteStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  IR *tmp0 = SAFETRANSLATE(opt_with_clause_);
  IR *tmp1 = SAFETRANSLATE(qualified_table_name_);
  IR *tmp2 = SAFETRANSLATE(opt_where_);
  IR *tmp3 = SAFETRANSLATE(opt_returning_clause_);
  res = new IR(kUnknown, OPMID("DELETE FROM"), tmp0, tmp1);
  PUSH(res);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);
  res = new IR(kDeleteStatement, OP0(), res, tmp3);

  TRANSLATEEND
}

IR *UpdateStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(opt_with_clause_);
  auto tmp1 = SAFETRANSLATE(update_type_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);

  auto tmp2 = SAFETRANSLATE(qualified_table_name_);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);

  auto tmp3 = SAFETRANSLATE(update_clause_list_);
  res = new IR(kUnknown, OPMID("SET"), res, tmp3);
  PUSH(res);

  auto tmp4 = SAFETRANSLATE(opt_from_clause_);
  res = new IR(kUnknown, OP0(), res, tmp4);
  PUSH(res);

  auto tmp5 = SAFETRANSLATE(opt_where_);
  res = new IR(kUnknown, OP0(), res, tmp5);
  PUSH(res);

  auto tmp6 = SAFETRANSLATE(opt_returning_clause_);
  res = new IR(kUpdateStatement, OP0(), res, tmp6);

  TRANSLATEEND
}

void UpdateStatement::deep_delete() {
  SAFEDELETE(opt_with_clause_);
  SAFEDELETE(update_type_);
  SAFEDELETE(qualified_table_name_);
  SAFEDELETE(update_clause_list_);
  SAFEDELETE(opt_from_clause_);
  SAFEDELETE(opt_where_);
  SAFEDELETE(opt_returning_clause_);
  delete this;
}

IR *FilePath::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kFilePath, str_val_);

  TRANSLATEEND
}

IR *OptRecursive::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptRecursive, OP1(str_val_));
  TRANSLATEEND
}

void OptRecursive::deep_delete() { delete this; }

IR *OptIfNotExists::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptIfNotExists, OP1(str_val_));

  TRANSLATEEND
}

void OptIfNotExists::deep_delete() { delete this; }

IR *ColumnDefList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kColumnDefList, v_column_def_list_, ",");
  TRANSLATEENDNOPUSH
}

IR *ColumnDef::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(identifier_);
  auto tmp = SAFETRANSLATE(column_type_);
  res = new IR(kUnknown, OP0(), res, tmp);
  PUSH(res);

  tmp = SAFETRANSLATE(opt_column_constraintlist_);
  res = new IR(kColumnDef, OP0(), res, tmp);

  TRANSLATEEND
}

IR *ColumnType::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kColumnType, str_val_);

  TRANSLATEEND
}

IR *OptColumnNullable::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptColumnNullable, str_val_);

  TRANSLATEEND
}

IR *OptColumnListParen::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(column_name_list_);
  res = new IR(kOptColumnListParen, OP3("(", "", ")"), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptColumnListParen, "");
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptColumnListParen::deep_delete() {
  SAFEDELETE(column_name_list_);
  delete this;
}

IR *UpdateClauseList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kUpdateClauseList, v_update_clause_list_, ",");
  TRANSLATEENDNOPUSH
}

IR *UpdateClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART

  CASESTART(0)
  auto tmp1 = SAFETRANSLATE(column_name_);
  auto tmp2 = SAFETRANSLATE(expr_);
  res = new IR(kUpdateClause, OPMID("="), tmp1, tmp2);
  CASEEND
  CASESTART(1)
  auto tmp1 = SAFETRANSLATE(column_name_list_);
  auto tmp2 = SAFETRANSLATE(expr_);
  res = new IR(kUpdateClause, OP2("(", ") ="), tmp1, tmp2);
  CASEEND

  SWITCHEND

  TRANSLATEEND
}

IR *SelectCoreList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  assert(v_select_core_list_.size() == v_set_operator_list_.size() + 1);

  res = SAFETRANSLATE(v_select_core_list_[0]);
  for (int i = 1; i < v_select_core_list_.size(); i++) {
    IR *set_op = SAFETRANSLATE(v_set_operator_list_[i - 1]);
    res = new IR(kUnknown, OP0(), res, set_op);
    PUSH(res);
    IR *select_core = SAFETRANSLATE(v_select_core_list_[i]);
    res = new IR(kSelectCoreList, OP0(), res, select_core);
    PUSH(res);
  }
  TRANSLATEENDNOPUSH
}

void SelectCoreList::deep_delete() {

  for (auto select_core_ : v_select_core_list_)
    SAFEDELETE(select_core_);

  for (auto set_operator_ : v_set_operator_list_)
    SAFEDELETE(set_operator_);

  delete this;
}

IR *SetOperator::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kSetOperator, OP1(str_val_));

  TRANSLATEEND
}

IR *SelectCore::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(opt_distinct_);
  auto tmp1 = SAFETRANSLATE(result_column_list_);
  auto tmp2 = SAFETRANSLATE(opt_from_clause_);
  auto tmp3 = SAFETRANSLATE(opt_where_);
  auto tmp4 = SAFETRANSLATE(opt_group_);
  auto tmp5 = SAFETRANSLATE(opt_window_clause_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);
  res = new IR(kUnknown, OP0(), res, tmp3);
  PUSH(res);
  res = new IR(kUnknown, OP0(), res, tmp4);
  PUSH(res);
  res = new IR(kSelectCore, OP1("SELECT"), res, tmp5);
  CASEEND
  CASESTART(1)
  auto tmp = SAFETRANSLATE(expr_list_paren_list_);
  res = new IR(kSelectCore, OP1("VALUES"), tmp);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

IR *OptStoredVirtual::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptStoredVirtual, OP1(str_val_));

  TRANSLATEEND
}

void OptStoredVirtual::deep_delete() { delete this; }

IR *OptDistinct::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptDistinct, OP1(str_val_));

  TRANSLATEEND
}

IR *SelectList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(expr_list_);
  res = new IR(kSelectList, OP0(), res);

  TRANSLATEEND
}

IR *FromClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART

  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(join_clause_);
  res = new IR(kFromClause, OPSTART("FROM"), tmp0);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(table_or_subquery_list_);
  res = new IR(kFromClause, OPSTART("FROM"), tmp0);
  CASEEND

  SWITCHEND

  TRANSLATEEND
}

void FromClause::deep_delete() {
  // SAFEDELETE(table_ref_);
  SAFEDELETE(join_clause_);
  SAFEDELETE(table_or_subquery_list_);
  delete this;
}

IR *OptFromClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(from_clause_);
  auto tmp0 = SAFETRANSLATE(opt_column_alias_);
  res = new IR(kOptFromClause, OP0(), res, tmp0);
  CASEEND
  CASESTART(1)
  res = new IR(kOptFromClause, "");
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *OptWhere::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  IR *tmp1 = SAFETRANSLATE(where_expr_);
  res = new IR(kOptWhere, OP0(), tmp1);
  CASEEND
  CASESTART(1)
  res = new IR(kOptWhere, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptWhere::deep_delete() {
  SAFEDELETE(where_expr_);
  delete this;
}

IR *OptElseExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  IR *tmp1 = SAFETRANSLATE(else_expr_);
  res = new IR(kOptElseExpr, OP0(), tmp1);
  CASEEND
  CASESTART(1)
  res = new IR(kOptElseExpr, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptElseExpr::deep_delete() {
  SAFEDELETE(else_expr_);
  delete this;
}

IR *OptEscapeExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  IR *tmp1 = SAFETRANSLATE(escape_expr_);
  res = new IR(kOptEscapeExpr, OP0(), tmp1);
  CASEEND
  CASESTART(1)
  res = new IR(kOptEscapeExpr, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptEscapeExpr::deep_delete() {
  SAFEDELETE(escape_expr_);
  delete this;
}

IR *OptGroup::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp1 = SAFETRANSLATE(expr_list_);
  auto tmp2 = SAFETRANSLATE(opt_having_);
  res = new IR(kOptGroup, OPSTART("GROUP BY"), tmp1, tmp2);
  CASEEND
  CASESTART(1)
  res = new IR(kOptGroup, "");
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *OptHaving::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(expr_);
  res = new IR(kOptHaving, OP1("HAVING"), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptHaving, "");
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *OptOrder::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(order_list_);
  res = new IR(kOptOrder, OP1("ORDER BY"), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptOrder, OP1("ORDER BY 1"));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *OrderList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kOrderList, v_order_term_, ",");
  TRANSLATEENDNOPUSH
}

IR *OrderTerm::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(expr_);
  auto tmp = SAFETRANSLATE(opt_collate_);
  res = new IR(kUnknown, OP0(), res, tmp);
  PUSH(res);
  tmp = SAFETRANSLATE(opt_order_type_);
  res = new IR(kUnknown, OP0(), res, tmp);
  PUSH(res);
  tmp = SAFETRANSLATE(opt_order_of_null_);
  res = new IR(kOrderTerm, OP0(), res, tmp);

  TRANSLATEEND
}

IR *OptOrderType::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptOrderType, OP1(str_val_));

  TRANSLATEEND
}

void OptWithoutRowID::deep_delete() { delete this; }

IR *OptWithoutRowID::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptWithoutRowID, OP1(str_val_));
  TRANSLATEEND
}

void OptStrict::deep_delete() { delete this; }

IR *OptStrict::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptStrict, OP1(str_val_));
  TRANSLATEEND
}

IR *OptLimit::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(expr1_);
  res = new IR(kOptLimit, OPSTART("LIMIT"), tmp);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(expr1_);
  auto tmp1 = SAFETRANSLATE(expr2_);
  res = new IR(kOptLimit, OP2("LIMIT", "OFFSET"), tmp0, tmp1);
  CASEEND
  CASESTART(2)
  auto tmp0 = SAFETRANSLATE(expr1_);
  auto tmp1 = SAFETRANSLATE(expr2_);
  res = new IR(kOptLimit, OP2("LIMIT", ","), tmp0, tmp1);
  CASEEND
  CASESTART(3)
  res = new IR(kOptLimit, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptLimit::deep_delete() {
  SAFEDELETE(expr1_);
  SAFEDELETE(expr2_);
  delete this;
}

IR *ExprList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kExprList, v_expr_list_, ",");
  TRANSLATEENDNOPUSH
}

IR *ExprListParen::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto tmp = SAFETRANSLATE(expr_list_);
  res = new IR(kExprListParen, OP2("(", ")"), tmp);
  TRANSLATEEND
}

void ExprListParen::deep_delete() {
  SAFEDELETE(expr_list_);
  delete this;
}

IR *ExprListParenList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kExprListParenList, v_expr_list_paren_list_, ",");
  TRANSLATEENDNOPUSH
}

void ExprListParenList::deep_delete() {
  SAFEDELETELIST(v_expr_list_paren_list_);
  delete this;
}

IR *NewExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART

  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(literal_);
  res = new IR(kNewExpr, OP0(), tmp0);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(column_name_);
  res = new IR(kNewExpr, OP0(), tmp0);
  CASEEND
  CASESTART(2)
  auto tmp0 = SAFETRANSLATE(unary_op_);
  auto tmp1 = SAFETRANSLATE(new_expr1_);
  res = new IR(kNewExpr, OP0(), tmp0, tmp1);
  CASEEND
  CASESTART(3)
  auto tmp0 = SAFETRANSLATE(new_expr1_);
  auto tmp1 = SAFETRANSLATE(binary_op_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(new_expr2_);
  res = new IR(kNewExpr, OP0(), res, tmp2);
  CASEEND
  CASESTART(4)
  auto tmp0 = SAFETRANSLATE(function_name_);
  auto tmp1 = SAFETRANSLATE(function_args_);
  res = new IR(kUnknown, OP3("", "(", ")"), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(opt_filter_clause_);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);
  auto tmp3 = SAFETRANSLATE(opt_over_clause_);
  res = new IR(kNewExpr, OP0(), res, tmp3);
  CASEEND
  CASESTART(5)
  auto tmp0 = SAFETRANSLATE(expr_list_);
  res = new IR(kNewExpr, OP2("(", ")"), tmp0);
  CASEEND
  CASESTART(6)
  auto tmp0 = SAFETRANSLATE(new_expr1_);
  auto tmp1 = SAFETRANSLATE(column_type_);
  res = new IR(kNewExpr, OP3("CAST (", "AS", ")"), tmp0, tmp1);
  CASEEND
  CASESTART(7)
  auto tmp0 = SAFETRANSLATE(new_expr1_);
  auto tmp1 = SAFETRANSLATE(collate_);
  res = new IR(kNewExpr, OP0(), tmp0, tmp1);
  CASEEND
  CASESTART(8)
  auto tmp0 = SAFETRANSLATE(new_expr1_);
  auto tmp1 = SAFETRANSLATE(opt_not_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(binary_op_);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);
  auto tmp3 = SAFETRANSLATE(new_expr2_);
  res = new IR(kUnknown, OP0(), res, tmp3);
  PUSH(res);
  auto tmp4 = SAFETRANSLATE(opt_escape_expr_);
  res = new IR(kNewExpr, OP0(), res, tmp4);
  CASEEND
  CASESTART(9)
  auto tmp0 = SAFETRANSLATE(new_expr1_);
  auto tmp1 = SAFETRANSLATE(null_of_expr_);
  res = new IR(kNewExpr, OP0(), tmp0, tmp1);
  CASEEND
  CASESTART(10)
  auto tmp0 = SAFETRANSLATE(new_expr1_);
  auto tmp1 = SAFETRANSLATE(opt_not_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(new_expr2_);
  auto tmp3 = SAFETRANSLATE(new_expr3_);
  auto tmp4 = new IR(kUnknown, OP2("BETWEEN", "AND"), tmp2, tmp3);
  PUSH(tmp4);
  res = new IR(kNewExpr, OP0(), res, tmp4);
  CASEEND
  CASESTART(11)
  auto tmp0 = SAFETRANSLATE(new_expr1_);
  auto tmp1 = SAFETRANSLATE(opt_not_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(binary_op_);
  auto tmp3 = SAFETRANSLATE(in_target_);
  auto tmp4 = new IR(kUnknown, OP0(), tmp2, tmp3);
  PUSH(tmp4);
  res = new IR(kNewExpr, OP0(), res, tmp4);
  CASEEND
  CASESTART(12)
  auto tmp0 = SAFETRANSLATE(exists_or_not_);
  auto tmp1 = SAFETRANSLATE(select_statement_);
  res = new IR(kNewExpr, OP3("", "(", ")"), tmp0, tmp1);
  CASEEND
  CASESTART(13)
  auto tmp0 = SAFETRANSLATE(opt_expr_);
  auto tmp1 = SAFETRANSLATE(case_condition_list_);
  auto tmp2 = SAFETRANSLATE(opt_else_expr_);
  res = new IR(kUnknown, OP0(), tmp1, tmp2);
  PUSH(res);
  res = new IR(kNewExpr, OP3("CASE", "", "END"), tmp0, res);
  CASEEND
  CASESTART(14)
  auto tmp = SAFETRANSLATE(raise_function_);
  res = new IR(kNewExpr, OP0(), tmp);
  CASEEND
  CASESTART(15)
  auto tmp0 = SAFETRANSLATE(select_statement_);
  res = new IR(kNewExpr, OP2("(", ")"), tmp0);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void NewExpr::deep_delete() {
  SAFEDELETE(literal_);
  SAFEDELETE(column_name_);
  SAFEDELETE(unary_op_);
  SAFEDELETE(new_expr1_);
  SAFEDELETE(new_expr2_);
  SAFEDELETE(new_expr3_);
  SAFEDELETE(binary_op_);
  SAFEDELETE(function_name_);
  SAFEDELETE(function_args_);
  SAFEDELETE(opt_filter_clause_);
  SAFEDELETE(opt_over_clause_);
  SAFEDELETE(expr_list_);
  SAFEDELETE(column_type_);
  SAFEDELETE(collate_);
  SAFEDELETE(opt_not_);
  SAFEDELETE(opt_escape_expr_);
  SAFEDELETE(null_of_expr_);
  SAFEDELETE(in_target_);
  SAFEDELETE(select_statement_);
  SAFEDELETE(exists_or_not_);
  SAFEDELETE(opt_expr_);
  SAFEDELETE(case_condition_list_);
  SAFEDELETE(opt_else_expr_);
  SAFEDELETE(raise_function_);
  delete this;
}

IR *OptExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  IR *tmp1 = SAFETRANSLATE(expr_);
  res = new IR(kOptExpr, OP0(), tmp1);
  CASEEND
  CASESTART(1)
  res = new IR(kOptExpr, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptExpr::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

IR *UnaryOp::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kUnaryOp, OP1(str_val_));
  TRANSLATEEND
}

void UnaryOp::deep_delete() { delete this; }

IR *InTarget::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kInTarget, OP2("(", ")"));
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(select_statement_);
  res = new IR(kInTarget, OP2("(", ")"), tmp0);
  CASEEND
  CASESTART(2)
  auto tmp0 = SAFETRANSLATE(expr_list_);
  res = new IR(kInTarget, OP2("(", ")"), tmp0);
  CASEEND
  CASESTART(3)
  auto tmp0 = SAFETRANSLATE(table_name_);
  res = new IR(kInTarget, OP0(), tmp0);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void InTarget::deep_delete() {
  SAFEDELETE(select_statement_);
  SAFEDELETE(expr_list_);
  SAFEDELETE(table_name_);
  delete this;
}

IR *BinaryOp::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kBinaryOp, OP1(str_val_));
  TRANSLATEEND
}

void BinaryOp::deep_delete() { delete this; }

IR *CaseCondition::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp1 = SAFETRANSLATE(when_expr_);
  auto tmp2 = SAFETRANSLATE(then_expr_);
  res = new IR(kCaseCondition, OP2("WHEN", "THEN"), tmp1, tmp2);

  TRANSLATEEND
}
IR *CaseConditionList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kCaseConditionList, v_case_condition_list_, " ");
  TRANSLATEENDNOPUSH
}

IR *TableConstraintList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kTableConstraintList, v_table_constraint_list_, ",");
  TRANSLATEENDNOPUSH
}

void TableConstraintList::deep_delete() {
  SAFEDELETELIST(v_table_constraint_list_);
  delete this;
}

IR *TableConstraint::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(opt_constraint_name_);

  SWITCHSTART
  CASESTART(0)
  auto tmp1 = SAFETRANSLATE(expr_);
  res = new IR(kTableConstraint, OP3("", "CHECK(", ")"), tmp0, tmp1);
  CASEEND
  CASESTART(1)
  auto tmp1 = SAFETRANSLATE(indexed_column_list_);
  auto tmp2 = SAFETRANSLATE(opt_conflict_clause_);
  res = new IR(kUnknown, OP2("PRIMARY KEY (", ")"), tmp1, tmp2);
  PUSH(res);
  res = new IR(kTableConstraint, OP0(), tmp0, res);
  CASEEND
  CASESTART(2)
  auto tmp1 = SAFETRANSLATE(indexed_column_list_);
  auto tmp2 = SAFETRANSLATE(opt_conflict_clause_);
  res = new IR(kUnknown, OP2("UNIQUE (", ")"), tmp1, tmp2);
  PUSH(res);
  res = new IR(kTableConstraint, OP0(), tmp0, res);
  CASEEND
  CASESTART(3)
  auto tmp1 = SAFETRANSLATE(column_name_list_);
  auto tmp2 = SAFETRANSLATE(foreign_key_clause_);
  res = new IR(kUnknown, OP2("FOREIGN KEY (", ")"), tmp1, tmp2);
  PUSH(res);
  res = new IR(kTableConstraint, OP0(), tmp0, res);
  CASEEND

  SWITCHEND

  TRANSLATEEND
}

void TableConstraint::deep_delete() {
  SAFEDELETE(opt_constraint_name_);
  SAFEDELETE(expr_);
  SAFEDELETE(opt_conflict_clause_);
  SAFEDELETE(indexed_column_list_);
  SAFEDELETE(column_name_list_);
  SAFEDELETE(foreign_key_clause_);
  delete this;
}

IR *OptConstraintName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART

  CASESTART(0)
  res = SAFETRANSLATE(identifier_);
  res = new IR(kOptConstraintName, OP1("CONSTRAINT"), res);
  CASEEND

  CASESTART(1)
  res = new IR(kOptConstraintName, "");
  CASEEND

  SWITCHEND

  TRANSLATEEND
}

void OptConstraintName::deep_delete() {
  SAFEDELETE(identifier_);
  delete this;
}

IR *FunctionArgs::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(opt_distinct_);
  auto tmp1 = SAFETRANSLATE(expr_list_);
  res = new IR(kFunctionArgs, OP0(), tmp0, tmp1);
  CASEEND
  CASESTART(1)
  res = new IR(kFunctionArgs, str_val_);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void FunctionArgs::deep_delete() {
  SAFEDELETE(opt_distinct_);
  SAFEDELETE(expr_list_);
  delete this;
}

IR *FunctionName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto tmp0 = SAFETRANSLATE(identifier_);
  res = new IR(kFunctionName, OP0(), tmp0);
  TRANSLATEEND
}

void FunctionName::deep_delete() {
  SAFEDELETE(identifier_);
  delete this;
}

IR *ColumnName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(identifier_col_);
  res = new IR(kColumnName, OP0(), res);
  CASEEND
  //CASESTART(1)
  //res = SAFETRANSLATE(identifier1_);
  //IR *tmp = SAFETRANSLATE(identifier2_);
  //res = new IR(kColumnName, OPMID("."), res, tmp);
  ////res->id_type_ = id_column_name;
  //CASEEND
  CASESTART(2)
  res = new IR(kColumnName, string("*"));
  CASEEND
  CASESTART(3)
  res = SAFETRANSLATE(identifier_tbl_);
  IR *tmp = new IR(kconst_str, string("*"));
  PUSH(tmp);
  res = new IR(kColumnName, OPMID("."), res, tmp);
  res->id_type_ = id_column_name;
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *Literal::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  assert(0);
  TRANSLATEEND
}

IR *StringLiteral::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kStringLiteral, "'" + str_val_ + "'");

  TRANSLATEEND
}

IR *BlobLiteral::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kBlobLiteral, "x'" + str_val_ + "'");

  TRANSLATEEND
}

IR *SignedNumber::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto tmp = SAFETRANSLATE(numeric_literal_);
  res = new IR(kSignedNumber, OP1(str_sign_), tmp);
  TRANSLATEEND
}

void SignedNumber::deep_delete() {
  SAFEDELETE(numeric_literal_);
  delete this;
}

IR *NumericLiteral::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kNumericLiteral, value_);
  TRANSLATEEND
}

void NumericLiteral::deep_delete() { delete this; }

IR *NullLiteral::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kNullLiteral, string("NULL"));

  TRANSLATEEND
}

IR *ParamExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kParamExpr, string("?"));

  TRANSLATEEND
}

IR *Identifier::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kIdentifier, id_str_, id_type_);

  TRANSLATEEND
}

IR *TableRefCommaList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kTableRefCommaList, v_table_ref_comma_list_, ",");
  TRANSLATEENDNOPUSH
}

IR *TableRefAtomic::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(nonjoin_table_ref_atomic_);
  res = new IR(kTableRefAtomic, OP0(), res);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(join_clause_);
  res = new IR(kTableRefAtomic, OP0(), res);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *NonjoinTableRefAtomic::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(table_ref_name_);
  res = new IR(kNonjoinTableRefAtomic, OP0(), res);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(select_statement_);
  IR *tmp1 = SAFETRANSLATE(opt_table_alias_);
  res = new IR(kNonjoinTableRefAtomic, OP2("(", ")"), res, tmp1);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *TableRefName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp1 = SAFETRANSLATE(table_name_);
  auto tmp2 = SAFETRANSLATE(opt_table_alias_);
  res = new IR(kTableRefName, OP0(), tmp1, tmp2);

  TRANSLATEEND
}

IR *ColumnAlias::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(alias_id_);
  res = new IR(kColumnAlias, OP0(), res);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(alias_id_);
  res = new IR(kColumnAlias, OP1("AS"), res);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void ColumnAlias::deep_delete() {
  SAFEDELETE(alias_id_);
  delete this;
}

IR *TableAlias::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(alias_id_);
  res = new IR(kTableAlias, OP0(), res);

  TRANSLATEEND
}

void TableAlias::deep_delete() {
  SAFEDELETE(alias_id_);
  delete this;
}

IR *OptColumnAlias::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(column_alias_);
  res = new IR(kOptColumnAlias, OP0(), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptColumnAlias, "");
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptColumnAlias::deep_delete() {
  SAFEDELETE(column_alias_);
  delete this;
}

IR *OptReturningClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(returning_column_list_);
  res = new IR(kOptReturningClause, OP1("RETURNING"), tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptReturningClause, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptReturningClause::deep_delete() {
  SAFEDELETE(returning_column_list_);
  delete this;
}

IR *ResultColumnList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kResultColumnList, v_result_column_list_, ",");
  TRANSLATEENDNOPUSH
}

void ResultColumnList::deep_delete() {
  SAFEDELETELIST(v_result_column_list_);
  delete this;
}

IR *ResultColumn::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(expr_);
  auto tmp1 = SAFETRANSLATE(opt_column_alias_);
  res = new IR(kResultColumn, OP0(), tmp0, tmp1);
  CASEEND
  CASESTART(1)
  res = new IR(kResultColumn, OP1("*"));
  CASEEND
  CASESTART(2)
  auto tmp0 = SAFETRANSLATE(table_name_);
  res = new IR(kResultColumn, OPMID(". *"), tmp0);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void ResultColumn::deep_delete() {
  SAFEDELETE(expr_);
  SAFEDELETE(opt_column_alias_);
  SAFEDELETE(table_name_);
  delete this;
}

IR *OptTableAliasAs::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(table_alias_);
  res = new IR(kOptTableAliasAs, OP1("AS"), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptTableAliasAs, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptTableAliasAs::deep_delete() {
  SAFEDELETE(table_alias_);
  delete this;
}

IR *OptTableAlias::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(table_alias_);
  if (has_as_) {
    res = new IR(kOptTableAlias, OP1("AS"), res);
  } else {
    res = new IR(kOptTableAlias, OP0(), res);
  }
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(table_alias_);
  res = new IR(kOptTableAlias, OP1("AS"), res);
  CASEEND
  CASESTART(2)
  res = new IR(kOptTableAlias, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptTableAlias::deep_delete() {
  SAFEDELETE(table_alias_);
  delete this;
}

IR *WithClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(opt_recursive_);
  auto tmp1 = SAFETRANSLATE(common_table_expr_list_);
  res = new IR(kWithClause, OPSTART("WITH"), tmp0, tmp1);

  TRANSLATEEND
}

IR *OptWithClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(with_clause_);
  res = new IR(kOptWithClause, OP0(), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptWithClause, "");
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *CommonTableExprList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kCommonTableExprList, v_common_table_expr_list_, ",");
  TRANSLATEENDNOPUSH
}

void CommonTableExprList::deep_delete() {
  SAFEDELETELIST(v_common_table_expr_list_);
  delete this;
}

IR *CommonTableExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(table_name_);
  auto tmp1 = SAFETRANSLATE(opt_column_list_paren_);
  auto tmp2 = SAFETRANSLATE(select_statement_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  res = new IR(kCommonTableExpr, OP3("", "AS (", ")"), res, tmp2);

  TRANSLATEEND
}

void CommonTableExpr::deep_delete() {
  SAFEDELETE(table_name_);
  SAFEDELETE(opt_column_list_paren_);
  SAFEDELETE(select_statement_);
  delete this;
}

IR *JoinSuffix::translate(vector<IR *> &v_ir_collector) {

  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(join_op_);
  auto tmp1 = SAFETRANSLATE(table_or_subquery_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(join_constraint_);
  res = new IR(kJoinSuffix, OP0(), res, tmp2);
  TRANSLATEEND
}

void JoinSuffix::deep_delete() {
  SAFEDELETE(join_op_);
  SAFEDELETE(table_or_subquery_);
  SAFEDELETE(join_constraint_);
  delete this;
}

IR *JoinSuffixList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kJoinSuffixList, v_join_suffix_list_, " ");
  TRANSLATEENDNOPUSH
}

void JoinSuffixList::deep_delete() {
  SAFEDELETELIST(v_join_suffix_list_);
  delete this;
}

IR *JoinClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  // Insert a TableAlas node if it does not have one.
  //char start_alias_id = 'A';
  //if (table_or_subquery_ != NULL &&
  //    !table_or_subquery_->opt_table_alias_->is_existed_) {
  //  // TODO(vancir): use different identifier here.
  //  Identifier *alias_id = new Identifier(string(1, start_alias_id));
  //  start_alias_id += 1;

  //  TableAlias *table_alias = new TableAlias();
  //  table_alias->sub_type_ = CASE0;
  //  table_alias->alias_id_ = alias_id;

  //  OptTableAlias *opt_table_alias = new OptTableAlias();
  //  opt_table_alias->is_existed_ = true;
  //  opt_table_alias->has_as_ = true;
  //  opt_table_alias->table_alias_ = table_alias;

  //  table_or_subquery_->opt_table_alias_ = opt_table_alias;
  //}

  //if (join_suffix_list_ != NULL) {
  //  for (auto join_suffix : join_suffix_list_->v_join_suffix_list_) {
  //    if (!join_suffix->table_or_subquery_->opt_table_alias_->is_existed_) {
  //      // TODO(vancir): use different identifier here.
  //      Identifier *alias_id = new Identifier(string(1, start_alias_id));
  //      start_alias_id += 1;

  //      TableAlias *table_alias = new TableAlias();
  //      table_alias->sub_type_ = CASE0;
  //      table_alias->alias_id_ = alias_id;

  //      OptTableAlias *opt_table_alias = new OptTableAlias();
  //      opt_table_alias->is_existed_ = true;
  //      opt_table_alias->has_as_ = true;
  //      opt_table_alias->table_alias_ = table_alias;

  //      join_suffix->table_or_subquery_->opt_table_alias_ = opt_table_alias;
  //    }
  //  }
  //}

  SWITCHSTART

  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(table_or_subquery_);
  res = new IR(kJoinClause, OP0(), tmp0);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(table_or_subquery_);
  auto tmp1 = SAFETRANSLATE(join_suffix_list_);
  res = new IR(kJoinClause, OP0(), tmp0, tmp1);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void JoinClause::deep_delete() {
  SAFEDELETE(table_or_subquery_);
  SAFEDELETE(join_suffix_list_);
  delete this;
}

IR *OptJoinType::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptJoinType, str_val_);

  TRANSLATEEND
}

IR *JoinConstraint::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART

  CASESTART(0)
  res = SAFETRANSLATE(on_expr_);
  res = new IR(kJoinConstraint, OP0(), res);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(column_name_list_);
  res = new IR(kJoinConstraint, OP2("USING (", ")"), res);
  CASEEND
  CASESTART(2)
  res = new IR(kJoinConstraint, "");
  CASEEND

  SWITCHEND

  TRANSLATEEND
}

void JoinConstraint::deep_delete() {
  SAFEDELETE(on_expr_);
  SAFEDELETE(column_name_list_);
  delete this;
}

IR *OptSemicolon::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptSemicolon, OP1(str_val_));

  TRANSLATEEND
}

void Opt::deep_delete() { delete this; }

void OptString::deep_delete() { delete this; }

void Program::deep_delete() {
  SAFEDELETE(opt_semicolon_prefix_);
  SAFEDELETE(statement_list_);
  SAFEDELETE(opt_semicolon_suffix_);
  delete this;
}

void StatementList::deep_delete() {
  SAFEDELETELIST(v_statement_list_);
  SAFEDELETELIST(v_opt_semicolon_list_);
  delete this;
}

void Statement::deep_delete() {
  SAFEDELETE(preparable_statement_);
  delete this;
}

void PreparableStatement::deep_delete() { delete this; }

void SelectStatement::deep_delete() {
  SAFEDELETE(opt_with_clause_);
  SAFEDELETE(select_core_list_);
  SAFEDELETE(opt_order_);
  SAFEDELETE(opt_limit_);
  delete this;
}

void CreateStatement::deep_delete() { assert(0); }

void InsertStatement::deep_delete() {
  SAFEDELETE(opt_with_clause_);
  SAFEDELETE(insert_type_);
  SAFEDELETE(table_name_);
  SAFEDELETE(opt_table_alias_as_);
  SAFEDELETE(opt_column_list_paren_);
  SAFEDELETE(insert_value_);
  SAFEDELETE(opt_returning_clause_);
  delete this;
}

void DeleteStatement::deep_delete() {
  SAFEDELETE(opt_with_clause_);
  SAFEDELETE(qualified_table_name_);
  SAFEDELETE(opt_where_);
  SAFEDELETE(opt_returning_clause_);
  delete this;
}

void DropStatement::deep_delete() { assert(0); }

void FilePath::deep_delete() { delete this; }

void ColumnDefList::deep_delete() {
  SAFEDELETELIST(v_column_def_list_);
  delete this;
}

void ColumnDef::deep_delete() {
  SAFEDELETE(identifier_);
  SAFEDELETE(column_type_);
  SAFEDELETE(opt_column_constraintlist_);
  delete this;
}

void ColumnType::deep_delete() { delete this; }

void OptColumnNullable::deep_delete() { delete this; }

void OptIfExists::deep_delete() { delete this; }

void UpdateClauseList::deep_delete() {
  SAFEDELETELIST(v_update_clause_list_);
  delete this;
}

void UpdateClause::deep_delete() {
  SAFEDELETE(column_name_);
  SAFEDELETE(column_name_list_);
  SAFEDELETE(expr_);
  delete this;
}

void SetOperator::deep_delete() { delete this; }

void SelectCore::deep_delete() {
  SAFEDELETE(opt_distinct_);
  SAFEDELETE(result_column_list_);
  SAFEDELETE(opt_from_clause_);
  SAFEDELETE(opt_where_);
  SAFEDELETE(opt_group_);
  SAFEDELETE(opt_window_clause_);
  SAFEDELETE(expr_list_paren_list_);
  delete this;
}

void OptDistinct::deep_delete() { delete this; }

void SelectList::deep_delete() {
  SAFEDELETE(expr_list_);
  delete this;
}

void OptFromClause::deep_delete() {
  SAFEDELETE(from_clause_);
  SAFEDELETE(opt_column_alias_);
  delete this;
}

void OptGroup::deep_delete() {
  SAFEDELETE(expr_list_);
  SAFEDELETE(opt_having_);
  delete this;
}

void OptHaving::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

void OptOrder::deep_delete() {
  SAFEDELETE(order_list_);
  delete this;
}

void OrderList::deep_delete() {
  SAFEDELETELIST(v_order_term_);
  delete this;
}

void OrderTerm::deep_delete() {
  SAFEDELETE(expr_);
  SAFEDELETE(opt_collate_);
  SAFEDELETE(opt_order_type_);
  SAFEDELETE(opt_order_of_null_);
  delete this;
}

void OptOrderType::deep_delete() { delete this; }

void ExprList::deep_delete() {
  SAFEDELETELIST(v_expr_list_);
  delete this;
}

void CaseCondition::deep_delete() {
  SAFEDELETE(when_expr_);
  SAFEDELETE(then_expr_);
  delete this;
}

void CaseConditionList::deep_delete() {
  SAFEDELETELIST(v_case_condition_list_);
  delete this;
}

void ColumnName::deep_delete() {
  SAFEDELETE(identifier_col_);
  SAFEDELETE(identifier_tbl_);
  delete this;
}

void Literal::deep_delete() { delete this; }

void StringLiteral::deep_delete() { delete this; }

void BlobLiteral::deep_delete() { delete this; }

void NullLiteral::deep_delete() { delete this; }

void ParamExpr::deep_delete() { delete this; }

void Identifier::deep_delete() { delete this; }

void TableRefCommaList::deep_delete() {
  SAFEDELETELIST(v_table_ref_comma_list_);
  delete this;
}

void TableRefAtomic::deep_delete() {
  SAFEDELETE(nonjoin_table_ref_atomic_);
  SAFEDELETE(join_clause_);
  delete this;
}

void NonjoinTableRefAtomic::deep_delete() {
  SAFEDELETE(table_ref_name_);
  SAFEDELETE(select_statement_);
  SAFEDELETE(opt_table_alias_);
  delete this;
}

void TableRefName::deep_delete() {
  SAFEDELETE(table_name_);
  SAFEDELETE(opt_table_alias_);
  delete this;
}

void WithClause::deep_delete() {
  SAFEDELETE(opt_recursive_);
  SAFEDELETE(common_table_expr_list_);
  delete this;
}

void OptWithClause::deep_delete() {
  SAFEDELETE(with_clause_);
  delete this;
}

void OptJoinType::deep_delete() { delete this; }

void OptSemicolon::deep_delete() {
  SAFEDELETE(opt_semicolon_);
  delete this;
}

void AttachStatement::deep_delete() {
  SAFEDELETE(expr_);
  SAFEDELETE(schema_name_);
  delete this;
}

IR *AttachStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(expr_);
  auto tmp = SAFETRANSLATE(schema_name_);
  res = new IR(kAttachStatement, OP2("ATTACH", "AS"), res, tmp);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(expr_);
  auto tmp = SAFETRANSLATE(schema_name_);
  res = new IR(kAttachStatement, OP2("ATTACH DATABASE", "AS"), res, tmp);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

IR *ReindexStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kReindexStatement, OP1("REINDEX"));
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(table_name_);
  res = new IR(kReindexStatement, OP1("REINDEX"), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void ReindexStatement::deep_delete() {
  SAFEDELETE(table_name_);
  delete this;
}

void DetachStatement::deep_delete() {
  SAFEDELETE(schema_name_);
  delete this;
}

IR *DetachStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(schema_name_);
  res = new IR(kDetachStatement, OP1("DETACH"), res);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(schema_name_);
  res = new IR(kDetachStatement, OP1("DETACH DATABASE"), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void AnalyzeStatement::deep_delete() {
  SAFEDELETE(table_name_);
  delete this;
}

IR *AnalyzeStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kAnalyzeStatement, string("ANALYZE"));
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(table_name_);
  res = new IR(kAnalyzeStatement, OP1("ANALYZE"), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void PragmaStatement::deep_delete() {
  SAFEDELETE(pragma_key_);
  SAFEDELETE(pragma_value_);
  SAFEDELETE(table_name_);
  delete this;
}

IR *PragmaStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto pk = SAFETRANSLATE(pragma_key_);
  res = new IR(kPragmaStatement, OPSTART("PRAGMA"), pk);
  CASEEND
  CASESTART(1)
  auto pk = SAFETRANSLATE(pragma_key_);
  auto pv = SAFETRANSLATE(pragma_value_);
  res = new IR(kPragmaStatement, OP2("PRAGMA", "="), pk, pv);
  CASEEND
  CASESTART(2)
  auto pk = SAFETRANSLATE(pragma_key_);
  auto pv = SAFETRANSLATE(pragma_value_);
  res = new IR(kPragmaStatement, OP3("PRAGMA", "(", ")"), pk, pv);
  CASEEND
  CASESTART(3)
  res = new IR(kPragmaStatement, string("REINDEX"));
  CASEEND
  CASESTART(4)
  auto table_name = SAFETRANSLATE(table_name_);
  res = new IR(kPragmaStatement, OPSTART("REINDEX"), table_name);
  CASEEND
  CASESTART(5)
  res = new IR(kPragmaStatement, string("ANALYZE"));
  CASEEND
  CASESTART(6)
  auto table_name = SAFETRANSLATE(table_name_);
  res = new IR(kPragmaStatement, OPSTART("ANALYZE"), table_name);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void PragmaKey::deep_delete() {
  SAFEDELETE(pragma_name_);
  SAFEDELETE(schema_name_);
  delete this;
}

IR *PragmaKey::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto pn = SAFETRANSLATE(pragma_name_);

  SWITCHSTART
  CASESTART(0)
  res = new IR(kPragmaKey, OP0(), pn);
  CASEEND
  CASESTART(1)
  auto sn = SAFETRANSLATE(schema_name_);
  res = new IR(kPragmaKey, OPMID("."), sn, pn);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void PragmaValue::deep_delete() {
  SAFEDELETE(signed_number_);
  SAFEDELETE(string_literal_);
  SAFEDELETE(identifier_);
  delete this;
}

IR *PragmaValue::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(signed_number_);
  res = new IR(kPragmaValue, OP0(), res);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(string_literal_);
  res = new IR(kPragmaValue, OP0(), res);
  CASEEND
  CASESTART(2)
  res = SAFETRANSLATE(identifier_);
  res = new IR(kPragmaValue, OP0(), res);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void PragmaName::deep_delete() {
  SAFEDELETE(identifier_);
  delete this;
}

IR *PragmaName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto name = SAFETRANSLATE(identifier_);
  res = new IR(kPragmaName, OP0(), name);
  TRANSLATEEND
}

void SchemaName::deep_delete() {
  SAFEDELETE(identifier_);
  delete this;
}

IR *SchemaName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto name = SAFETRANSLATE(identifier_);
  res = new IR(kSchemaName, OP0(), name);
  TRANSLATEEND
}

IR *OptColumnConstraintlist::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(column_constraintlist_);
  res = new IR(kOptColumnConstraintlist, OP0(), tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptColumnConstraintlist, "");
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptColumnConstraintlist::deep_delete() {
  SAFEDELETE(column_constraintlist_);
  delete this;
}

IR *ColumnConstraintlist::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kColumnConstraintlist, v_column_constraint_, " ");
  TRANSLATEENDNOPUSH
}

void ColumnConstraintlist::deep_delete() {
  SAFEDELETELIST(v_column_constraint_);
  delete this;
}

IR *OptDeferrableClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(deferrable_clause_);
  res = new IR(kOptDeferrableClause, OP0(), tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptDeferrableClause, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptDeferrableClause::deep_delete() {
  SAFEDELETE(deferrable_clause_);
  delete this;
}

IR *DeferrableClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp = SAFETRANSLATE(opt_not_);
  res = new IR(kDeferrableClause, OP2("", str_val_), tmp);

  TRANSLATEEND
}

void DeferrableClause::deep_delete() {
  SAFEDELETE(opt_not_);
  delete this;
}

IR *OptForeignKeyOnList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(foreign_key_on_list_);
  res = new IR(kOptForeignKeyOnList, OP0(), tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptForeignKeyOnList, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptForeignKeyOnList::deep_delete() {
  SAFEDELETE(foreign_key_on_list_);
  delete this;
}

IR *ForeignKeyOnList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kForeignKeyOnList, v_foreign_key_on_list_, " ");
  TRANSLATEENDNOPUSH
}

void ForeignKeyOnList::deep_delete() {
  SAFEDELETELIST(v_foreign_key_on_list_);
  delete this;
}

IR *ForeignKeyOn::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kForeignKeyOn, OP1(str_val_));
  CASEEND
  CASESTART(1)
  auto tmp = SAFETRANSLATE(identifier_);
  res = new IR(kForeignKeyOn, OP1("MATCH"), tmp);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void ForeignKeyOn::deep_delete() {
  SAFEDELETE(identifier_);
  delete this;
}

IR *ForeignKeyClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(foreign_table_);
  auto tmp1 = SAFETRANSLATE(opt_column_list_paren_);
  auto tmp2 = SAFETRANSLATE(opt_foreign_key_on_list_);
  auto tmp3 = SAFETRANSLATE(opt_deferrable_clause_);

  res = new IR(kUnknown, OP1("REFERENCES"), tmp0, tmp1);
  PUSH(res);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);
  res = new IR(kForeignKeyClause, OP0(), res, tmp3);

  TRANSLATEEND
}

void ForeignKeyClause::deep_delete() {
  SAFEDELETE(foreign_table_);
  SAFEDELETE(opt_column_list_paren_);
  SAFEDELETE(opt_foreign_key_on_list_);
  SAFEDELETE(opt_deferrable_clause_);
  delete this;
}

IR *ColumnConstraint::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(opt_order_type_);
  auto tmp1 = SAFETRANSLATE(opt_conflict_clause_);
  res = new IR(kColumnConstraint, OP1("PRIMARY KEY"), tmp, tmp1);
  PUSH(res);
  tmp = SAFETRANSLATE(opt_autoinc_);
  res = new IR(kColumnConstraint, OP0(), res, tmp);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(opt_not_);
  auto tmp1 = SAFETRANSLATE(opt_conflict_clause_);
  res = new IR(kColumnConstraint, OPMID("NULL"), tmp0, tmp1);
  CASEEND
  CASESTART(2)
  res = SAFETRANSLATE(opt_conflict_clause_);
  res = new IR(kColumnConstraint, OP1("UNIQUE"), res);
  CASEEND
  CASESTART(3)
  res = SAFETRANSLATE(expr_);
  res = new IR(kColumnConstraint, OP2("CHECK(", ")"), res);
  CASEEND
  CASESTART(4)
  res = SAFETRANSLATE(expr_);
  res = new IR(kColumnConstraint, OP2("DEFAULT (", ")"), res);
  CASEEND
  CASESTART(5)
  res = SAFETRANSLATE(literal_);
  res = new IR(kColumnConstraint, OP1("DEFAULT"), res);
  CASEEND
  CASESTART(6)
  res = SAFETRANSLATE(signed_number_);
  res = new IR(kColumnConstraint, OP1("DEFAULT"), res);
  CASEEND
  CASESTART(7)
  res = SAFETRANSLATE(collate_);
  res = new IR(kColumnConstraint, OP0(), res);
  CASEEND
  CASESTART(8)
  res = SAFETRANSLATE(foreign_key_clause_);
  res = new IR(kColumnConstraint, OP0(), res);
  CASEEND
  CASESTART(9)
  auto tmp0 = SAFETRANSLATE(expr_);
  auto tmp1 = SAFETRANSLATE(opt_stored_virtual_);
  res = new IR(kColumnConstraint, OP2("GENERATED ALWAYS AS(", ")"), tmp0, tmp1);
  CASEEND
  CASESTART(10)
  res = SAFETRANSLATE(expr_);
  res = new IR(kColumnConstraint, OP2("AS(", ")"), res);
  CASEEND
  CASESTART(11)
  res = new IR(kColumnConstraint, OP1("GENERATED ALWAYS"));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void ColumnConstraint::deep_delete() {
  SAFEDELETE(opt_conflict_clause_);
  SAFEDELETE(opt_order_type_);
  SAFEDELETE(opt_autoinc_);
  SAFEDELETE(expr_);
  SAFEDELETE(opt_not_);
  SAFEDELETE(literal_);
  SAFEDELETE(signed_number_);
  SAFEDELETE(collate_);
  SAFEDELETE(foreign_key_clause_);
  SAFEDELETE(identifier_);
  SAFEDELETE(opt_stored_virtual_);
  SAFEDELETE(opt_constraint_name_);
  delete this;
}

IR *OptConflictClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(resolve_type_);
  res = new IR(kOptConflictClause, OP1("ON CONFLICT"), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptConflictClause, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptConflictClause::deep_delete() {
  SAFEDELETE(resolve_type_);
  delete this;
}

IR *ResolveType::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kResolveType, OP1(str_val_));
  TRANSLATEEND
}

void ResolveType::deep_delete() { delete this; }

IR *OptAutoinc::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptAutoinc, OP1(str_val_));
  TRANSLATEEND
}

void OptAutoinc::deep_delete() { delete this; }

IR *OptUnique::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptUnique, OP1(str_val_));
  TRANSLATEEND
}

void OptUnique::deep_delete() { delete this; }

IR *OptTmp::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptTmp, OP1(str_val_));
  TRANSLATEEND
}

void OptTmp::deep_delete() { delete this; }

IR *OptTriggerTime::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptTriggerTime, OP1(str_val_));
  TRANSLATEEND
}

void OptTriggerTime::deep_delete() { delete this; }

IR *TriggerEvent::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kTriggerEvent, string("DELETE"));
  CASEEND
  CASESTART(1)
  res = new IR(kTriggerEvent, string("INSERT"));
  CASEEND
  CASESTART(2)
  res = SAFETRANSLATE(opt_of_column_list_);
  res = new IR(kTriggerEvent, OP1("UPDATE"), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void TriggerEvent::deep_delete() {
  SAFEDELETE(opt_of_column_list_);
  delete this;
}

IR *OptOfColumnList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(column_name_list_);
  res = new IR(kOptOfColumnList, OP1("OF"), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptOfColumnList, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptOfColumnList::deep_delete() {
  SAFEDELETE(column_name_list_);
  delete this;
}

IR *OptForEach::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptForEach, OP1(str_val_));
  TRANSLATEEND
}

void OptForEach::deep_delete() { delete this; }

IR *OptWhen::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(expr_);
  res = new IR(kOptWhen, OP1("WHEN"), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptWhen, OP1(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptWhen::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

IR *TriggerCmdList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kTriggerCmdList, v_trigger_cmd_list_, ";");
  res->op_->suffix_ = ";";
  TRANSLATEENDNOPUSH
}

void TriggerCmdList::deep_delete() {
  SAFEDELETELIST(v_trigger_cmd_list_);
  delete this;
}

IR *TriggerCmd::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = SAFETRANSLATE(stmt_);
  TRANSLATEEND
}

void TriggerCmd::deep_delete() {
  SAFEDELETE(stmt_);
  delete this;
}

IR *ModuleName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = SAFETRANSLATE(identifier_);
  res = new IR(kModuleName, OP0(), res);
  TRANSLATEEND
}

void ModuleName::deep_delete() {
  SAFEDELETE(identifier_);
  delete this;
}

IR *OptOverClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(window_name_);
  res = new IR(kOptOverClause, OP1("OVER"), res);
  CASEEND
  CASESTART(1)
  auto tmp3 = SAFETRANSLATE(window_body_);
  res = new IR(kOptOverClause, OP2("OVER (", ")"), tmp3);
  CASEEND
  CASESTART(2)
  res = new IR(kOptOverClause, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptOverClause::deep_delete() {
  SAFEDELETE(window_name_);
  ;
  SAFEDELETE(window_body_);
  delete this;
}

IR *FilterClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(where_expr_);
  res = new IR(kFilterClause, OP2("FILTER (", ")"), res);
  CASEEND
  CASESTART(1)
  res = new IR(kFilterClause, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void FilterClause::deep_delete() {
  SAFEDELETE(where_expr_);
  delete this;
}

IR *OptFilterClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(filter_clause_);
  res = new IR(kOptFilterClause, OP0(), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptFilterClause, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptFilterClause::deep_delete() {
  SAFEDELETE(filter_clause_);
  delete this;
}

IR *OptWindowClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(window_clause_);
  res = new IR(kOptWindowClause, OP0(), tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptWindowClause, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptWindowClause::deep_delete() {
  SAFEDELETE(window_clause_);
  delete this;
}

IR *WindowClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto tmp = SAFETRANSLATE(windowdefn_list_);
  res = new IR(kWindowClause, OP1("WINDOW"), tmp);
  TRANSLATEEND
}

void WindowClause::deep_delete() {
  SAFEDELETE(windowdefn_list_);
  delete this;
}

IR *WindowDefnList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kWindowDefnList, v_windowdefn_list_, ",");
  TRANSLATEENDNOPUSH
}

void WindowDefnList::deep_delete() {
  SAFEDELETELIST(v_windowdefn_list_);
  delete this;
}

IR *WindowDefn::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto win_name = SAFETRANSLATE(window_name_);
  auto win_ir = SAFETRANSLATE(window_body_);
  res = new IR(kWindowDefn, OP3("", "AS (", ")"), win_name, win_ir);
  TRANSLATEEND
}

void WindowDefn::deep_delete() {
  SAFEDELETE(window_name_);
  SAFEDELETE(window_body_);
  delete this;
}

IR *WindowBody::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto tmp0 = SAFETRANSLATE(opt_base_window_name_);
  auto tmp1 = SAFETRANSLATE(opt_partition_by_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(opt_order_);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);
  auto tmp3 = SAFETRANSLATE(opt_frame_);
  res = new IR(kOptOverClause, OP0(), res, tmp3);
  TRANSLATEEND
}

void WindowBody::deep_delete() {
  SAFEDELETE(opt_base_window_name_);
  SAFEDELETE(opt_partition_by_);
  SAFEDELETE(opt_order_);
  SAFEDELETE(opt_frame_);
  delete this;
}

IR *WindowName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto tmp = SAFETRANSLATE(identifier_);
  res = new IR(kWindowName, OP0(), tmp);
  TRANSLATEEND
}

void WindowName::deep_delete() {
  SAFEDELETE(identifier_);
  delete this;
}

IR *OptBaseWindowName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(identifier_);
  res = new IR(kOptBaseWindowName, OP0(), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptBaseWindowName, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptBaseWindowName::deep_delete() {
  SAFEDELETE(identifier_);
  delete this;
}

IR *OptFrame::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto range_or_row = SAFETRANSLATE(range_or_rows_);
  auto frame_bound = SAFETRANSLATE(frame_bound_);
  auto opt_frame_exclude = SAFETRANSLATE(opt_frame_exclude_);
  res = new IR(kUnknown, OP0(), range_or_row, frame_bound);
  PUSH(res);
  res = new IR(kOptFrame, OP0(), res, opt_frame_exclude);
  CASEEND
  CASESTART(1)
  auto range_or_row = SAFETRANSLATE(range_or_rows_);
  auto frame_bound_s = SAFETRANSLATE(frame_bound_s_);
  auto opt_frame_exclude = SAFETRANSLATE(opt_frame_exclude_);
  res = SAFETRANSLATE(frame_bound_e_);
  res = new IR(kUnknown, OP2("BETWEEN", "AND"), frame_bound_s, res);
  PUSH(res);
  res = new IR(kUnknown, OP0(), range_or_row, res);
  PUSH(res);
  res = new IR(kOptFrame, OP0(), res, opt_frame_exclude);
  CASEEND
  CASESTART(2)
  res = new IR(kOptFrame, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptFrame::deep_delete() {
  SAFEDELETE(range_or_rows_);
  SAFEDELETE(frame_bound_e_);
  SAFEDELETE(frame_bound_s_);
  SAFEDELETE(opt_frame_exclude_);
  delete this;
}

IR *RangeOrRows::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kRangeOrRows, OP1(str_val_));
  TRANSLATEEND
}

void RangeOrRows::deep_delete() { delete this; }

IR *FrameBoundS::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kFrameBoundS, str_val_);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(expr_);
  res = new IR(kFrameBoundS, OPMID(str_val_), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void FrameBoundS::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

IR *FrameBoundE::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kFrameBoundE, str_val_);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(expr_);
  res = new IR(kFrameBoundE, OPMID(str_val_), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void FrameBoundE::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

IR *FrameBound::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kFrameBound, str_val_);
  CASEEND
  CASESTART(1)
  res = SAFETRANSLATE(expr_);
  res = new IR(kFrameBound, OPMID(str_val_), res);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void FrameBound::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

IR *OptFrameExclude::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(frame_exclude_);
  res = new IR(kOptFrameExclude, tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptFrameExclude, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptFrameExclude::deep_delete() {
  SAFEDELETE(frame_exclude_);
  delete this;
}

IR *FrameExclude::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kFrameExclude, str_val_);
  TRANSLATEEND
}

void FrameExclude::deep_delete() { delete this; }

IR *TableOrSubqueryList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kTableOrSubqueryList, v_table_or_subquery_list_, ",");
  TRANSLATEENDNOPUSH
}

void TableOrSubqueryList::deep_delete() {
  SAFEDELETELIST(v_table_or_subquery_list_);
  delete this;
}


// OptTableAlias has three cases
// this function makes sure they are in the second case: AS IDENTIFIER
void ForceTableAlias(OptTableAlias * opt_table_alias_) {

  if (opt_table_alias_->is_existed_ != true) {

    TableAlias *table_alias = new TableAlias();
    table_alias->sub_type_ = CASE0;
    table_alias->alias_id_ = new Identifier("x", id_table_alias_name);

    opt_table_alias_->table_alias_ = table_alias;
    opt_table_alias_->is_existed_ = true;
  }

  opt_table_alias_->sub_type_ = CASE1;

  return;
}

IR *TableOrSubquery::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART

  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(select_statement_);
  ForceTableAlias(opt_table_alias_);
  auto tmp1 = SAFETRANSLATE(opt_table_alias_);
  res = new IR(kTableOrSubquery, OP2("(", ")"), tmp0, tmp1);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(table_or_subquery_list_);
  res = new IR(kTableOrSubquery, OP0(), tmp0);
  CASEEND
  CASESTART(2)
  auto tmp0 = SAFETRANSLATE(table_name_);
  ForceTableAlias(opt_table_alias_);
  auto tmp1 = SAFETRANSLATE(opt_table_alias_);
  res = new IR(kUnknown, OP0(), tmp0, tmp1);
  PUSH(res);
  auto tmp2 = SAFETRANSLATE(opt_index_);
  res = new IR(kTableOrSubquery, OP0(), res, tmp2);
  CASEEND
  CASESTART(3)
  auto tmp0 = SAFETRANSLATE(join_clause_);
  res = new IR(kTableOrSubquery, OP2("(", ")"), tmp0);
  CASEEND

  SWITCHEND

  TRANSLATEEND
}

void TableOrSubquery::deep_delete() {
  SAFEDELETE(select_statement_);
  SAFEDELETE(opt_table_alias_);
  SAFEDELETE(table_or_subquery_list_);
  SAFEDELETE(table_name_);
  SAFEDELETE(opt_index_);
  SAFEDELETE(join_clause_);
  delete this;
}

IR *JoinOp::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kJoinOp, OP1(str_val_));

  TRANSLATEEND
}

IR *OptIndex::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(index_name_);
  res = new IR(kOptIndex, OP1("INDEXED BY"), tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptIndex, string("NOT INDEXED"));
  CASEEND
  CASESTART(2)
  res = new IR(kOptIndex, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

IR *WhereExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(expr_);
  res = new IR(kWhereExpr, OP1("WHERE"), res);

  TRANSLATEEND
}

void WhereExpr::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

IR *EscapeExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(expr_);
  res = new IR(kEscapeExpr, OP1("ESCAPE"), res);

  TRANSLATEEND
}

void EscapeExpr::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

IR *ElseExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(expr_);
  res = new IR(kElseExpr, OP1("ELSE"), res);

  TRANSLATEEND
}

void ElseExpr::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

IR *OnExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = SAFETRANSLATE(expr_);
  res = new IR(kOnExpr, OP1("ON"), res);

  TRANSLATEEND
}

void OnExpr::deep_delete() {
  SAFEDELETE(expr_);
  delete this;
}

void JoinOp::deep_delete() { delete this; }

void OptIndex::deep_delete() {
  SAFEDELETE(index_name_);
  delete this;
}

IR *ReleaseStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  auto tmp = SAFETRANSLATE(savepoint_name_);
  res = new IR(kReleaseStatement, OP1("RELEASE SAVEPOINT"), tmp);
  CASEEND
  CASESTART(1)
  auto tmp = SAFETRANSLATE(savepoint_name_);
  res = new IR(kReleaseStatement, OP1("RELEASE"), tmp);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void ReleaseStatement::deep_delete() {
  SAFEDELETE(savepoint_name_);
  delete this;
}

IR *SavepointStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto tmp = SAFETRANSLATE(savepoint_name_);
  res = new IR(kSavepointStatement, OP1("SAVEPOINT"), tmp);
  TRANSLATEEND
}

void SavepointStatement::deep_delete() {
  SAFEDELETE(savepoint_name_);
  delete this;
}

void AlterStatement::deep_delete() {
  SAFEDELETE(table_name1_);
  SAFEDELETE(table_name2_);
  SAFEDELETE(column_def_);
  SAFEDELETE(opt_column_);
  SAFEDELETE(column_name1_);
  SAFEDELETE(column_name2_);
  delete this;
}

IR *AlterStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(table_name1_);
  auto tmp1 = SAFETRANSLATE(table_name2_);
  res = new IR(kAlterStatement, OP2("ALTER TABLE", "RENAME TO"), tmp0, tmp1);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(table_name1_);
  auto tmp1 = SAFETRANSLATE(opt_column_);
  auto tmp2 = SAFETRANSLATE(column_name1_);
  auto tmp3 = SAFETRANSLATE(column_name2_);
  res = new IR(kUnknown, OP2("ALTER TABLE", "RENAME"), tmp0, tmp1);
  PUSH(res);
  res = new IR(kUnknown, OP0(), res, tmp2);
  PUSH(res);
  res = new IR(kAlterStatement, OPMID("TO"), res, tmp3);
  CASEEND
  CASESTART(2)
  auto tmp0 = SAFETRANSLATE(table_name1_);
  auto tmp1 = SAFETRANSLATE(opt_column_);
  auto tmp2 = SAFETRANSLATE(column_def_);
  res = new IR(kUnknown, OP2("ALTER TABLE", "ADD"), tmp0, tmp1);
  PUSH(res);
  res = new IR(kAlterStatement, OP0(), res, tmp2);
  CASEEND
  CASESTART(3)
  auto tmp0 = SAFETRANSLATE(table_name1_);
  auto tmp1 = SAFETRANSLATE(opt_column_);
  auto tmp2 = SAFETRANSLATE(column_name1_);
  res = new IR(kUnknown, OP2("ALTER TABLE", "DROP"), tmp0, tmp1);
  PUSH(res);
  res = new IR(kAlterStatement, OP0(), res, tmp2);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptColumn::deep_delete() { delete this; }

IR *OptColumn::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptColumn, OP1(str_val_));

  TRANSLATEEND
}

void VacuumStatement::deep_delete() {
  SAFEDELETE(opt_schema_name_);
  SAFEDELETE(file_path_);

  delete (this);
}

IR *VacuumStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(opt_schema_name_);
  auto tmp1 = SAFETRANSLATE(file_path_);
  res = new IR(kVacuumStatement, OP2("VACUUM", "INTO"), tmp0, tmp1);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(opt_schema_name_);
  res = new IR(kVacuumStatement, OP1("VACUUM"), tmp0);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptSchemaName::deep_delete() {
  SAFEDELETE(schema_name_);

  delete this;
}

IR *OptSchemaName::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(schema_name_);
  res = new IR(kOptSchemaName, OP0(), tmp0);
  CASEEND
  CASESTART(1)
  res = new IR(kOptSchemaName, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void RollbackStatement::deep_delete() {
  SAFEDELETE(opt_transaction_);
  SAFEDELETE(opt_to_savepoint_);

  delete this;
}

IR *RollbackStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(opt_transaction_);
  auto tmp1 = SAFETRANSLATE(opt_to_savepoint_);
  res = new IR(kRollbackStatement, OP1("ROLLBACK"), tmp0, tmp1);

  TRANSLATEEND
}

void OptTransaction::deep_delete() { delete this; }

IR *OptTransaction::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kOptTransaction, OP1(str_val_));
  TRANSLATEEND
}

void OptToSavepoint::deep_delete() {
  SAFEDELETE(savepoint_name_);

  delete this;
}

IR *OptToSavepoint::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(savepoint_name_);
  res = new IR(kOptToSavepoint, OP1("TO"), tmp0);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(savepoint_name_);
  res = new IR(kOptToSavepoint, OP1("TO SAVEPOINT"), tmp0);
  CASEEND
  CASESTART(2)
  res = new IR(kOptToSavepoint, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void BeginStatement::deep_delete() {
  SAFEDELETE(opt_transaction_);

  delete this;
}

IR *BeginStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(opt_transaction_);
  res = new IR(kBeginStatement, OP1("BEGIN"), tmp0);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(opt_transaction_);
  res = new IR(kBeginStatement, OP1("BEGIN DEFFERED"), tmp0);
  CASEEND
  CASESTART(2)
  auto tmp0 = SAFETRANSLATE(opt_transaction_);
  res = new IR(kBeginStatement, OP1("BEGIN IMEDIATE"), tmp0);
  CASEEND
  CASESTART(3)
  auto tmp0 = SAFETRANSLATE(opt_transaction_);
  res = new IR(kBeginStatement, OP1("BEGIN EXCLUSIVE"), tmp0);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void CommitStatement::deep_delete() {
  SAFEDELETE(opt_transaction_);

  delete this;
}

IR *CommitStatement::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(opt_transaction_);
  res = new IR(kCommitStatement, OP1("COMMIT"), tmp0);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(opt_transaction_);
  res = new IR(kCommitStatement, OP1("END"), tmp0);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *UpsertItem::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)

  auto tmp0 = SAFETRANSLATE(opt_conflict_target_);
  res = new IR(kUpsertItem, OP2("ON CONFLICT", "DO NOTHING"), tmp0);

  CASEEND
  CASESTART(1)

  auto tmp0 = SAFETRANSLATE(opt_conflict_target_);
  auto tmp1 = SAFETRANSLATE(assign_list_);
  auto tmp2 = SAFETRANSLATE(opt_where_);

  res = new IR(kUnknown, OP2("ON CONFLICT", "DO UPDATE SET"), tmp0, tmp1);
  PUSH(res);
  res = new IR(kUpsertItem, OP0(), res, tmp2);

  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void UpsertItem::deep_delete() {
  SAFEDELETE(opt_conflict_target_);
  SAFEDELETE(assign_list_);
  SAFEDELETE(opt_where_);
  delete this;
}

void UpsertClause::deep_delete() {
  SAFEDELETELIST(v_upsert_item_list_);
  delete this;
}

IR *UpsertClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kUpsertClause, v_upsert_item_list_, " ");
  TRANSLATEENDNOPUSH
}

void IndexedColumnList::deep_delete() {
  SAFEDELETELIST(v_indexed_column_list_);

  delete this;
}

IR *IndexedColumnList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kIndexedColumnList, v_indexed_column_list_, ",")
  TRANSLATEENDNOPUSH
}

void IndexedColumn::deep_delete() {
  SAFEDELETE(opt_collate_);
  SAFEDELETE(expr_);
  SAFEDELETE(opt_order_type_);

  delete this;
}

IR *IndexedColumn::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp0 = SAFETRANSLATE(expr_);
  auto tmp1 = SAFETRANSLATE(opt_collate_);
  auto tmp2 = SAFETRANSLATE(opt_order_type_);
  res = new IR(kIndexedColumn, OP0(), tmp0, tmp1);
  PUSH(res);
  res = new IR(kIndexedColumn, OP0(), res, tmp2);

  TRANSLATEEND
}

IR *Collate::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  auto tmp0 = SAFETRANSLATE(collate_name_);
  res = new IR(kCollate, OP1("COLLATE"), tmp0);
  TRANSLATEEND
}

void Collate::deep_delete() {
  SAFEDELETE(collate_name_);
  delete this;
}

IR *OptCollate::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(collate_);
  res = new IR(kOptCollate, OP0(), tmp0);
  CASEEND
  CASESTART(1)
  res = new IR(kOptCollate, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void OptCollate::deep_delete() {
  SAFEDELETE(collate_);
  delete this;
}

void AssignList::deep_delete() {
  SAFEDELETELIST(v_assign_list_);

  delete this;
}

IR *AssignList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kAssignList, v_assign_list_, ",");
  TRANSLATEENDNOPUSH
}

IR *ExistsOrNot::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kExistsOrNot, OP1(str_val_));
  TRANSLATEEND
}

void ExistsOrNot::deep_delete() { delete this; }

IR *NullOfExpr::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  res = new IR(kNullOfExpr, OP1(str_val_));
  TRANSLATEEND
}

void NullOfExpr::deep_delete() { delete this; }

IR *OptOrderOfNull::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  res = new IR(kOptOrderOfNull, OP1(str_val_));

  TRANSLATEEND
}

void OptOrderOfNull::deep_delete() { delete this; }

void AssignClause::deep_delete() {
  SAFEDELETE(expr_);
  SAFEDELETE(column_name_list_);
  SAFEDELETE(column_name_);

  delete this;
}

IR *AssignClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART

  CASESTART(0)
  auto tmp0 = SAFETRANSLATE(column_name_);
  auto tmp1 = SAFETRANSLATE(expr_);
  res = new IR(kAssignClause, OPMID("="), tmp0, tmp1);
  CASEEND
  CASESTART(1)
  auto tmp0 = SAFETRANSLATE(column_name_list_);
  auto tmp1 = SAFETRANSLATE(expr_);
  res = new IR(kAssignClause, OP2("(", ") ="), tmp0, tmp1);
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

void ColumnNameList::deep_delete() {
  SAFEDELETELIST(v_column_name_list_);

  delete this;
}

IR *ColumnNameList::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  TRANSLATELIST(kColumnNameList, v_column_name_list_, ",");
  TRANSLATEENDNOPUSH
}

IR *PartitionBy::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  auto tmp = SAFETRANSLATE(expr_list_);
  res = new IR(kPartitionBy, OP1("PARTITION BY"), tmp);

  TRANSLATEEND
}

void PartitionBy::deep_delete() {
  SAFEDELETE(expr_list_);
  delete this;
}

IR *OptPartitionBy::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART

  CASESTART(0)
  auto tmp = SAFETRANSLATE(partition_by_);
  res = new IR(kOptPartitionBy, OP0(), tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptPartitionBy, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptPartitionBy::deep_delete() {
  SAFEDELETE(partition_by_);
  delete this;
}

void OptUpsertClause::deep_delete() {
  SAFEDELETE(upsert_clause_);

  delete this;
}

IR *OptUpsertClause::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART

  SWITCHSTART
  CASESTART(0)
  res = SAFETRANSLATE(upsert_clause_);
  res = new IR(kOptUpsertClause, OP0(), res);
  CASEEND
  CASESTART(1)
  res = new IR(kOptUpsertClause, string(""));
  CASEEND
  SWITCHEND

  TRANSLATEEND
}

IR *OptNot::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kOptNot, string("NOT"));
  CASEEND
  CASESTART(1)
  res = new IR(kOptNot, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptNot::deep_delete() { delete this; }

IR *RaiseFunction::translate(vector<IR *> &v_ir_collector) {
  TRANSLATESTART
  SWITCHSTART
  CASESTART(0)
  res = new IR(kRaiseFunction, string("RAISE ( IGNORE )"));
  CASEEND
  CASESTART(1)
  auto tmp = SAFETRANSLATE(error_msg_);
  res = new IR(kOptNot, OP2(to_raise_, ")"), tmp);
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void RaiseFunction::deep_delete() {
  SAFEDELETE(error_msg_);
  delete this;
}

IR *ConflictTarget::translate(vector<IR *> &v_ir_collector) {

  TRANSLATESTART
  auto tmp0 = SAFETRANSLATE(indexed_column_list_);
  auto tmp1 = SAFETRANSLATE(opt_where_);
  res = new IR(kConflictTarget, OP2("(", ")"), tmp0, tmp1);
  TRANSLATEEND
}

void ConflictTarget::deep_delete() {

  SAFEDELETE(indexed_column_list_);
  SAFEDELETE(opt_where_);
  delete this;
}

IR *OptConflictTarget::translate(vector<IR *> &v_ir_collector) {

  TRANSLATESTART
  SWITCHSTART

  CASESTART(0)
  auto tmp = SAFETRANSLATE(conflict_target_);
  res = new IR(kOptConflictTarget, OP0(), tmp);
  CASEEND
  CASESTART(1)
  res = new IR(kOptConflictTarget, string(""));
  CASEEND
  SWITCHEND
  TRANSLATEEND
}

void OptConflictTarget::deep_delete() {

  SAFEDELETE(conflict_target_);
  delete this;
}

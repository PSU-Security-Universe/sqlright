#include "../include/ast.h"
#include "../include/define.h"
#include "../include/utils.h"
#include <cassert>
#include <cstdio>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <vector>
#include <string.h>

static string s_table_name;

string get_string_by_ir_type(IRTYPE type) {

#define DECLARE_CASE(classname) \
  if (type == classname)     \
    return #classname;

  ALLTYPE(DECLARE_CASE);
#undef DECLARE_CASE

  return "";
}

string get_string_by_option_type(RelOptionType type) {
  switch (type) {
    case Unknown:
      return "option_unknown";
    case StorageParameters:
      return "option_storageParameters";
    case SetConfigurationOptions:
      return "option_setConfigurationOptions";
  }
  return "option_unknown";
}

string get_string_by_data_type(DATATYPE type) {

  switch (type) {
  case kDataWhatever:
    return "data_whatever";
  case kDataTableName:
    return "data_tableName";
  case kDataColumnName:
    return "data_columnName";
  case kDataViewName:
    return "data_viewName";
  case kDataFunctionName:
    return "data_functionName";
  case kDataPragmaKey:
    return "data_pragmaKey";
  case kDataPragmaValue:
    return "data_pragmaValue";
  case kDataTableSpaceName:
    return "data_tableSpaceName";
  case kDataSequenceName:
    return "data_SequenceName";
  case kDataExtensionName:
    return "data_extensionName";
  case kDataRoleName:
    return "data_roleName";
  case kDataSchemaName:
    return "data_SchemaName";
  case kDataDatabase:
    return "data_dataDatabase";
  case kDataTriggerName:
    return "data_triggername";
  case kDataWindowName:
    return "data_windowName";
  case kDataTriggerFunction:
    return "data_triggerFunction";
  case kDataDomainName:
    return "data_domainName";
  case kDataAliasName:
    return "data_aliasName";
  case kDataLiteral:
    return "data_literal";
  case kDataIndexName:
    return "data_indexName";
  case kDataGroupName:
    return "data_groupName";
  case kDataUserName:
    return "data_UserName";
  case kDataDatabaseName:
    return "data_DatabaseName";
  case kDataSystemName:
    return "data_SystemName";
  case kDataConversionName:
    return "data_ConversionName";
  case kDataAggregateArguments:
    return "data_aggregateArguments";
  case kDataNonReservedWord:
    return "data_nonReservedWord";
  case kDataFixLater:
    return "data_fixLater";
  case kDataConstraintName:
    return "data_constraintName";
  case kDataRelOption:
    return "data_relOption";
  case kDataGenericType:
    return "data_genericType";
  case kDataTableNameFollow:
    return "data_tableNameFollow";
  case kDataColumnNameFollow:
    return "data_columnNameFollow";
  case kDataCollate:
    return "data_collate";
  case kDataStatisticName:
    return "data_statisticName";
  case kDataForeignTableName:
    return "data_foreignTableName";
  case kDataAliasTableName:
    return "data_aliasTableName";
  default:
    return "data_unknown";
  }
}

string get_string_by_data_flag(DATAFLAG flag_type_) {

  switch (flag_type_) {
  case kUse:
    return "kUse";
  case kMapToClosestOne:
    return "kMapToClosestOne";
  case kNoSplit:
    return "kNoSplit";
  case kGlobal:
    return "kGlobal";
  case kReplace:
    return "kReplace";
  case kUndefine:
    return "kUndefine";
  case kAlias:
    return "kAlias";
  case kMapToAll:
    return "kMapToAll";
  case kDefine:
    return "kDefine";
  default:
    return "kUnknown";
  }
}

string get_string_by_datatype(DATATYPE tt) {
#define DECLARE_CASE(datatypename)                                             \
  if (tt == k##datatypename)                                                   \
    return string(#datatypename);

  ALLDATATYPE(DECLARE_CASE);

#undef DECLARE_CASE
  return string("");
}

DATATYPE get_datatype_by_string(string s) {
#define DECLARE_CASE(datatypename)                                             \
  if (s == #datatypename)                                                      \
    return k##datatypename;

  ALLDATATYPE(DECLARE_CASE);

#undef DECLARE_CASE
  return kDataWhatever;
}

void deep_delete(IR *root) {
  if (root->left_)
    deep_delete(root->left_);
  if (root->right_)
    deep_delete(root->right_);

  if (root->op_)
    delete root->op_;

  delete root;
}

IR *deep_copy(const IR *root) {
  IR *left = NULL, *right = NULL, *copy_res;

  if (root->left_)
    left = deep_copy(root->left_);
  if (root->right_)
    right = deep_copy(root->right_);

  copy_res = new IR(root, left, right);


  return copy_res;
}

string IR::to_string() {
  string res = "";
  to_string_core(res);
  trim_string(res);
  return res;
}

/* Very frequently called. Must be very fast. */
void IR::to_string_core(string& res) {

  if (data_type_ == kDataCollate) {
    res += "\"" + str_val_ + "\"";
    return;
  }

  switch (type_) {
  case kIntLiteral:
    if (str_val_ != "") {
      res += str_val_;
    } else {
      res += std::to_string(int_val_);
    }
    return;
  case kFloatLiteral:
    if (str_val_ != "") {
      res += str_val_;
    } else {
      res += std::to_string(float_val_);
    }
    return;
  case kBoolLiteral:
    if (str_val_ != "") {
      res += str_val_;
    }  else {
      if (bool_val_) {
        res += " TRUE ";
      } else {
        res += " FALSE ";
      }
    }
    return;
  case kIdentifier:
    if (str_val_ != "") {
      res += str_val_;
    }
    return;
  case kStringLiteral:
    res += "'" + str_val_ + "'";
    return;
  }


  // if (type_ == kFuncArgs && str_val_ != "") {
  //   res += str_val_;
  //   return;
  // }

  /* If we have str_val setup, directly return the str_val_; */
  if (str_val_ != "") {
    res += str_val_;
    return;
  }

  if (op_) {
    res += op_->prefix_;
    res += " ";
  }

  if (left_) {
    left_->to_string_core(res);
    res += " ";
  }

  if (op_) {
    res += op_->middle_;
    res += + " ";
  }

  if (right_) {
    right_->to_string_core(res);
    res += " ";
  }

  if (op_)
    res += op_->suffix_;

  return;
}

bool IR::detach_node(IR *node) { return swap_node(node, NULL); }

bool IR::swap_node(IR *old_node, IR *new_node) {
  if (old_node == NULL)
    return false;

  IR *parent = this->locate_parent(old_node);

  if (parent == NULL)
    return false;
  else if (parent->left_ == old_node)
    parent->update_left(new_node);
  else if (parent->right_ == old_node)
    parent->update_right(new_node);
  else
    return false;

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

IR *IR::get_parent() { return this->parent_; }

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

  if (this->op_)
    op = OP3(this->op_->prefix_, this->op_->middle_, this->op_->suffix_);

  copy_res = new IR(this->type_, op, left, right, this->float_val_,
                    this->str_val_, this->name_, this->mutated_times_);
  copy_res->data_type_ = this->data_type_;
  copy_res->data_flag_ = this->data_flag_;
  copy_res->option_type_ = this->option_type_;

  return copy_res;
}

const char* IR::get_prefix(){
  if (op_) {
    return op_->prefix_;
  }
  return "";
}

const char* IR::get_middle() {
  if (op_) {
    return op_->middle_;
  }
  return "";
}

const char* IR::get_suffix() {
  if (op_) {
    return op_->suffix_;
  }
  return "";
}

string IR::get_str_val() {
  return str_val_;
}

bool IR::is_empty() {
    if (op_) {
        if (strcmp(op_->prefix_, "") || strcmp(op_->middle_, "") || strcmp(op_->suffix_, "")) {
            return false;
        }
    }
    if (str_val_ != "") {
        return false;
    }
    if (left_ || right_) {
        return false;
    }
    return true;
}

void IR::set_str_val(string in) {
  str_val_ = in;
}

IRTYPE IR::get_ir_type() {
  return type_;
}

DATATYPE IR::get_data_type() {
  return data_type_;
}

DATAFLAG IR::get_data_flag() {
  return data_flag_;
}

IR* IR::get_left() {
  return left_;
}

IR* IR::get_right() {
  return right_;
}

void IR::set_ir_type(IRTYPE type) {
  this->type_ = type;
}

void IR::set_data_type(DATATYPE data_type) {
  this->data_type_ = data_type;
}

void IR::set_data_flag(DATAFLAG data_flag) {
  this->data_flag_ = data_flag;
}

bool IR::set_qualified_name_type(DATATYPE data_type, DATAFLAG data_flag) {
  // cerr << get_string_by_ir_type(this->get_parent()->get_ir_type()) << "\n";
  assert(this->get_ir_type() == kQualifiedName);
  assert(this->get_left() && this->get_left()->get_ir_type() == kIdentifier);

  /* Dirty fix: if kQualifiedName contains right sub-node, do not assign the input type,
   * treat it as kDataTableNameFollow
   * */
  if (get_right()) {
    IR* iden = this->get_left();
    iden->set_data_type(kDataTableNameFollow);
    iden->set_data_flag(kUse);
    return true;
  }

  IR* iden = this->get_left();
  iden->set_data_type(data_type);
  iden->set_data_flag(data_flag);

  return true;
}

bool IR::set_qualified_name_list_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(this->get_ir_type() == kQualifiedNameList);

  IR* qualified_name_ir = NULL;
  if (this->get_right()) {
    qualified_name_ir = this->get_right();
  } else {
    qualified_name_ir = this->get_left();
  }
  IR* iden = qualified_name_ir->get_left();
  iden->set_iden_type(data_type, data_flag);

  if (this->get_right()) {
    return this->get_left()->set_qualified_name_list_type(data_type, data_flag);
  }

  return true;
}

bool IR::set_type(DATATYPE data_type, DATAFLAG data_flag) {

  /* Set type regardless of the node type. Do not use this unless necessary. */
  this->set_data_type(data_type);
  this->set_data_flag(data_flag);

  return true;
}


bool IR::set_iden_type(DATATYPE data_type, DATAFLAG data_flag) {
  // cerr << get_string_by_ir_type(this->get_parent()->get_ir_type()) << "\n";
  assert(this->get_ir_type() == kIdentifier);

  this->set_data_type(data_type);
  this->set_data_flag(data_flag);

  return true;
}

bool IR::set_reloption_elem_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(this->get_ir_type() == kReloptionElem);

  this->set_data_type(data_type);
  this->set_data_flag(data_flag);

  return true;
}

bool IR::set_any_name_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(this->get_ir_type() == kAnyName);

  IR* iden = this->get_left();

  iden->set_data_type(data_type);
  iden->set_data_flag(data_flag);

  return true;
}

bool IR::set_any_name_list_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(this->get_ir_type() == kAnyNameList);

  IR* anyname_ir = NULL;
  if (this->get_right()) {
    anyname_ir = this->get_right();
  } else {
    anyname_ir = this->get_left();
  }
  IR* iden = anyname_ir->get_left();
  iden->set_iden_type(data_type, data_flag);

  if (this->get_right()) {
    return this->get_left()->set_any_name_list_type(data_type, data_flag);
  }

  return true;
}

bool IR::set_opt_columnlist_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(this->get_ir_type() == kOptColumnList);

  IR* columnlist_ir = this->get_left();
  if (columnlist_ir) {
    return columnlist_ir->set_columnlist_type(data_type, data_flag);
  }
  return true;
}

bool IR::set_columnlist_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(this->get_ir_type() == kColumnList);

  IR* column_elem_ir = NULL;
  if (this->get_right()) {
    column_elem_ir = this->get_right();
  } else {
    column_elem_ir = this->get_left();
  }
  IR* iden = column_elem_ir->get_left();
  iden->set_iden_type(data_type, data_flag);

  /* This is a list, iterate all the columnElem possible.  */
  if (this->get_right()) {
    return this->get_left()->set_columnlist_type(data_type, data_flag);
  }

  return true;

}


bool IR::set_insert_columnlist_type(DATATYPE data_type, DATAFLAG data_flag) {

  assert(this->get_ir_type() == kInsertColumnList);

  IR* insert_column_elem_ir = NULL;
  if (this->get_right()) {
    insert_column_elem_ir = this->get_right();
  } else {
    insert_column_elem_ir = this->get_left();
  }
  IR* iden = insert_column_elem_ir->get_left();
  iden->set_iden_type(data_type, data_flag);

  /* This is a list, iterate all the columnElem possible.  */
  if (this->get_right()) {
    return this->get_left()->set_insert_columnlist_type(data_type, data_flag);
  }

  return true;

}

bool IR::set_rolelist_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(this->get_ir_type() == kRoleList);

  IR* iden = NULL;
  if (this->get_right()) {
    iden = this->get_right();
  } else {
    iden = this->get_left();
  }
  iden->set_iden_type(data_type, data_flag);

  /* This is a list, iterate all the columnElem possible.  */
  if (this->get_right()) {
    return this->get_left()->set_rolelist_type(data_type, data_flag);
  }

  return true;

}

bool IR::add_drop_is_add(){
  assert(this->get_ir_type() == kAddDrop);

  if(!strcmp(this->get_prefix(), "ADD")) {
    return true;
  } else {
    return false;
  }
}

int IR::get_object_type_any_name() {
  assert(this->get_ir_type() == kObjectTypeAnyName);

  if (!strncmp(this->get_prefix(), "TABLE", 5)) return 0;
  else if (!strncmp(this->get_prefix(), "SEQUENCE", 8)) return 1;
  else if (!strncmp(this->get_prefix(), "VIEW", 4)) return 2;
  else if (!strncmp(this->get_prefix(), "MATERIALIZED VIEW", 17)) return 3;
  else if (!strncmp(this->get_prefix(), "INDEX", 5)) return 4;
  else if (!strncmp(this->get_prefix(), "FOREIGN TABLE", 13)) return 5;
  else if (!strncmp(this->get_prefix(), "COLLATION", 9)) return 6;
  else if (!strncmp(this->get_prefix(), "CONVERSION", 10)) return 7;
  else if (!strncmp(this->get_prefix(), "STATISTICS", 10)) return 8;
  else if (!strncmp(this->get_prefix(), "TEXT SEARCH PARSER", 18)) return 9;
  else if (!strncmp(this->get_prefix(), "TEXT SEARCH DICTIONARY", 22)) return 10;
  else if (!strncmp(this->get_prefix(), "TEXT SEARCH TEMPLATE", 20)) return 11;
  else if (!strncmp(this->get_prefix(), "TEXT SEARCH CONFIGURATION", 25)) return 12;
  else return -1;

}

int IR::get_object_type() {
  assert(this->get_ir_type() == kObjectTypeName);

  if (!strncmp(this->get_prefix(), "DATABASE", 5)) return 0;
  else if (!strncmp(this->get_prefix(), "ROLE", 8)) return 1;
  else if (!strncmp(this->get_prefix(), "SUBSCRIPTION", 4)) return 2;
  else if (!strncmp(this->get_prefix(), "TABLESPACE", 17)) return 3;
  else return -1;

}

int IR::get_reindex_target_type() {
  assert(this->get_ir_type() == kReindexTargetType ||
        this->get_ir_type() == kReindexTargetMultitable);

  if (!strncmp(this->get_prefix(), "INDEX", 5)) return 0;
  else if (!strncmp(this->get_prefix(), "TABLE", 5)) return 1;
  else if (!strncmp(this->get_prefix(), "SCHEMA", 6)) return 2;
  else if (!strncmp(this->get_prefix(), "SYSTEM", 6)) return 3;
  else if (!strncmp(this->get_prefix(), "DATABASE", 8)) return 4;
  else return -1;

}

bool IR::target_el_is_exist_alias() {
  assert(get_ir_type() == kTargetEl);

  if(is_empty()) return false;
  if(!op_) return false;

  if(!strcmp(get_middle(), "AS")) return true;

  return false;
 
}
bool IR::target_el_set_alias(string in) {
  assert(target_el_is_exist_alias());

  IR* iden = get_right();
  iden->set_str_val(string(in));

  return true;
}

bool IR::func_name_set_str(string in) {
  assert(get_ir_type() == kFuncName);

  IR* iden = get_left();
  iden->set_str_val(in);

  return true;
}

bool IR::replace_op(IROperator* op_in) {
  if (this->op_) {
    delete this->op_;
  }

  this->op_ = op_in;

  return true;

}

COLTYPE IR::typename_ir_get_type() {
  assert(get_ir_type() == kTypename);

  IR* simple_typename_ir = get_left();
  if ( !simple_typename_ir || simple_typename_ir->get_ir_type() != kSimpleTypename) {
    return COLTYPE::UNKNOWN_T;
  }

  IR* sub_typename_ir = simple_typename_ir->get_left();
  if (!simple_typename_ir) {
    return COLTYPE::UNKNOWN_T;
  }

  if (sub_typename_ir->get_ir_type() == kNumeric) {
    string prefix_str = sub_typename_ir->get_prefix();
    // cerr << "DEBUG:: Prefix string: " << prefix_str << "\n\n\n";
    if (findStringIn(prefix_str, "INT")) {
      return COLTYPE::INT_T;
    } else if (findStringIn(prefix_str, "BOOL")) {
      return COLTYPE::BOOLEAN_T;
    }
    else if (
      findStringIn(prefix_str, "REAL") ||
      findStringIn(prefix_str, "DOUBLE") ||
      findStringIn(prefix_str, "DEC") ||
      findStringIn(prefix_str, "FLOAT")
    ) {
      return COLTYPE::FLOAT_T;
    } else {
      return COLTYPE::UNKNOWN_T;
    }
  } /* Finished for Numeric type */

  /* Support the custom type later. Right now, treat all other types
   * except Numeric as String type.
   * */
  return COLTYPE::STRING_T;


}

RelOptionType IR::get_rel_option_type() {
  return this->option_type_;
}

bool IR::set_rel_option_type(RelOptionType type) {
  this->option_type_ = type;
  return true;
}

bool IR::set_generic_set_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(this->get_ir_type() == kGenericSet);

  this->data_type_ = data_type;
  this->data_flag_ = data_flag;

  return true;

}

bool IR::set_opt_name_list_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(get_ir_type() == kOptNameList);

  if (!get_left()) return false;

  IR* name_list_ir = get_left();

  return name_list_ir->set_name_list_type(data_type, data_flag);

}

bool IR::set_name_list_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(get_ir_type() == kNameList);

  if (get_right()) {
    /* This is not the end of the name_list. Fix thte current one and iterate it */
    IR* name_ir = get_right();
    IR* next_name_list_ir = get_left();
    return next_name_list_ir->set_name_list_type(data_type, data_flag) &&
      name_ir->set_iden_type(data_type, data_flag);
;
  } else {
    /* This is the last name list. Set it and return */
    IR* name_ir = get_left();
    return name_ir->set_iden_type(data_type, data_flag);
  }
}

bool IR::set_opt_reloptions_option_type(RelOptionType type) {
  assert(get_ir_type() == kOptReloptions);

  if (!get_left()) return false;

  IR* reloptions_ir = get_left();

  return reloptions_ir->set_reloptions_option_type(type);
}

bool IR::set_reloptions_option_type(RelOptionType type) {
  assert(get_ir_type() == kReloptions);

  if (!get_left()) return false;

  IR* reloptions_list_ir = get_left();

  return reloptions_list_ir->set_reloption_list_option_type(type);
}

bool IR::set_reloption_list_option_type(RelOptionType type) {
  assert(get_ir_type() == kReloptionList);

  if (get_right()) {
    /* This is not the end of the list. Fix thte current one and iterate it */
    IR* reloption_elem_ir = get_right();
    IR* next_reloption_list_ir = get_left();
    return next_reloption_list_ir->set_reloption_list_option_type(type) &&
      reloption_elem_ir->set_reloption_elem_option_type(type);
;
  } else {
    /* This is the last list. Set it and return */
    IR* reloption_elem_ir= get_left();
    return reloption_elem_ir->set_reloption_elem_option_type(type);
  }
}

bool IR::set_reloption_elem_option_type(RelOptionType type) {
  assert(get_ir_type() == kReloptionElem);
  return set_rel_option_type(type);
}

bool IR::set_cluster_index_specification_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(get_ir_type() == kClusterIndexSpecification);

  if (!get_left()) return false;

  IR* iden = get_left();
  return iden->set_iden_type(data_type, data_flag);
}

bool IR::set_relation_expr_type(DATATYPE data_type, DATAFLAG data_flag) {
  assert(get_ir_type() == kRelationExpr);

  if (!get_left()) return false;

  IR* qualified_name = get_left();

  return qualified_name->set_qualified_name_type(data_type, data_flag);
}

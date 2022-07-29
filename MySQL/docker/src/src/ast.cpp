#include "../include/ast.h"
#include "../include/utils.h"
#include <cassert>

 
static string s_table_name;

string get_string_by_ir_type(IRTYPE type) {
#define DECLARE_CASE(classname)                 \
  if (type == classname)     \
    return string(#classname);

  ALLTYPE(DECLARE_CASE);
#undef DECLARE_CASE

  return "";
}

string get_string_by_data_type(DATATYPE tt){
    #define DECLARE_CASE(datatypename) \
    if(tt == k##datatypename) return string(#datatypename);

    ALLDATATYPE(DECLARE_CASE);

    #undef DECLARE_CASE
    return string("");
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
  case kUseDefine:
    return "kUseDefine";
  default:
    return "kUnknown";
  }
}

DATATYPE get_datatype_by_string(string s){
    #define DECLARE_CASE(datatypename) \
    if(s == #datatypename) return k##datatypename;

    ALLDATATYPE(DECLARE_CASE);

    #undef DECLARE_CASE
    return kDataWhatever;
}

void deep_delete(IR * root){
    if(root->left_) deep_delete(root->left_);
    if(root->right_) deep_delete(root->right_);
    
    if(root->op_) delete root->op_;

    delete root;
}

// IR* deep_copy(const IR* const root) {

//   IR *left = NULL, *right = NULL, *copy_res;
//   IROperator *op = NULL;

//   if (root->left_)
//     left = root->left_->deep_copy();
//   if (root->right_)
//     right = root->right_->deep_copy();

//   if (root->op_)
//     op = OP3(root->op_->prefix_, root->op_->middle_, root->op_->suffix_);

//   copy_res = new IR(root->type_, op, left, right, root->float_val_,
//                     root->str_val_, root->name_, root->mutated_times_, 0, kFlagUnknown);
//   copy_res->data_type_ = root->data_type_;
//   copy_res->data_flag_ = root->data_flag_;

//   return copy_res;
// }


// IR *IR::deep_copy() {

//   IR *left = NULL, *right = NULL, *copy_res;
//   IROperator *op = NULL;

//   if (this->left_)
//     left = this->left_->deep_copy();
//   if (this->right_)
//     right = this->right_->deep_copy();

//   if (this->op_)
//     op = OP3(this->op_->prefix_, this->op_->middle_, this->op_->suffix_);

//   copy_res = new IR(this->type_, op, left, right, this->float_val_,
//                     this->str_val_, this->name_, this->mutated_times_, 0, kFlagUnknown);
//   copy_res->data_type_ = this->data_type_;
//   copy_res->data_flag_ = this->data_flag_;

//   return copy_res;
// }

// void IR::drop() {
//   if (this->op_)
//     delete this->op_;
//   delete this;
// }


// void IR::deep_drop() {
//   if (this->left_)
//     this->left_->deep_drop();

//   if (this->right_)
//     this->right_->deep_drop();

//   this->drop();
// }

// string IR::to_string(){
//     auto res = to_string_core();
//     trim_string(res);
//     return res;
// }

// string IR::to_string_core(){
//     //cout << get_string_by_nodetype(this->type_) << endl;
// //     switch(type_){
// // 	case kIntLiteral: return std::to_string(int_val_);
// // 	case kFloatLiteral: return std::to_string(float_val_);
// // 	case kIdentifier: return str_val_;
// // 	case kStringLiteral: return str_val_;

// // }

//     string res;
    
//     if( op_!= NULL ){
//         //if(op_->prefix_ == NULL)
//             ///cout << "FUCK NULL prefix" << endl;
//          //cout << "OP_Prex: " << op_->prefix_ << endl;
//         res += op_->prefix_ + " ";
//     }
//      //cout << "OP_1_" << op_ << endl;
//     if(left_ != NULL)
//         //res += left_->to_string() + " ";
//         res += left_->to_string_core() + " ";
//     // cout << "OP_2_" << op_ << endl;
//     if( op_!= NULL)
//         res += op_->middle_ + " ";
//      //cout << "OP_3_" << op_ << endl;
//     if(right_ != NULL)
//         //res += right_->to_string() + " ";
//         res += right_->to_string_core() + " ";
//      //cout << "OP_4_" << op_ << endl;
//     if(op_!= NULL)
//         res += op_->suffix_;
    
//     //cout << "FUCK" << endl;
//     //cout << "RETURN" << endl;
//     return res;
// }

#ifndef __AST_H__
#define __AST_H__
#include <vector>
#include <string>
#include "sql/sql_ir_define.h"
#include <iostream>
using namespace std;


#define GEN_NAME() \
    name_ = gen_id_name();


static unsigned long g_id_counter;

static inline void reset_id_counter(){
    g_id_counter = 0;
}

static string gen_id_name() { return "v" + to_string(g_id_counter++); }
static string gen_view_name() {return "view" + to_string(g_id_counter++);}
static string gen_column_name() {return "c" + to_string(g_id_counter++); }
static string gen_index_name() {return "i" + to_string(g_id_counter++); }
static string gen_alias_name() { return "a" + to_string(g_id_counter++); }
static string gen_statistic_name() {return "stat" + to_string(g_id_counter++);}
static string gen_sequence_name() {return "seq" + to_string(g_id_counter++);}

enum UnionType{
    kUnionUnknown = 0,
    kUnionString = 1,
    kUnionFloat,
    kUnionInt,
    kUnionLong,
    kUnionBool,
};

#define isUse(a) ((a) & kUse)
#define isMapToClosestOne(a) ((a) & kMapToClosestOne)
#define isNoSplit(a) ((a) & kNoSplit)
#define isGlobal(a) ((a) & kGlobal)
#define isReplace(a) ((a) & kReplace)
#define isUndefine(a) ((a) & kUndefine)
#define isAlias(a) ((a) & kAlias)
#define isMapToAll(a) ((a) & kMapToAll)
#define isDefine(a) ((a) & kDefine)



DATATYPE get_datatype_by_string(string s);

string get_string_by_ir_type(IRTYPE type);
string get_string_by_data_type(DATATYPE tt);
string get_string_by_data_flag(DATAFLAG flag_type_);
IR * deep_copy(const IR* const root);

void deep_delete(IR * root);

#endif

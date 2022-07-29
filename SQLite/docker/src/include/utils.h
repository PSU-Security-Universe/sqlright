#ifndef __UTILS_H__
#define __UTILS_H__

//#include "define.h"
//#include "ast.h"

#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <dirent.h>
#include <iostream>
#include <random>
#include <string>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>

using namespace std;

#define vector_rand_ele(a)                                                     \
  (a.size() != 0 ? a[get_rand_int(a.size())]                                   \
                 : (*a.insert(a.begin(), gen_id_name())))

static std::random_device rd; // random device engine, usually based on
                              // /dev/random on UNIX-like systems
// initialize Mersennes' twister using rd to generate the seed
static std::mt19937 rng{rd()};

inline int get_rand_int(int range) {
  if (range != 0) {
    std::uniform_int_distribution<int> uid(0, range - 1);
    return uid(rng);
  } else
    return 0;
}
uint64_t fuzzing_hash(const void *key, int len);
void trim_string(string &);
std::vector<string> get_all_files_in_dir(const char *dir_name);
string magic_string_generator(string &s);
void ensure_semicolon_at_query_end(string &);
std::vector<string> string_splitter(const string &input_string,
                                    const char delimiter_re);
bool is_str_empty(string input_str);

string::const_iterator findStringIter(const std::string &strHaystack,
                                      const std::string &strNeedle);
bool findStringIn(const std::string &strHaystack, const std::string &strNeedle);

enum ORA_COMP_RES { Pass = 1, Fail = 0, Error = -1, ALL_Error = -1, IGNORE = -2 };

struct COMP_RES {
  string res_str_0 = "EMPTY", res_str_1 = "EMPTY", res_str_2 = "EMPTY",
         res_str_3 = "EMPTY";
  vector<string> v_res_str;
  int res_int_0 = -1, res_int_1 = -1, res_int_2 = -1, res_int_3 = -1;
  vector<int> v_res_int;

  ORA_COMP_RES comp_res;
  vector<int> explain_diff_id; // Is EXPLAIN QUERY PLAN provides different
                               // execution plans between different validation.
};

struct ALL_COMP_RES {
  vector<COMP_RES> v_res;
  ORA_COMP_RES final_res = ORA_COMP_RES::Fail;
  string cmd_str;
  vector<string> v_cmd_str;
  string res_str;
  vector<string> v_res_str;
};

#endif

#include "../include/utils.h"
#include "../include/ir_wrapper.h"
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <cstring>
#include <algorithm>

using namespace std;

IRWrapper ir_wrapper_2;

void trim_string(string &res){
    int count = 0;
    int idx = 0;
    bool expect_space = false;
    for(int i = 0; i < res.size(); i++){
        if(res[i] == ';' && i != res.size() - 1){
            res[i+1] = '\n';
        }
        if(res[i] == ' '){
            if(expect_space == false){
                continue;
            }else{
                expect_space = false;
                res[idx++] = res[i];
                count ++;
            }
        }else{
            expect_space = true;
            res[idx++] = res[i];
            count ++;
        }
    }

    res.resize(count);
}

string gen_string(){
    return string("x");
}

double gen_float(){
    return 1.2;
}

long gen_long(){
    return 1;
}

int gen_int(){
    return 1;
}


typedef unsigned long uint64_t;

uint64_t fucking_hash ( const void * key, int len )
{
	const uint64_t m = 0xc6a4a7935bd1e995;
	const int r = 47;
	uint64_t h = 0xdeadbeefdeadbeef ^ (len * m);

	const uint64_t * data = (const uint64_t *)key;
	const uint64_t * end = data + (len/8);

	while(data != end)
	{
		uint64_t k = *data++;

		k *= m; 
		k ^= k >> r; 
		k *= m; 
		
		h ^= k;
		h *= m; 
	}

	const unsigned char * data2 = (const unsigned char*)data;

	switch(len & 7)
	{
	case 7: h ^= uint64_t(data2[6]) << 48;
	case 6: h ^= uint64_t(data2[5]) << 40;
	case 5: h ^= uint64_t(data2[4]) << 32;
	case 4: h ^= uint64_t(data2[3]) << 24;
	case 3: h ^= uint64_t(data2[2]) << 16;
	case 2: h ^= uint64_t(data2[1]) << 8;
	case 1: h ^= uint64_t(data2[0]);
	        h *= m;
	};
 
	h ^= h >> r;
	h *= m;
	h ^= h >> r;

	return h;
} 

vector<string> get_all_files_in_dir( const char * dir_name  )
{
        vector<string> file_list;
         if( NULL == dir_name  )
         {
               cout<<" dir_name is null ! "<<endl;
                 return file_list;
                  
         }
          
          struct stat s;
           lstat( dir_name , &s  );
            if( ! S_ISDIR( s.st_mode  )  )
            {
                  cout<<"dir_name is not a valid directory !"<<endl;
                    return file_list;
                     
            }
             
             struct dirent * filename;    // return value for readdir()
               DIR * dir;                   // return value for opendir()
                dir = opendir( dir_name  );
                 if( NULL == dir  )
                 {
                       cout<<"Can not open dir "<<dir_name<<endl;
                         return file_list;
                          
                 }
                  cout<<"Successfully opened the dir !"<<endl;
                   
                   while( ( filename = readdir(dir)  ) != NULL  )
                   {
                         if( strcmp( filename->d_name , "."  ) == 0 || 
                                    strcmp( filename->d_name , ".." ) == 0    )
                                continue;
                           cout<<filename->d_name <<endl;
                                   file_list.push_back(string(filename->d_name));
                                    
                   }
                       return file_list;
                       
}


string::const_iterator findStringIter(const std::string &strHaystack,
                                      const std::string &strNeedle) {
  auto it =
      std::search(strHaystack.begin(), strHaystack.end(), strNeedle.begin(),
                  strNeedle.end(), [](char ch1, char ch2) {
                    return std::toupper(ch1) == std::toupper(ch2);
                  });
  return it;
}

bool findStringIn(const std::string &strHaystack,
                  const std::string &strNeedle) {
  return (findStringIter(strHaystack, strNeedle) != strHaystack.end());
}

bool is_str_empty(string input_str) {
  for (int i = 0; i < input_str.size(); i++) {
    char c = input_str[i];
    if (!isspace(c) && c != '\n' && c != '\0')
      return false; // Not empty.
  }
  return true; // Empty
}

// from http://www.cplusplus.com/forum/beginner/114790/
vector<string> string_splitter(const std::string &s, const char delimiter) {

  size_t start = 0;
  size_t end = s.find_first_of(delimiter);

  vector<string> output;

  while (end <= string::npos) {

    output.emplace_back(s.substr(start, end - start));

    if (end == string::npos)
      break;

    start = end + 1;
    end = s.find_first_of(delimiter, start);
  }

  return output;
}

int run_parser_multi_stmt(string cmd_str, vector<IR*>& ir_vec_all_stmt) {

  vector<IR*> ir_vec_single;
  vector<IR*> v_ir_root;
  IR* ir_root;

  vector<string> v_cmd_str = string_splitter(cmd_str, ';');
  for (string cur_cmd_str : v_cmd_str) {

    if(is_str_empty(cur_cmd_str)) continue;

    cur_cmd_str += ";";

    ir_vec_single.clear();
    int ret = run_parser(cur_cmd_str, ir_vec_single);

    if (ret != 0 || ir_vec_single.size() == 0) {
      // cerr << "String parsing failed: " << cur_cmd_str << "\n\n\n";
      // for (IR* ir_root : v_ir_root) {
      //   ir_root->deep_drop();
      // }
      // v_ir_root.clear();
      // return 1;
      continue;
    }

    IR* cur_ir_root = ir_vec_single.back();

    if (!(cur_ir_root->get_left())) {
      // cerr << "query return left empty: " << cur_cmd_str << "\n\n\n";
      cur_ir_root->deep_drop();
      continue;
    }

    if (!(cur_ir_root->get_left()->get_left())) {
      // cerr << "query return left->left empty: " << cur_cmd_str << "\n\n\n";
      cur_ir_root->deep_drop();
      continue;
    }

    if (ir_vec_single.size() > 700) {
      // Do not mutate on too complicated statements, fix them. 
      // cerr << "query too complicated, do not mutate, fixed: " << cur_ir_root->to_string() << "\n\n\n";
      for (IR* cur_comp_ir : ir_vec_single) {
        cur_comp_ir->is_node_struct_fixed = true;
      }
      // cur_ir_root->deep_drop();
      // continue;
    }

    IR* cur_stmt = ir_wrapper_2.get_first_stmt_from_root(cur_ir_root)->deep_copy();
    v_ir_root.push_back(cur_stmt);

    // cerr << "Just run throught the run_parser, getting: \n";
    // cerr << cur_stmt->to_string();
    // cerr << "\n\n\n\n";

    cur_ir_root->deep_drop();
  }

  ir_root = ir_wrapper_2.reconstruct_ir_with_stmt_vec(v_ir_root);

  if (!ir_root) {
    // cerr << "IR reconstruct failed in run_parser_multi_stmt. \n";
    // cerr << "cmd_str: \n" << cmd_str << "\n\n\n";
    for (IR* cur_ir_root : v_ir_root) {
      cur_ir_root->deep_drop();
    } 
    return 1;
  }

  // cerr << "DEBUG: Inside run_parser_multi_stmt, getting: \n";
  // cerr << ir_root->to_string();
  // cerr << get_string_by_ir_type(ir_root->type_);
  // cerr << "\n\n\n";

  ir_vec_all_stmt = ir_wrapper_2.get_all_ir_node(ir_root);

  if (ir_vec_all_stmt.size() > 0) {

    /* Set up unique_id */
    int id = 0;
    for (IR* cur_ir : ir_vec_all_stmt) {
      cur_ir->uniq_id_in_tree_ = id++;
    }
    /* Double check whether root's parent is NULL.  */
    ir_vec_all_stmt.back()->parent_ = NULL; 

    // cerr << "Before returnning in the run_parser_multi_stmt, last check on the root\n\n\n";
    // ir_root = ir_vec_all_stmt.back();
    // cerr << ir_root->to_string();
    // cerr << get_string_by_ir_type(ir_root->type_);
    // cerr << "\n\n\n";

    for (IR* cur_ir_root : v_ir_root) {
      cur_ir_root->deep_drop();
    } 

    return 0;
  } else {
    for (IR* cur_ir_root : v_ir_root) {
      cur_ir_root->deep_drop();
    } 
    return 1;
  }
}
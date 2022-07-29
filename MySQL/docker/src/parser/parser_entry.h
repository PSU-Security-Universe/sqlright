#ifndef __PARSER_ENTRY_H__
#define __PARSER_ENTRY_H__

#include <vector>
#include <string>

class IR;

int run_parser(std::string cmd_str, std::vector<IR*>& ir_vec);
void parser_init(const char* program_name);
void parser_teardown();

#endif
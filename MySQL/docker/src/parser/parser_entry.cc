
#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
#include <string>
#include <vector>
#include <iostream>

#include <gtest/gtest.h>

#include "thr_lock.h"

#include "parser_entry.h"

#include "my_config.h"
#include "my_getopt.h"
#include "my_inttypes.h"
#include "my_sys.h"
#include "storage/temptable/include/temptable/allocator.h"
#include "unittest/gunit/test_utils.h"
#include "unittest/gunit/fake_table.h"

#include "sql/item_func.h"
#include "sql/sql_lex.h"
#include "template_utils.h"
#include "thr_lock.h"
#include "unittest/gunit/parsertest.h"
#include "unittest/gunit/test_utils.h"

using std::vector;
using std::string;

// We choose non-zero to avoid it working by coincidence.
int Fake_TABLE::highest_table_id = 5;
Server_initializer initializer;

int run_parser(string cmd_str, vector<IR*>& ir_vec) {

  // printf("Enter parser function.\n");

  ir_vec = ::parse(&initializer, cmd_str.c_str(), 0, 0);

  if (ir_vec.size() == 0) {
    return 1;
  }

  if ( ir_vec.back()->get_ir_type() != kStartEntry) {
    return 1;
  }

  // my_testing::teardown_server_simple();

  // printf("Exit parser function.\n");
  return 0;
}

void parser_init(const char* program_name) {
  MY_INIT(program_name);

  my_testing::setup_server_for_unit_tests();
  initializer.SetUp();
}

void parser_teardown() {
  my_testing::teardown_server_for_unit_tests();
  initializer.TearDown();
}
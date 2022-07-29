/*
  Copyright 2013 Google LLC All rights reserved.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at:

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/*
   american fuzzy lop - fuzzer code
   --------------------------------

   Written and maintained by Michal Zalewski <lcamtuf@google.com>

   Forkserver design by Jann Horn <jannhorn@googlemail.com>

   This is the real deal: the program takes an instrumented binary and
   attempts a variety of basic fuzzing tricks, paying close attention to
   how they affect the execution path.

*/

#define AFL_MAIN

#include "debug.h"

#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "../oracle/sqlite_index.h"
#include "../oracle/sqlite_likely.h"
#include "../oracle/sqlite_norec.h"
#include "../oracle/sqlite_oracle.h"
#include "../oracle/sqlite_rowid.h"
#include "../oracle/sqlite_tlp.h"

/* Display usage hints. */

static void usage(u8 *argv0) {

  SAYF("\n%s -r /path/to/query [ ... ]\n\n"

       "Required parameters:\n\n"

       "  -r query      - path to query file\n"
       "  -O ORACLE     - oracle type(default is NOREC)\n\n"

       "For additional tips, please consult README.md\n\n",

       argv0);

  exit(1);
}

#ifndef AFL_LIB

int main(int argc, char **argv) {
  s32 opt;
  Mutator g_mutator;
  SQL_ORACLE *p_oracle;
  string minimize_target;

  p_oracle = nullptr;
  g_mutator.set_use_cri_val(false);

  // SAYF(cCYA "sqlite3 query minimizer " cBRI VERSION cRST
  //           " by <vancirprince@gmail.com>\n");

  while ((opt = getopt(argc, argv, "+O:r:")) > 0) {
    switch (opt) {
    case 'O': {
      /* Oracle, default is NOREC */
      string arg = string(optarg);
      if (arg == "NOREC")
        p_oracle = new SQL_NOREC();
      else if (arg == "TLP")
        p_oracle = new SQL_TLP();
      else if (arg == "LIKELY")
        p_oracle = new SQL_LIKELY();
      else if (arg == "ROWID")
        p_oracle = new SQL_ROWID();
      else if (arg == "INDEX")
        p_oracle = new SQL_INDEX();
      else
        FATAL("Oracle arguments not supported. ");
    } break;

    case 'r': {
      /* set minimize target file */
      minimize_target = string(optarg);
      cout << "minimize target file: " << minimize_target.c_str() << endl;
    } break;

    default:
      usage(argv[0]);
    }
  }

  /* Finish setup g_mutator and p_oracle; */
  if (p_oracle == nullptr)
    p_oracle = new SQL_NOREC();
  p_oracle->set_mutator(&g_mutator);
  g_mutator.set_p_oracle(p_oracle);

  /* Read target query. */
  ifstream minimize_target_stream(minimize_target);
  stringstream minimize_target_query_stream;
  minimize_target_query_stream << minimize_target_stream.rdbuf();
  string minimize_target_query = minimize_target_query_stream.str();
  cout << "Target query: " << minimize_target_query.c_str() << endl;

  /* get all kinds of minimized queries from parser. */
  set<string> minimize_query_string_set =
      g_mutator.get_minimize_string_from_tree(minimize_target_query);

  /* remove invalid oracle statements. */
  // for (auto it = minimize_query_string_set.begin();
  //      it != minimize_query_string_set.end(); ++it) {
  //   if (!p_oracle->is_oracle_valid_stmt(*it))
  //     minimize_query_string_set.erase(it);
  // }

  /* output all minimize queries. */
  for (string minimized_query : minimize_query_string_set) {
    cout << "[+] " << minimized_query.c_str() << endl;
  }

  /* output the number of queries. */
  cout << "Get " << minimize_query_string_set.size() << " minimized queries."
       << endl;

  exit(0);
}

#endif /* !AFL_LIB */

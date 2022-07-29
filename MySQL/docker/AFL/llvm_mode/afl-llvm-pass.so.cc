/*
  Copyright 2015 Google LLC All rights reserved.

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
   american fuzzy lop - LLVM-mode instrumentation pass
   ---------------------------------------------------

   Written by Laszlo Szekeres <lszekeres@google.com> and
              Michal Zalewski <lcamtuf@google.com>

   LLVM integration design comes from Laszlo Szekeres. C bits copied-and-pasted
   from afl-as.c are Michal's fault.

   This library is plugged into LLVM when invoking clang through afl-clang-fast.
   It tells the compiler to add code roughly equivalent to the bits discussed
   in ../afl-as.h.
*/

#define AFL_LLVM_PASS

#include "../config.h"
#include "../debug.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <iostream>
#include <string>

#include "llvm/ADT/Statistic.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/Debug.h"
#include "llvm/Transforms/IPO/PassManagerBuilder.h"

using namespace llvm;

namespace {

  class AFLCoverage : public ModulePass {

    public:

      static char ID;
      AFLCoverage() : ModulePass(ID) { }

      bool runOnModule(Module &M) override;

      // StringRef getPassName() const override {
      //  return "American Fuzzy Lop Instrumentation";
      // }

  };

}


char AFLCoverage::ID = 0;


bool AFLCoverage::runOnModule(Module &M) {

  LLVMContext &C = M.getContext();

  std::string cur_file_name = M.getSourceFileName();

//  if (
//	cur_file_name.find("sql_yacc") == std::string::npos &&
//	cur_file_name.find("sql_alter") == std::string::npos &&
//	cur_file_name.find("sql_db") == std::string::npos &&
//	cur_file_name.find("sql_delete") == std::string::npos &&
//	cur_file_name.find("sql_derived") == std::string::npos &&
//	cur_file_name.find("sql_insert") == std::string::npos &&
//	cur_file_name.find("sql_join_buffer") == std::string::npos &&
//	cur_file_name.find("sql_lex") == std::string::npos &&
//	cur_file_name.find("sql_parse") == std::string::npos &&
//	cur_file_name.find("sql_rename") == std::string::npos &&
//	cur_file_name.find("sql_parse") == std::string::npos &&
//	cur_file_name.find("sql_select") == std::string::npos &&
//	cur_file_name.find("sql_show") == std::string::npos &&
//	cur_file_name.find("sql_table") == std::string::npos &&
//	cur_file_name.find("sql_truncate") == std::string::npos &&
//	cur_file_name.find("sql_udf") == std::string::npos &&
//	cur_file_name.find("sql_union") == std::string::npos &&
//	cur_file_name.find("sql_update") == std::string::npos &&
//	cur_file_name.find("sql_view") == std::string::npos &&
////
////	cur_file_name.find("sql_") == std::string::npos
//	cur_file_name.find("join_") == std::string::npos &&
//	cur_file_name.find("opt_") == std::string::npos &&
//	cur_file_name.find("/range_optimizer/") == std::string::npos &&
//	cur_file_name.find("/join_optimizer/") == std::string::npos &&
//	cur_file_name.find("/partitioning/") == std::string::npos &&
//	cur_file_name.find("item_") == std::string::npos
//     ) {
//	  return false;
//  }
//
//  if (
//	cur_file_name.find("binlog") != std::string::npos ||
//	cur_file_name.find("admin") != std::string::npos ||
//	cur_file_name.find("error") != std::string::npos ||
//	cur_file_name.find("audit") != std::string::npos ||
//	cur_file_name.find("event") != std::string::npos ||
//	cur_file_name.find("trigger") != std::string::npos ||
//	cur_file_name.find("lock") != std::string::npos ||
//	cur_file_name.find("backup") != std::string::npos ||
//	cur_file_name.find("bootstrap") != std::string::npos ||
//	cur_file_name.find("client") != std::string::npos ||
//	cur_file_name.find("exception") != std::string::npos ||
//	cur_file_name.find("profile") != std::string::npos ||
//	cur_file_name.find("thd") != std::string::npos ||
//	cur_file_name.find("timer") != std::string::npos
//)  {
//	  return false;
//  }


// if (cur_file_name.find("/sql_") == std::string::npos) {
//       return false;
// }


///* Remove from blacklist */
//if (cur_file_name.find("binlog") != std::string::npos) {
//  return false;
//}
//if (cur_file_name.find("log") != std::string::npos) {
//  return false;
//}
//if (cur_file_name.find("/auth/") != std::string::npos) {
//  return false;
//}
//if (cur_file_name.find("mysys/") != std::string::npos) {
//  return false;
//}
//if (cur_file_name.find("/dd/") != std::string::npos) {
//  return false;
//}
//if (cur_file_name.find("boost") != std::string::npos) {
//  return false;
//}
//if (cur_file_name.find("rpl_") != std::string::npos) {
//  return false;
//}
//if (cur_file_name.find("srv_") != std::string::npos) {
//  return false;
//}
//if (cur_file_name.find("plugin/") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("storage") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("error") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("audit") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("event") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("trigger") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("lock") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("backup") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("bootstrap") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("client") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("exception") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("profile") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("thd") != std::string::npos) {
//	return false;
//}
//if (cur_file_name.find("timer") != std::string::npos) {
//	return false;
//}



  IntegerType *Int8Ty  = IntegerType::getInt8Ty(C);
  IntegerType *Int32Ty = IntegerType::getInt32Ty(C);

  /* Show a banner */

  char be_quiet = 0;

  if (isatty(2) && !getenv("AFL_QUIET")) {

    SAYF(cCYA "afl-llvm-pass " cBRI VERSION cRST " by <luy70@psu.edu>. Block coverage. \n");

  } else be_quiet = 1;

  /* Decide instrumentation ratio */

  char* inst_ratio_str = getenv("AFL_INST_RATIO");
  unsigned int inst_ratio = 100;

  if (inst_ratio_str) {

    if (sscanf(inst_ratio_str, "%u", &inst_ratio) != 1 || !inst_ratio ||
        inst_ratio > 100)
      FATAL("Bad value of AFL_INST_RATIO (must be between 1 and 100)");

  }

  /* Get globals for the SHM region and the previous location. Note that
     __afl_prev_loc is thread-local. */

  GlobalVariable *AFLMapPtr =
      new GlobalVariable(M, PointerType::get(Int8Ty, 0), false,
                         GlobalValue::ExternalLinkage, 0, "__afl_area_ptr");

  // GlobalVariable *AFLPrevLoc = new GlobalVariable(
  //     M, Int32Ty, false, GlobalValue::ExternalLinkage, 0, "__afl_prev_loc",
  //     0, GlobalVariable::GeneralDynamicTLSModel, 0, false);

  /* Instrument all the things! */

  int inst_blocks = 0;

  for (auto &F : M)
    for (auto &BB : F) {

      BasicBlock::iterator IP = BB.getFirstInsertionPt();
      IRBuilder<> IRB(&(*IP));

      if (AFL_R(100) >= inst_ratio) continue;

      /* Make up cur_loc */

      unsigned int cur_loc = AFL_R(MAP_SIZE);

      ConstantInt *CurLoc = ConstantInt::get(Int32Ty, cur_loc);

      /* Load prev_loc */

      // LoadInst *PrevLoc = IRB.CreateLoad(AFLPrevLoc);
      // PrevLoc->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
      // Value *PrevLocCasted = IRB.CreateZExt(PrevLoc, IRB.getInt32Ty());

      /* Load SHM pointer */

      LoadInst *MapPtr = IRB.CreateLoad(AFLMapPtr);
      MapPtr->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
      Value *MapPtrIdx =
          IRB.CreateGEP(MapPtr, CurLoc);
      // Value *MapPtrIdx = IRB.CreateZExt(CurLoc, IRB.getInt32Ty());

      /* Update bitmap */

      LoadInst *Counter = IRB.CreateLoad(MapPtrIdx);
      Counter->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));
      // Value *Incr = IRB.CreateAdd(Counter, ConstantInt::get(Int8Ty, 1));
      ConstantInt *const_one = ConstantInt::get(Int8Ty, 1);
      IRB.CreateStore(const_one, MapPtrIdx)
          ->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));

      /* Set prev_loc to cur_loc >> 1 */

      // StoreInst *Store =
      //     IRB.CreateStore(ConstantInt::get(Int32Ty, cur_loc >> 1), AFLPrevLoc);
      // Store->setMetadata(M.getMDKindID("nosanitize"), MDNode::get(C, None));

      inst_blocks++;

    }

  /* Say something nice. */

  if (!be_quiet) {

    if (!inst_blocks) WARNF("No instrumentation targets found.");
    else OKF("Instrumented %u locations (%s mode, ratio %u%%).",
             inst_blocks, getenv("AFL_HARDEN") ? "hardened" :
             ((getenv("AFL_USE_ASAN") || getenv("AFL_USE_MSAN")) ?
              "ASAN/MSAN" : "non-hardened"), inst_ratio);

  }

  return true;

}


static void registerAFLPass(const PassManagerBuilder &,
                            legacy::PassManagerBase &PM) {

  PM.add(new AFLCoverage());

}


static RegisterStandardPasses RegisterAFLPass(
    PassManagerBuilder::EP_ModuleOptimizerEarly, registerAFLPass);

static RegisterStandardPasses RegisterAFLPass0(
    PassManagerBuilder::EP_EnabledOnOptLevel0, registerAFLPass);

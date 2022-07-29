#
# american fuzzy lop - makefile
# -----------------------------
#
# Written and maintained by Michal Zalewski <lcamtuf@google.com>
# 
# Copyright 2013, 2014, 2015, 2016, 2017 Google LLC All rights reserved.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
# 
#   http://www.apache.org/licenses/LICENSE-2.0
#

PROGNAME    = afl
VERSION     = $(shell grep '^\#define VERSION ' config.h | cut -d '"' -f2)

MYSQL_SRC_PATH =  ../parser/mysql-server/bld/
MYSQL_INSTALL_PATH =  ../parser/mysql-server/bld/
MYSQL_LIB_PATH   = $(MYSQL_INSTALL_PATH)/lib 
MYSQL_HEADER_PATH = $(MYSQL_SRC_PATH)/include
MYSQL_INSTALL_HEADER_PATH = $(MYSQL_INSTALL_PATH)/include
PREFIX     ?= /usr/local
BIN_PATH    = $(PREFIX)/bin
HELPER_PATH = $(PREFIX)/lib/afl
DOC_PATH    = $(PREFIX)/share/doc/afl
MISC_PATH   = $(PREFIX)/share/afl
DEPEN_PATH  = ../src/*.cpp  #../parser/parser_entry.cc

PARSER_INCLUDE_PATH = -I../parser/ 
PARSER_INCLUDE_PATH += -I../parser/mysql-server

# PROGS intentionally omit afl-as, which gets installed elsewhere.

# PROGS       = afl-fuzz

CC         = g++
CFLAGS     ?= -fpermissive --std=c++17 -static-libstdc++
CFLAGS     += -g -w \
	      -DAFL_PATH=\"$(HELPER_PATH)\" -DDOC_PATH=\"$(DOC_PATH)\" \
	      -DBIN_PATH=\"$(BIN_PATH)\"
CFLAGS     += -I$(MYSQL_HEADER_PATH) -I$(MYSQL_INSTALL_HEADER_PATH)

DEPDIR := .deps
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.d


COMPILE.c = $(CC) $(DEPFLAGS) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c

SRCS = afl-fuzz.cpp test-parser.cpp
# SRCS = test-parser.cpp

include depend.make

all: $(SRCS:%.cpp=%.o)

afl-fuzz.o: afl-fuzz.cpp $(DEPDIR)
	$(COMPILE.c) -g $^ $(DEPEN_PATH) $(LDFLAGS)  -lmysqlclient $(PARSER_INCLUDE_PATH)

test-parser.o: test-parser.cpp $(DEPDIR)
	$(COMPILE.c) -g $^ $(DEPEN_PATH) $(LDFLAGS)  -lmysqlclient $(PARSER_INCLUDE_PATH)

.NOTPARALLEL: clean

clean:
	rm -rf $(PROGS)  .deps *.gch *.o

$(DEPDIR): ; @mkdir -p $@

DEPFILES := $(SRCS:%.cpp=$(DEPDIR)/%.d)
$(DEPFILES):

include $(wildcard $(DEPFILES))

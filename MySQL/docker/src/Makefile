SUB_DIRS := oracle src AFL

PARSER_SRCS := parser/parser_entry.cc.o
LIB_SRCS := $(wildcard src/*.cpp) $(wildcard oracle/*.cpp) $(PARSER_SRCS)
COMM_OBJS := $(patsubst %.cpp,%.o,$(LIB_SRCS))
DEPEN_PATH  = ../src/*.cpp  ../parser/parser_entry.cc

AFL_OBJS := AFL/afl-fuzz.o $(COMM_OBJS)
TEST_OBJS:= AFL/test-parser.o $(COMM_OBJS)

MYSQL_INCLUDE_PATH = /usr/include/mysql
MYSQL_LIB_PATH = 

export CC = g++
export DEBUG =
export OPT = -O3
export CFLAGS = -std=c++17 -fpermissive -static-libstdc++ $(DEBUG) $(OPT) $(ASAN_FLAGS)
LDFLAGS = -ldl -lmysqlclient

include parser/link_depend.make

all: afl-fuzz test-parser

parser:
	@$(MAKE) -C $@

$(SUB_DIRS): parser
	@$(MAKE) -C $@

afl-fuzz: $(SUB_DIRS)
	$(CC) $(CFLAGS) $(AFL_OBJS)  -I $(PGSQL_INCLUDE_PATH)  -L $(PGSQL_LIB_PATH)  -o $@ $(LDFLAGS) $(PARSER_LINK_FLAGS)
	cp afl-fuzz ./fuzz_root

test-parser: $(SUB_DIRS)
	$(CC) $(CFLAGS) $(TEST_OBJS) -I $(PGSQL_INCLUDE_PATH) -L $(PGSQL_LIB_PATH) -o $@ $(LDFLAGS) $(PARSER_LINK_FLAGS)
	cp test-parser ./fuzz_root

debug: DEBUG = -g
debug: OPT = -O0
debug:
	$(MAKE) -e

asan: ASAN_FLAGS = -fsanitize=address
asan: DEBUG = -g
asan: OPT = -O0
asan:
	$(MAKE) -e

.PHONY: parser $(SUB_DIRS)

clean:
	@make clean -C parser
	@make clean -C src
	@make clean -C oracle
	@make clean -C AFL
	rm -rf afl-fuzz
	rm -rf ./include/*.gch ./include/.deps

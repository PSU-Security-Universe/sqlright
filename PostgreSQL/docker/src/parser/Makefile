# bison's version is too old on OSX, allow user to pass in custom path
BISON?=bison
FLEX?=flex

#BISON_VERSION=$(shell $(BISON) --version | head -n 1 | grep -o '[0-9]\.[0-9]\+')
#BISON_VERSION_SUPPORTED=$(shell echo $(BISON_VERSION) \>= 3.0 | bc)
#ifneq ($(BISON_VERSION_SUPPORTED), 1)
#$(error Bison version $(BISON_VERSION) not supported. If you are using OS X, `bison` uses the system default instead of the brew version. Run BISON=/usr/local/opt/bison/bin/bison make)
#endif

#FLEX_VERSION=$(shell $(FLEX) --version | head -n 1 | grep -o '[0-9]\.[0-9]\+')
#FLEX_VERSION_SUPPORTED=$(shell echo $(FLEX_VERSION) \>= 2.6 | bc)
#ifneq ($(FLEX_VERSION_SUPPORTED), 1)
#$(error Flex version $(FLEX_VERSION) not supported. If you are using OS X, `flex` uses the system default instead of the brew version. Run FLEX=/usr/local/opt/flex/bin/flex make)
#endif

SRCS = bison_parser.cpp flex_lexer.cpp parser.cpp

all: $(SRCS:%.cpp=%.o)

bison_parser.cpp: bison_parser.y
	$(BISON) bison_parser.y  -t --output=bison_parser.cpp --defines=bison_parser.h --verbose -Wconflicts-rr # --debug

flex_lexer.cpp: flex_lexer.l
	$(FLEX) flex_lexer.l

clean:
	rm -rf bison_parser.cpp bison_bison.cpp flex_lexer.cpp flex_lexer.cpp bison_parser.h bison_parser.h flex_lexer.h flex_lexer.h *.output *.o .deps *.gch

# Tests if the parser builds correctly and doesn't contain conflicts.
test:
	! $(BISON) bison_parser.y -v --output=conflict_test.cpp 2>&1 | grep "conflict" >/tmp/2

DEPDIR := .deps
DEPFLAGS = -MT $@ -MMD -MP -MF $(DEPDIR)/$*.d

#CPPFLAGS += "-Wno-write-strings"

COMPILE.c = $(CXX) $(DEPFLAGS) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -c -I ./include/ -fPIC

parser.o: parser.cpp bison_parser.cpp flex_lexer.cpp
	g++ $< -o $@ -c -I ./include/ $(DEBUG) $(OPT)

%.o : %.cpp $(SRCS)  $(DEPDIR)/%.d | $(DEPDIR)
	$(COMPILE.c) $(OUTPUT_OPTION) $<

$(DEPDIR): ; @mkdir -p $@

DEPFILES := $(SRCS:%.cpp=$(DEPDIR)/%.d)
$(DEPFILES):

include $(wildcard $(DEPFILES))

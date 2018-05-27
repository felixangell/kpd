ifeq ($(DC),)
	DC := dmd
endif

ifeq ($(DC), ldc2)
	D_FLAGS := -cache=krug_cache/ -march=x86-64 -d-debug -g -w 
else
	D_FLAGS := -m64 -debug -g
endif

D_SOURCES := $(shell find src -type f -name '*.d')
D_OBJ_FILES := $(patsubst %.d,%.o,$(D_SOURCES))

LLVM_CONF := $(shell llvm-config --cflags --ldflags --libs core executionengine analysis native bitwriter --system-libs)

# this should use llvm-config but the first four flags are not
# valid for non gcc things
LLVM_DCONF := -L-L/usr/lib -L-lLLVM-6.0

LD_FLAGS := -vcolumns
KRUG_OUT_DIR := bin
KRUG_OUT := $(KRUG_OUT_DIR)/krug

default: $(KRUG_OUT)

ifeq ($(CC),)
	CC := clang
endif

CC_FLAGS := -Wall -Wextra -g3 -std=c99 -Wno-unused-function
GCC_FLAGS := $(LLVM_CONF) -m64 -Xlinker -no_compact_unwind -Xlinker -lz -lcurses -lm -L/usr/local/opt/dmd/lib -lphobos2 -lpthread -lm

%.o: %.c
	$(CC) -fPIC $(CC_FLAGS) -c $< -o $@

$(KRUG_OUT): $(D_SOURCES)
ifeq ($(shell uname), Darwin)
	@mkdir -p $(KRUG_OUT_DIR)
	$(DC) -c -of$@.o -dip1000 $(D_FLAGS) $(LD_FLAGS) $(D_SOURCES)
	g++ bin/krug.o -o bin/krug -g $(GCC_FLAGS) -stdlib=libc++
else
	@mkdir -p $(KRUG_OUT_DIR)
	$(DC) -of$@ -dip1000 $(LLVM_DCONF) $(D_FLAGS) $(LD_FLAGS) $(D_SOURCES)
endif

mac:

clean:
	-rm $(KRUG_OUT)

.PHONY: clean default all lib $(VM_OUT) $(KRUG_OUT) tests

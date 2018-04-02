D_COMPILER := dmd

ifeq ($(D_COMPILER), ldc2)
	D_FLAGS := -cache=krug_cache/ -march=x86-64 -d-debug -g -w
else
	D_FLAGS := -m64 -debug -g -w
endif

D_SOURCES := $(shell find src -type f -name '*.d')
D_OBJ_FILES := $(patsubst %.d,%.o,$(D_SOURCES))

LD_FLAGS := -L=vm/krugvm.a -vcolumns
KRUG_OUT := krug

default: $(KRUG_OUT)

VM_CC_SRC_FILES := $(wildcard vm/src/*.c)
VM_CC_OBJ_FILES := $(patsubst %.c,%.o,$(VM_CC_SRC_FILES))
VM_OUT := vm/krugvm.a

CC := clang
CC_FLAGS := -Wall -Wextra -g3 -std=c99 -Wno-unused-function

%.o: %.c
	$(CC) -fPIC $(CC_FLAGS) -c $< -o $@

$(VM_OUT): $(VM_CC_OBJ_FILES)
	ar -cvq $(VM_OUT) $(VM_CC_OBJ_FILES)

$(KRUG_OUT): $(VM_OUT) $(D_SOURCES)
	$(D_COMPILER) -of$@ -dip1000 $(D_FLAGS) $(LD_FLAGS) $(D_SOURCES)
	
tests:
	$(D_COMPILER) -of$@_test -unittest $(D_FLAGS) $(LD_FLAGS) $(D_SOURCES)

clean:
	-rm $(VM_CC_OBJ_FILES)
	-rm $(VM_OUT)
	-rm $(KRUG_OUT)

.PHONY: clean default all lib $(VM_OUT) $(KRUG_OUT) tests

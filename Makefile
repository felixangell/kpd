D_FLAGS := -dip1000 -march=x86-64 -d-debug -g -w -c
D_COMPILER := ldc2
D_SOURCES := $(shell find src -type f -name '*.d')
D_OBJ_FILES := $(patsubst %.d,%.o,$(D_SOURCES))

LD_FLAGS := -L=vm/krugvm.a -L=-lcollectc -vcolumns
KRUG_OUT := krug

default: $(KRUG_OUT)

VM_CC_SRC_FILES := $(wildcard vm/src/*.c)
VM_CC_OBJ_FILES := $(patsubst %.c,%.o,$(VM_CC_SRC_FILES))
VM_OUT := vm/krugvm.a

CC := clang
CC_FLAGS := -Wall -Wextra -g3 -std=c99 -Wno-unused-function

%.o: %.c
	$(CC) $(CC_FLAGS) -c $< -o $@

$(VM_OUT): $(VM_CC_OBJ_FILES)
	ar -cvq $(VM_OUT) $(VM_CC_OBJ_FILES)

$(KRUG_OUT): $(VM_OUT) $(D_SOURCES)
	$(D_COMPILER) $(D_FLAGS) -of$(KRUG_OUT) $(LD_FLAGS) $(D_SOURCES)
	
clean:
	-rm $(VM_CC_OBJ_FILES)
	-rm $(VM_OUT)
	-rm $(KRUG_OUT)

.PHONY: clean default all lib $(VM_OUT) $(KRUG_OUT)

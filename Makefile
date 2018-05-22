ifeq ($(DC),)
	DC := dmd
endif

ifeq ($(DC), ldc2)
	D_FLAGS := -cache=krug_cache/ -march=x86-64 -d-debug -g -w
else
	D_FLAGS := -m64 -debug -g -w
endif

D_SOURCES := $(shell find src -type f -name '*.d')
D_OBJ_FILES := $(patsubst %.d,%.o,$(D_SOURCES))

LD_FLAGS := -L=vm/krugvm.a -vcolumns $(llvm-config --ldflags --libs | sed -e 's/-L/-L-L/g' | sed -e 's/-l/-L-l/g') -L-lstdc++ 
KRUG_OUT_DIR := bin
KRUG_OUT := $(KRUG_OUT_DIR)/krug

default: $(KRUG_OUT)

VM_CC_SRC_FILES := $(wildcard vm/src/*.c)
VM_CC_OBJ_FILES := $(patsubst %.c,%.o,$(VM_CC_SRC_FILES))
VM_OUT := vm/krugvm.a

ifeq ($(CC),)
	CC := clang
endif

CC_FLAGS := -Wall -Wextra -g3 -std=c99 -Wno-unused-function

%.o: %.c
	$(CC) -fPIC $(CC_FLAGS) -c $< -o $@

$(VM_OUT): $(VM_CC_OBJ_FILES)
	ar -cvq $(VM_OUT) $(VM_CC_OBJ_FILES)

$(KRUG_OUT): $(VM_OUT) $(D_SOURCES)
	@mkdir -p $(KRUG_OUT_DIR)
	$(DC) -of$@ -dip1000 $(D_FLAGS) $(LD_FLAGS) $(D_SOURCES)
	
optimized: $(VM_OUT) $(D_SOURCES)
	$(DC) -of$(KRUG_OUT) -O -dip1000 $(D_FLAGS) $(LD_FLAGS) $(D_SOURCES)

clean:
	-rm $(VM_CC_OBJ_FILES)
	-rm $(VM_OUT)
	-rm $(KRUG_OUT)

.PHONY: clean default all lib $(VM_OUT) $(KRUG_OUT) tests

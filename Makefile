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

LD_FLAGS := -vcolumns
KRUG_OUT_DIR := bin
KRUG_OUT := $(KRUG_OUT_DIR)/krug

default: $(KRUG_OUT)

ifeq ($(CC),)
	CC := clang
endif

CC_FLAGS := -Wall -Wextra -g3 -std=c99 -Wno-unused-function

%.o: %.c
	$(CC) -fPIC $(CC_FLAGS) -c $< -o $@

$(KRUG_OUT): $(D_SOURCES)
	@mkdir -p $(KRUG_OUT_DIR)
	$(DC) -of$@ -dip1000 $(D_FLAGS) $(LD_FLAGS) $(D_SOURCES)

mac:

clean:
	-rm $(KRUG_OUT)

.PHONY: clean default all lib $(VM_OUT) $(KRUG_OUT) tests

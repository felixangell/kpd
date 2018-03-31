CC_SRC_FILES := $(wildcard src/*.c)
CC_OBJ_FILES := $(patsubst %.c,%.o,$(CC_SRC_FILES))
OUT := krugvm.a

CC := clang
CC_FLAGS := -Wall -Wextra -g3 -std=c99 -Wno-unused-function

default: $(OUT)

%.o: %.c
	$(CC) $(CC_FLAGS) -c $< -o $@

lib: $(CC_OBJ_FILES)
	ar -cvq $(OUT) $(CC_OBJ_FILES)
	
$(OUT): $(CC_OBJ_FILES)
	$(CC) $(LD_FLAGS) $(CC_OBJ_FILES) -o $(OUT)

clean:
	-rm $(CC_OBJ_FILES)
	-rm $(OUT)

.PHONY: cc default all lib
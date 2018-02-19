src := $(wildcard src/*.c)
obj := $(patsubst %.c,%.o,$(src))
out := krugvm.a

CCFLAGS := -Wall -Wextra -g3 -std=c99
LDFLAGS := -lcollectc

default: $(out)

%.o: %.c
	clang $(CCFLAGS) -c $< -o $@

cc: $(obj)
	clang $(LDFLAGS) $(obj) -o krugvm

$(out): $(obj)
	ar -cvq $(out) $(obj)

.PHONY: cc default all
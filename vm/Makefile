src := $(wildcard src/*.c)
obj := $(patsubst %.c,%.o,$(src))
out := krugvm.a

CCFLAGS := -Wall -Wextra -g3 -std=c99
LDFLAGS := -lcollectc

default: $(out)

%.o: %.c
	clang $(CCFLAGS) -c $< -o $@

lib: $(obj)
	ar -cvq $(out) $(obj)
	
$(out): $(obj)
	clang $(LDFLAGS) $(obj) -o krugvm

clean:
	-rm $(obj)
	-rm $(out)

.PHONY: cc default all
D_FLAGS := -dip1000 -march=x86-64 -ofkrug -d-debug -g -w
D_COMPILER := ldc2
D_SOURCES := $(shell find source/ -type f -name '*.d')

LD_FLAGS := -L=vm/krugvm.a -L=-lcollectc -vcolumns

all:
	# cd into vm, remove all obj files and the lib
	# build the library again.
	cd vm && rm src/*.o && rm krugvm.a && make lib

compiler:
	$(D_COMPILER) $(D_FLAGS) $(LD_FLAGS) $(D_SOURCES)

.PHONY: all
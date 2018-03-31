DCOMPILER := dmd

all:
	# cd into vm, remove all obj files and the lib
	# build the library again.
	cd vm && rm src/*.o && rm krugvm.a && make lib

	# build the dub
	dub build --arch=x86_64 --compiler=$(DCOMPILER) --force

.PHONY: all
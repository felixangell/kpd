exe := krug

all:
	cd vm && rm src/*.o && rm krugvm.a && make lib
	dub build --arch=x86_64 --compiler=ldc2 --force

.PHONY: all
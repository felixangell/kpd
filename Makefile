src_files := $(wildcard source/*.d)
exe := krug

$(exe): $(src_files)
	cd vm && make lib
	dub build --force --arch=x86_64

go: $(exe)
	./krug tests/main.krug -v

all: $(exe)

clean:
	-rm $(exe)

.PHONY: clean $(exe)
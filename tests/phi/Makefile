all:
	krug b main.krug -c -v
	gcc -shared -fpic -no-pie *.o -lSDL2 -o phi
	rm *.o
all:
	cd $(KRUGBIN) && cd ../ && make
	krug b piecetable.krug -c -v
	gcc -fpic -no-pie *.o -lSDL2 -o phi
	rm *.o
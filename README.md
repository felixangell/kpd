# krug
Krug is a compiled programming language.

## try it out
Nothing is in working order, but some tests might run!

Make sure you have `dub` installed as well as a D compiler,
I'm using `ldc2`.

	$ git clone http://github.com/felixangell/krug
	$ cd krug
	$ make
	$ ./krug tests/some_test_here.krug 		# to compile only
	$ ./krug tests/some_test_here.krug -r 		# to compile and run
	$ ./krug tests/some_test_here.krug -r -v 	# compile and run with verbose output
	$ ./krug -e E0001 				# explain error message 1

## future plans
The idea of this language is to keep the features and syntax
relatively simple.

Here's a list of a lot of ideas I have for the language.

* implement an SSA form
* translate the SSA form -> vm bytecode (right now its ast -> vm bytecode)
* -native flag for turning the vm bytecode -> native machine code
* by default when we run with -r, vm bytecode is run
* when we compile, produce an executable with the vm bytuecode -> native machine code system
* how do we handle multi threading if we generate asm?
* optimisation pass! SSA will help with this
* implement the vm in krug

## notes
Though this compiler is written in D, most of the code
is written in a very c/c++-y way!
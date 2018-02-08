# krug
Krug is a compiled programming language.

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

## notes
Though this compiler is written in D, most of the code
is written in a very c/c++-y way!
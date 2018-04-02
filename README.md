# krug
Krug is a compiled programming language that compiles to x64 assembly.

## how it works
here's a brief overview of how the compiler works (so far):

- krug lexes and half parses the main.krug file passed in;
- then the load directives are parsed, the compiler builds a 
  dependency graph for the entire program based on what the main
  file loads
- the dependency graph is checked to ensure it is acyclic
- the graph is then sorted to make resolution easier (i.e. ordered
  such that all symbols should be known when encountered)
- the dependency graphs sub-modules are parsed into their respective
  abstract syntax trees
- each of these trees are then semantically analysed:
  * all symbols are declared
  * names are resolved
  * top level types are _declared_
  * types are then inferred
- then these trees are translated into "Krug IR" or KIR;
  * (TODO) make this an SSA based IR
  * optimisation passes (hand in hand w SSA)
- (1: run command) the compiler can generate bytecode from the krug IR
  for the krug virtual machine which is then executed straight
  after.
- **(2: build command)** the compiler generates x64 assembly from the krug
  ir. this is then assembled into object files and linked together.
  _note: this is the current focus is getting a feature complete x64
  code generator_

## try it out
Nothing is in working order, but some tests might run!

Make sure you have `dub` installed as well as a D compiler,
I'm using `dmd`.

```bash
$ git clone http://github.com/felixangell/krug
$ cd krug
$ make
$
$ ./krug b tests/x64_tests/fib.krug
$ ./a.out
$
$ ./krug e E0001 				# explain error message 1
```

## future plans
The idea of this language is to keep the features and syntax
relatively simple.

## notes
Though this compiler is written in D, most of the code
is written in a very c/c++-y way!
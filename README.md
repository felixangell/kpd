# krug
Krug is a compiled programming language that compiles to x64 assembly. Currently
the prime targets are OS X and Linux.

## try it out
Nothing is in working order, but some tests _might_ run! The compiler still has a long
way to go till it's stable-ish to run some actual programs.

You will likely only be able to build this on OSX and Linux, and you will only _possibly_
get Krug programs to execute on Linux.

### requirements
You'll need a few bits of software to compile the compiler:

* `dmd`, `ldc2`, - some D compiler
* `clang`, `gcc`, - some C compiler
* GNU assembler/linker
* GNU make

### building

```bash
$ git clone http://github.com/felixangell/krug
$ cd krug
$ make
$
$ ./krug b tests/x64_tests/fib.krug
$ ./main
$
$ ./krug e E0001        # explain error message E0001
```

## examples!
For now let's have a nice simple hello world program!

```krug
// no standard library yet!
#{c_func}
func printf();
    //.    ^- no type checking either yet lol
    //.       so this is valid and OK

func main() {
    printf(c"Hello, World!\n");
}
```

## why?!
Krug is a fun little side project. The goal is to create a somewhat polished compiler that 
can compile any Krug program you throw at it. In an ideal world it would compile krug programs 
for most major platforms: Windows, Linux, and OS X. Realistically, it will only work on Linux 
on x64 systems.

The main things I want to do with this project are:

* generate x64 assembly...
* writing directly to object files, no assemblers needed!
* have a reasonable set of optimisation passes, hand-in-hand with an SSA-based IR;

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
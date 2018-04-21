# krug [![Build Status](https://travis-ci.org/felixangell/krug.svg?branch=master)](https://travis-ci.org/felixangell/krug)
Krug is a compiled programming language that compiles to x64 assembly. Currently
the prime targets are OS X and Linux.

## demo
Here's a little demo [vide](https://www.youtube.com/watch?v=j3tRL-vkj8g) on my youtube. The language is
still very much in its infancy and has a lot of work left to be even somewhat stable.

![screenshot of a krug program](/krug_screenshot.png)

## try it out
Nothing is in working order, but some tests _might_ run! The compiler still has a long
way to go till it's stable-ish to run some actual programs.

You will likely only be able to build this on OSX and Linux, and you will only _possibly_
get Krug programs to execute on Linux.

## support
The table below shows the compilers support as of writing this.

              linux     os x      windows
    ia32      todo      todo      todo
    x64       yes       kinda     todo
    arm       todo      todo      todo
    mips      todo      todo      todo
    aarch64   todo      todo      todo

Currently x64 is the main priority, starting off with Linux, then
eventually OS X support, and finally Windows.

### requirements
You'll need a few bits of software to compile the compiler:

* `dmd`, `ldc2`, - some D compiler
* `clang`, `gcc`, - some C compiler
* `as` - GNU assembler/linker
* `make` - GNU make

### building
Krug is relatively easy to build. Once you have all of the software required
it should be as simple as cloning and running make.

#### Mac
The easiest way to get going is use homebrew:

```bash
$ xcode-select --install
$ curl -fsS https://dlang.org/install.sh | bash -s dmd
$
$ git clone http://github.com/felixangell/krug
$ cd krug
$ make
$
$ ./krug b tests/x64_tests/fib.krug
$ ./main
$
$ ./krug e E0001        # explain error message E0001
```

#### Ubuntu

```bash
$ sudo apt-get install build-essential
$ curl -fsS https://dlang.org/install.sh | bash -s dmd
$
$ git clone http://github.com/felixangell/krug
$ cd krug
$ make
$
$ ./krug b tests/x64_tests/fib.krug
$ ./main
$
$ ./krug e E0001        # explain error message E0001
```

#### Windows
Not yet supported.

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
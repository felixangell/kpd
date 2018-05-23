# krug [![Build Status](https://travis-ci.org/felixangell/krug.svg?branch=master)](https://travis-ci.org/felixangell/krug)
Krug is a compiled programming language.

## demo
Here's a little demo [video](https://www.youtube.com/watch?v=j3tRL-vkj8g) on my youtube. The language is
still very much in its infancy and has a lot of work left to be even somewhat stable.

![screenshot of a krug program](/krug_screenshot.png)

## try it out
Nothing is in working order, but some tests _might_ run! The compiler still has a long
way to go till it's stable-ish to run some actual programs.

### requirements
You'll need a few bits of software to compile the compiler:

* `dmd`, `ldc2`, - some D compiler
* `llvm`, `llvm-config` - the llvm tool chain
* `clang`, `gcc`, - some C compiler
* `make` - GNU make

### building

#### Mac
The easiest way to get going is use homebrew:

```bash
$ xcode-select --install
$ curl -fsS https://dlang.org/install.sh | bash -s dmd
$ brew install llvm
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
$ sudo apt-get install build-essential llvm-config
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
TODO!

## examples!
For now let's have a nice simple hello world program! Note: this is not how the
final language is intended to look, but rather how you would approach a hello world
program in the compilers current state.

```krug
#module main

#{c_func, variadic}
func printf(str *u8) s32;

#{no_mangle}
func main() {
	printf(c"hello world\n");
}
```

##### What I want it to look like:
Something along these lines:

```krug
#module main

#load "std/io.krug"

func main() {
	std::Println("Hello, {}!", "world!");
}
```

Each file specifies what module it is a part of.
Krug source files are loaded with a relative path.
Modules are access with the :: colon operator.
The identifier for a function is capitalized as the privacy for function identifiers
is specified with the case of the identifier.
The standard library is nice and flexible!

## why?!
Krug is a fun little side project. The goal is to create a somewhat polished compiler that 
can compile any Krug program you throw at it.

### roadmap?
This is a side-project I do in my free time so development is done in short lived bursts when I can.

Here's a roadmap for the language in some sort of order:

* Todo write up a new roadmap!

Disclaimer: some of these are realistic and some are... not.
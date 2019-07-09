# KPD
This is a compiler for [Krug](//krug-lang.org), written in D. Though KPD itself is quite old, so it wont compile most Krug programs anymore.
The actual compiler for Krug can be found under the name [Caasper](//github.com/krug-lang/caasper).

## Try it out
Nothing is in working order, but some tests _might_ run! The compiler still has a long
way to go till it's stable-ish to run some actual programs.

### Requirements
You'll need a few bits of software to compile the compiler:

* `dmd`, `ldc2`, - some D compiler
* `clang`, `gcc`, - some C compiler
* `make` - GNU make

### Setup

#### Mac
```bash
$ xcode-select --install
$ curl -fsS https://dlang.org/install.sh | bash -s dmd
```

#### Ubuntu
```bash
$ sudo apt-get install build-essential
$ curl -fsS https://dlang.org/install.sh | bash -s dmd
```

#### Windows
TODO!

### Installing
$ git clone http://github.com/felixangell/krug
$ cd krug
$ make
$
$ ./krug b tests/x64_tests/fib.krug
$ ./main
$
$ ./krug e E0001        # explain error message E0001


## Examples!
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

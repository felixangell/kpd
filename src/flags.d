module cflags;

import std.stdio;
import std.conv : to;

import gen.target : Target;

enum VERSION = "0.0.1";
enum KRUG_EXT = ".krug";

Target BUILD_TARGET = Target.X64;
uint OPTIMIZATION_LEVEL = 0;
bool RELEASE_MODE = false;
string ARCH = arch_type();
string OPERATING_SYSTEM = os_name();
string OUT_NAME = "main";

enum Output_Type {
	Assembly,
	Object_Files,
	Executable,
}
Output_Type OUT_TYPE = Output_Type.Executable;

// prints krug compiler info (i.e. relevant flags)
// to the stdout only in debug mode.
void write_krug_info() {
	debug {
		writeln("KRUG COMPILER, VERSION ", VERSION);
		writeln("Executing compiler");
		writeln("* Optimization level O", to!string(OPTIMIZATION_LEVEL));
		writeln("* Operating system: ", os_name());
		writeln("* Architecture: ", ARCH);
		writeln("* Target Architecture: ", BUILD_TARGET);
		writeln("* Compiler is in ", (RELEASE_MODE ? "release" : "debug"), " mode");
		writeln();
	}
}

static string os_name() {
	// this should cover most of the important-ish ones
	version (linux) {
		return "Linux";
	}
	else version (Windows) {
		return "Windows";
	}
	else version (OSX) {
		return "Mac OS X";
	}
	else version (POSIX) {
		return "POSIX";
	}
	else {
		return "Undefined";
	}
}

// this is not an exhaustive list
// of architectures!
static string arch_type() {
	version (X86) {
		return "x86";
	}
	else version (X86_64) {
		return "x86_64";
	}
	else {
		return "Undefined";
	}
}

module cflags;

import std.stdio;
import std.conv : to;
import std.array : replicate;

import colour;
import gen.target : Target;

enum VERSION = "0.0.1";
enum KRUG_EXT = ".krug";

Target BUILD_TARGET = Target.LLVM;
uint OPTIMIZATION_LEVEL = 0;
bool RELEASE_MODE = false;
string ARCH = arch_type();
string OPERATING_SYSTEM = os_name();
string OUT_NAME = "main";
bool SHOW_WARNINGS = false;

enum Output_Type {
	Assembly,
	Object_Files,
	Executable,
}
Output_Type OUT_TYPE = Output_Type.Executable;

void write_fancy_string(A, B)(A left_raw, B right_raw) {
	string left = to!string(left_raw);
	string right = to!string(right_raw);

	auto tab = replicate(" ", 4);

	auto console_width = 80;
	auto rem_space = console_width - (tab.length * 2); // we have two tabs
	rem_space -= left.length;
	rem_space -= right.length;

	string dots = replicate(".", rem_space - 2);

	writeln(tab, colour.Bold(left), " ", dots, " ", colour.Colourize(colour.GREEN, right));
}

// prints krug compiler info (i.e. relevant flags)
// to the stdout only in debug mode.
void write_krug_info() {
	debug {
		writeln();
		write_fancy_string("KRUG COMPILER", "v" ~ VERSION);
		write_fancy_string("Optimization level", "O" ~ to!string(OPTIMIZATION_LEVEL));
		write_fancy_string("Operating system", os_name());
		write_fancy_string("Architecture", ARCH);
		write_fancy_string("Target Architecture", BUILD_TARGET);
		write_fancy_string("Release Mode", (RELEASE_MODE ? "release" : "debug") ~ " mode");
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

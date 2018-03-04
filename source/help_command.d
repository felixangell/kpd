module kargs.help;

import std.stdio;
import std.conv;

import cflags;
import logger;
import kargs.command;

class Help_Command : Command {
	this() {
		super("help", "show this help message");
	}

	override void process(string[] args) {
		writeln("KRUG COMPILER, VERSION ", VERSION);
		writeln("* Executing compiler, optimization level O", to!string(OPTIMIZATION_LEVEL));
		writeln("* Operating system: ", OPERATING_SYSTEM);
		writeln("* Target architecture: ", ARCH);
		writeln("* Compiler is in ", (RELEASE_MODE ? "release" : "debug"), " mode");
		writeln();

		writeln("Usage:\n");
		writeln("    krug command [arguments...]\n");

		writeln("List of sub-commands:\n");
		foreach (c; commands) {
			writefln("    %-10s%s", c.name, c.desc);
		}
		writeln;
	}
}

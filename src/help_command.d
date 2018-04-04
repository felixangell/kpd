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
		write_krug_info();

		writeln("Usage:\n");
		writeln("    krug command [arguments...]\n");

		writeln("List of sub-commands:\n");
		foreach (c; commands) {
			writefln("    %-10s%s", c.name, c.desc);
		}
		writeln;
	}
}

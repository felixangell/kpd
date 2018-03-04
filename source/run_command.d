module kargs.run;

import std.conv;
import std.datetime.stopwatch : StopWatch;
import std.stdio;

import logger;
import kargs.command;

// this hooks into the virtual machine which
// is separately implemented in C
extern (C) bool execute_program(size_t entry_addr, size_t instruction_count, ubyte* program);

class Run_Command : Command {
	this() {
		super("run");
	}

	override void process(string[] args) {
		StopWatch rt_timer;
		rt_timer.start();

		// TODO run the program here!

		auto rt_dur = rt_timer.peek();
		logger.Info("Program execution took ",
				to!string(rt_dur.total!"msecs"),
				"/ms or ", to!string(rt_dur.total!"usecs"), "/µs");
	}
}

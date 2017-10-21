import std.stdio;
import std.datetime;
import std.conv;

import program_tree;
import krug_module;
import parse.parser;
import err_logger;

const KRUG_EXT = ".krug";

void main(string[] args) {
	if (args.length == 1) {
        err_logger.Error("no program arguments specified.");
	    return;
	}

    StopWatch compilerTimer;
    compilerTimer.start();
    {
    	auto main_source_file = Source_File(args[1]);
    	build_program_tree(main_source_file);
    }
	long duration = compilerTimer.peek().usecs;
	err_logger.Verbose("Compiler took " ~ to!string(duration) ~ "/µs.");
}
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
    	Krug_Project proj = build_krug_project(main_source_file);
    	proj.graph.dump();
    }
	auto duration = compilerTimer.peek();
	err_logger.Verbose("Compiler took "
	    ~ to!string(duration.msecs)
	    ~ "/ms or "
	    ~ to!string(duration.usecs)
	    ~ "/µs");
}
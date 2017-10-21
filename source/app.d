import std.stdio;
import std.datetime;
import std.conv;
import std.array;
import std.algorithm.sorting;
import std.parallelism;

import ds;
import program_tree;
import krug_module;
import parse.parser;
import ast;
import err_logger;

const KRUG_EXT = ".krug";

void main(string[] args) {
    StopWatch compilerTimer;
    compilerTimer.start();

	if (args.length == 1) {
        err_logger.Error("no program arguments specified.");
	    return;
	}

    auto main_source_file = new Source_File(args[1]);
    Krug_Project proj = build_krug_project(main_source_file);
    assert("main" in proj.graph);
    proj.graph.dump();

    // TODO: we can move flatten -> sort into
    // one thing instead of a two step solution!

    // flatten the dependency graph into an array
    // of modules.
    Dependency_Graph graph = proj.graph;
    Module[] flattened;
    foreach (ref mod; graph) {
        flattened ~= mod;
    }

    // sort the flattened modules such that the
    // modules with the least amount of dependencies
    // are first
    auto sorted_deps = flattened.sort!((a, b) => a.dep_count() < b.dep_count());
    foreach (dep; sorted_deps) {
        Token_Stream[string] tok_streams = dep.token_streams;
        foreach (tok_stream; tok_streams) {
            dep.as_trees[dep.name] = new Parser(tok_stream).parse();
        }
    }

	auto duration = compilerTimer.peek();
	err_logger.Verbose("Compiler took "
	    ~ to!string(duration.msecs)
	    ~ "/ms or "
	    ~ to!string(duration.usecs)
	    ~ "/µs");
}
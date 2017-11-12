import std.stdio;
import std.datetime;
import std.conv;
import std.array;
import std.algorithm.sorting;
import std.parallelism;
import std.getopt;
import std.datetime.stopwatch : StopWatch;

import colour;
import ds.hash_set;
import dependency_scanner;
import krug_module;

import parse.parser;
import ast;
import err_logger;

import sema.analyzer;

uint OPTIMIZATION_LEVEL = 1;
const VERSION = "0.0.1";
const KRUG_EXT = ".krug";
bool RELEASE_MODE = false;
string ARCH = "x86_64";
string OUT_NAME = "main";

// FIXME this only handles a few common cases.
static string os_name() {
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

// FIXME this only handles a few common cases.
static string arch_type() {
	version (X86) {
		return "x86";
	}
	version (X86_64) {
		return "x86_64";
	}
}

void main(string[] args) {
    StopWatch compilerTimer;
    compilerTimer.start();

    // argument stuff.
    // todo we should parse this ourselves.
    // FIXME document these properly.
    getopt(args,
        "no-colours", "disables colourful output logging", &colour.NO_COLOURS,
        "verbose|v", "enable verbose logging", &err_logger.VERBOSE_LOGGING,
        "opt|O", "optimization level", &OPTIMIZATION_LEVEL,
        "release|r", "compile in release mode", &RELEASE_MODE,
        "out", "output name", &OUT_NAME,
        "arch", "force architecture, e.g. x86 or x86_64", &ARCH,
    );

    // argument validation
    {
    	// TODO: sanitize all of them, though we dont need
    	// to do this just now because we may end up parsing
    	// the flags ourselves.
        if (OPTIMIZATION_LEVEL < 1 || OPTIMIZATION_LEVEL > 3) {
            err_logger.Error("optimization level must be between 1 and 3.");
        }
    }

    if (err_logger.VERBOSE_LOGGING) {
        err_logger.Verbose();
        err_logger.Verbose("KRUG COMPILER, VERSION " ~ VERSION);
        err_logger.Verbose("Executing compiler, optimization level O" ~ to!string(OPTIMIZATION_LEVEL));
        err_logger.Verbose("Operating system: " ~ os_name());
        err_logger.Verbose("Target architecture: " ~ arch_type());
        err_logger.Verbose("Compiler is in " ~ (RELEASE_MODE ? "release" : "debug") ~ " mode");
        err_logger.Verbose();
        writeln();
    }

	if (args.length == 1) {
        err_logger.Error("no input file.");
	    return;
	}

    auto main_source_file = new Source_File(args[1]);
    Krug_Project proj = build_krug_project(main_source_file);
    assert("main" in proj.graph);

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
    err_logger.Verbose("Parsing: ");
    foreach (ref dep; sorted_deps) {
        foreach (ref entry; dep.token_streams.byKeyValue) {
            err_logger.Verbose("- " ~ dep.name ~ "::" ~ entry.key);

            // there is no point starting a parser instance
            // if we have no tokens to parse!

            auto token_stream = entry.value;
            if (token_stream.length == 0) {
                dep.as_trees[entry.key] = [];
                continue;
            }

            dep.as_trees[entry.key] = new Parser(token_stream).parse();
        }
    }

    err_logger.Verbose("Performing semantic analysis on: ");
    foreach (ref dep; sorted_deps) {
        auto sema = new Semantic_Analysis(graph);
        foreach (ref entry; dep.as_trees.byKeyValue) {
            sema.process(dep, entry.key);
        }
    }

	auto duration = compilerTimer.peek();
	err_logger.Info("Compiler took "
	    ~ to!string(duration.total!"msecs")
	    ~ "/ms or "
	    ~ to!string(duration.total!"usecs")
	    ~ "/µs");
}
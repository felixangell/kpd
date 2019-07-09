module kargs.run;

import std.datetime.stopwatch : StopWatch;
import std.stdio;
import std.datetime;
import std.format;
import std.conv;
import std.array;
import std.algorithm.sorting;
import std.parallelism;
import std.getopt;
import std.string;

import compiler_error : DEPENDENCY_CYCLE;

import kargs.command;
import cflags;
import colour;
import tarjans_scc;
import dep_graph;
import krug_module;
import diag.engine;
import logger;
import kargs.command;

import kir.cfg;
import kir.cfg_builder;

import parse.parser;
import ast;
import logger;

import kir.ir_mod;
import kir.ir_verify;
import kir.builder;

import sema.analyzer;

import opt.opt_manager;

import gen.code_gen;
import gen.target;

// TODO: clean this up because
// this is pretty much a copy paste
// of the build command but with
// a different function call haha
class Run_Command : Command {
	this() {
		super("run", "compiles and runs the given krug program");
	}

	override void process(string[] args) {
		StopWatch rt_timer;
		rt_timer.start();

		if (args.length == 0) {
			logger.error("No input files.");
			return;
		}

		getopt(args, 
			"verbose|v", &VERBOSE_LOGGING,
			"arch", &ARCH,
			"release|r", &RELEASE_MODE,
			"opt|O", &OPTIMIZATION_LEVEL,
			"out|o", &OUT_NAME,
		);

		write_krug_info();

		writeln("- unimplemented");

		auto rt_dur = rt_timer.peek();
		logger.info("Program execution took ",
				to!string(rt_dur.total!"msecs"),
				"/ms or ", to!string(rt_dur.total!"usecs"), "/µs");
	}
}

module kargs.build;

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
import dependency_scanner;
import krug_module;
import diag.engine;
import logger;
import kargs.command;

import parse.parser;
import ast;
import logger;

import kir.ir_mod;
import kir.ir_verify;
import kir.builder;

import exec.instruction;
import exec.exec_engine;

import sema.analyzer;

import opt.opt_manager;

import gen.code_gen;
import gen.target;

class Build_Command : Command {
	Target BUILD_TARGET = Target.X64;

	this() {
		super("build", "compiles the given krug program");
	}

	override void process(string[] args) {
		StopWatch compilerTimer;
		compilerTimer.start();

		if (args.length == 0) {
			logger.Error("No input files.");
			return;
		}

		getopt(args, 
			"verbose|v", &VERBOSE_LOGGING,
			"arch", &ARCH,
			"release|r", &RELEASE_MODE,
			"opt|O", &OPTIMIZATION_LEVEL,
			"out|o", &OUT_NAME,
			"target", &BUILD_TARGET,
		);

		debug {
			writeln("KRUG COMPILER, VERSION ", VERSION);
			writeln("* Executing compiler, optimization level O", to!string(OPTIMIZATION_LEVEL));
			writeln("* Operating system: ", os_name());
			writeln("* Architecture: ", arch_type());
			writeln("* Target Architecture: ", BUILD_TARGET);
			writeln("* Compiler is in ", (RELEASE_MODE ? "release" : "debug"), " mode");
			writeln();
		}

		string entry_file = args[0];
		auto main_source_file = new Source_File(entry_file);
		Krug_Project proj = build_krug_project(main_source_file);

		// run tarjan's strongly connected components
		// algorithm on the graph of the project to ensure
		// there are no cycles in the krug project graph

		logger.VerboseHeader("Cycle detection:");		
		SCC[] cycles = proj.graph.get_scc();
		if (cycles.length > 0) {
			foreach (cycle; cycles) {
				string dep_string;
				foreach (idx, mod; cycle) {
					if (idx > 0) {
						dep_string ~= " ";
					}
					dep_string ~= "'" ~ mod.name ~ "'";
				}

				// TODO a better error message for this.
				Diagnostic_Engine.throw_custom_error(DEPENDENCY_CYCLE,
						"There is a cycle in the project dependencies: " ~
						dep_string);
			}

			// let's not continue with compilation!
			return;
		}

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
		logger.VerboseHeader("Parsing:");
		foreach (ref dep; sorted_deps) {
			foreach (ref entry; dep.token_streams.byKeyValue) {
				logger.Verbose("- " ~ dep.name ~ "::" ~ entry.key);

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

		const auto parse_errors = logger.get_err_count();
		if (parse_errors > 0) {
			logger.Error("Terminating compilation: ", to!string(parse_errors),
					" parse errors encountered.");
			return;
		}

		logger.VerboseHeader("Semantic Analysis: ");
		foreach (ref dep; sorted_deps) {
			auto sema = new Semantic_Analysis(graph);
			foreach (ref entry; dep.as_trees.byKeyValue) {
				sema.process(dep, entry.key);
			}
		}

		const auto sema_errors = logger.get_err_count();
		if (sema_errors > 0) {
			logger.Error("Terminating compilation: ", to!string(sema_errors),
					" semantic errors encountered.");
			return;
		}

		bool GEN_IR = true;
		if (!GEN_IR) return;

		Kir_Module[] krug_program;

		logger.VerboseHeader("Generating Krug IR:");
		foreach (ref dep; sorted_deps) {
			foreach (ref entry; dep.as_trees.byKeyValue) {
				auto sub_mod_name = entry.key;
				auto mod_path = dep.path;
				auto mod_name = dep.name;

				auto kir_builder = new Kir_Builder(mod_name, sub_mod_name);

				logger.Verbose(" - ", mod_name, "::", sub_mod_name);

				auto mod = kir_builder.build(dep, sub_mod_name);
				mod.dump();
				new IR_Verifier(mod);
				krug_program ~= mod;
			}
		}

		logger.VerboseHeader("Optimisation Pass: ");
		optimise(krug_program, OPTIMIZATION_LEVEL);

		if ("no code generation please") {
			logger.VerboseHeader("Code Generation: ");
			generate_code(BUILD_TARGET, krug_program);
		}

		auto duration = compilerTimer.peek();
		logger.Info("Compiler took ", to!string(duration.total!"msecs"),
				"/ms or ", to!string(duration.total!"usecs"), "/µs");
	}
}

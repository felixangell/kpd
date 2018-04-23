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
import dep_graph;
import krug_project;
import krug_module;
import diag.engine;
import logger;
import kargs.command;

import parse.parser;
import ast;
import logger;

import kir.cfg;
import kir.cfg_builder;
import kir.ir_mod;
import kir.ir_verify;
import kir.builder;

import sema.analyzer;

import opt.opt_manager;

import gen.code_gen;
import gen.target;

class Build_Command : Command {
	this() {
		super("build", "compiles the given krug program");
	}

	override void process(string[] args) {
		StopWatch compilerTimer;
		compilerTimer.start();

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
			"target", &BUILD_TARGET,
			"out_type", &OUT_TYPE,

			"sw", &SHOW_WARNINGS,
			
			"c", function(string option) {
				OUT_TYPE = Output_Type.Object_Files;	
			},
			"S", function(string option) {
				OUT_TYPE = Output_Type.Assembly;
			},
		);

		write_krug_info();

		string entry_file = args[0];
		auto main_source_file = new Source_File(entry_file);
		Krug_Project proj = build_krug_project(main_source_file);

		// run tarjan's strongly connected components
		// algorithm on the graph of the project to ensure
		// there are no cycles in the krug project graph

		logger.verbose_header("Cycle detection:");		
		SCC[] cycles = proj.graph.get_scc();
		if (cycles.length > 0) {
			foreach (ref cycle; cycles) {
				string dep_string;
				foreach (ref idx, mod; cycle) {
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
		auto sorted_modules = flattened.sort!((a, b) => a.dep_count() < b.dep_count());

		logger.verbose_header("Parsing:");
		foreach (ref mod; sorted_modules) {
			foreach (ref sub_mod_name, token_stream; mod.token_streams) {
				logger.verbose("- " ~ mod.name ~ "::" ~ sub_mod_name);
				// there is no point starting a parser instance
				// if we have no tokens to parse
				if (token_stream.length == 0) {
					mod.as_trees[sub_mod_name] = [];
					continue;
				}
				mod.as_trees[sub_mod_name] = new Parser(token_stream).parse();
			}
		}

		const auto parse_errors = logger.get_err_count();
		if (parse_errors > 0) {
			logger.error("Terminating compilation: ", to!string(parse_errors),
					" parse errors encountered.");
			return;
		}

		logger.verbose_header("Semantic Analysis: ");
		foreach (ref mod; sorted_modules) {
			auto sema = new Semantic_Analysis(graph);
			sema.process(mod);
		}

		const auto sema_errors = logger.get_err_count();
		if (sema_errors > 0) {
			logger.error("Terminating compilation: ", to!string(sema_errors),
					" semantic errors encountered.");
			return;
		}

		// tree of modules -> ir_modules
		IR_Module[string] modules;

		IR_Module[] krug_program;

		logger.verbose_header("Generating Krug IR:");
		foreach (ref mod; sorted_modules) {
			writeln("ir_builder: ", mod.name);
			mod.ir_mod = new IR_Module(mod.name);

			foreach (ref sub_mod_name, as_tree; mod.as_trees) {
				auto ir_builder = new IR_Builder(mod, sub_mod_name);
				ir_builder.setup_sym_table(mod, sub_mod_name, as_tree);

				// register the depednencies for this module
				foreach (ref key, mod; mod.edges) {
					ir_builder.ir_mod.add_dependency(modules[key]);
				}

				logger.verbose(" - ", mod.name, "::", sub_mod_name);

				auto ir_mod = ir_builder.build(mod, as_tree);
				if (VERBOSE_LOGGING) ir_mod.dump();
				new IR_Verifier(ir_mod);

			}
			modules[mod.name] = mod.ir_mod;
			krug_program ~= mod.ir_mod;
		}

		logger.verbose_header("Control flow analysis of Krug IR:");
		foreach (ref ir_mod; krug_program) {
			build_graphs(ir_mod);
		}

		logger.verbose_header("Optimisation Pass: ");
		optimise(krug_program, OPTIMIZATION_LEVEL);

		logger.verbose_header("Code Generation: ");
		generate_code(BUILD_TARGET, krug_program);

		auto duration = compilerTimer.peek();
		logger.info("Compiler took ", to!string(duration.total!"msecs"),
				"/ms or ", to!string(duration.total!"usecs"), "/µs");
	}
}
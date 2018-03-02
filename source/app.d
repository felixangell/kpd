import std.stdio;
import std.datetime;
import std.format;
import std.conv;
import std.array;
import std.algorithm.sorting;
import std.parallelism;
import std.getopt;
import std.datetime.stopwatch : StopWatch;
import std.string;

import cflags;
import colour;
import tarjans_scc;
import dependency_scanner;
import krug_module;
import diag.engine;
import compiler_error;

import parse.parser;
import ast;
import logger;
import kir.builder;

import exec.instruction;
import exec.exec_engine;
import sema.analyzer;

static string os_name() {
  // this should cover most of the important-ish ones
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

extern (C) bool execute_program(size_t entry_addr, size_t instruction_count, ubyte* program);

// FIXME this only handles a few common cases.
static string arch_type() {
  version (X86) {
    return "x86";
  }
  version (X86_64) {
    return "x86_64";
  }
}

void explain_err(string err_code) {
  // validate the error code first:
  if (err_code.length != 5) {
    logger.Error("Invalid error code '" ~ err_code ~ "' - error code format is EXXXX");
    return;
  }

  auto num = to!ushort(err_code[1 .. $]);
  if (num < 0) {
    logger.Error("Invalid error code sign '" ~ err_code ~ "'");
    return;
  }

  if (num in compiler_error.ERROR_REGISTER) {
    auto error = compiler_error.ERROR_REGISTER[num];
    writeln(error.detail);
  } 
  else {
    logger.Error("No such error defined for '" ~ err_code ~ "'");
  }
}

bool DONT_COMPILE = false;

void main(string[] args) {
  StopWatch compilerTimer;
  compilerTimer.start();

  // argument stuff.
  // todo we should parse this ourselves.
  // FIXME document these properly.
  getopt(args, "no-colours", "disables colourful output logging", &colour.NO_COLOURS, "verbose|v", "enable verbose logging", &logger.VERBOSE_LOGGING, "opt|O",
      "optimization level", &OPTIMIZATION_LEVEL, "release|re", "compile in release mode", &RELEASE_MODE, "out", "output name", &OUT_NAME, "arch",
      "force architecture, e.g. x86 or x86_64", &ARCH, "run|r", "run program after compilation", &RUN_PROGRAM, "explain|e", "explains the given error code, e.g. -e E0001", &ERROR_CODE, "sw", "suppresses compiler warnings",
      &SUPPRESS_COMPILER_WARNINGS, "dump_bc|b", "dumps the bytecode to stdout",
      &DUMP_BYTECODE, "dont_compile|c", "don't compile any bytecode", &DONT_COMPILE);

  // argument validation
  {
    // TODO: sanitize all of them, though we dont need
    // to do this just now because we may end up parsing
    // the flags ourselves.
    if (OPTIMIZATION_LEVEL < 0 || OPTIMIZATION_LEVEL > 3) {
      logger.Error("optimization level must be between 0 and 3.");
    }
  }

  if (ERROR_CODE !is null) {
    explain_err(ERROR_CODE);
    return;
  }

  if (logger.VERBOSE_LOGGING) {
    logger.Verbose();
    logger.Verbose("KRUG COMPILER, VERSION " ~ VERSION);
    logger.Verbose("Executing compiler, optimization level O" ~ to!string(OPTIMIZATION_LEVEL));
    logger.Verbose("Operating system: " ~ os_name());
    logger.Verbose("Target architecture: " ~ arch_type());
    logger.Verbose("Compiler is in " ~ (RELEASE_MODE ? "release" : "debug") ~ " mode");
    logger.Verbose();
    writeln();
  }

  if (args.length == 1) {
    logger.Error("no input file.");
    return;
  }

  auto main_source_file = new Source_File(args[1]);
  Krug_Project proj = build_krug_project(main_source_file);

  // run tarjan's strongly connected components
  // algorithm on the graph of the project to ensure
  // there are no cycles in the krug project graph

  // TODO: this should be elsewhere... ?
  assert("main" in proj.graph);

  logger.VerboseHeader("Cycle detection: ");
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
      Diagnostic_Engine.throw_custom_error(DEPENDENCY_CYCLE,
          "There is a cycle in the project dependencies: " ~ dep_string);
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
  logger.VerboseHeader("Parsing: ");
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

  logger.VerboseHeader("Semantic Analysis: ");
  foreach (ref dep; sorted_deps) {
    auto sema = new Semantic_Analysis(graph);
    foreach (ref entry; dep.as_trees.byKeyValue) {
      sema.process(dep, entry.key);
    }
  }

  const auto err_count = logger.get_err_count();
  if (err_count > 0) {
    logger.Error("Terminating compilation: " ~ to!string(err_count) ~ " errors encountered.");
    return;
  }

  logger.VerboseHeader("Control Flow Analysis:");
  foreach (ref dep; sorted_deps) {
    auto kir_builder = new Kir_Builder;
    foreach (ref entry; dep.as_trees.byKeyValue) {
      kir_builder.build(dep, entry.key);
    }
  }

  auto duration = compilerTimer.peek();
  logger.Info("Compiler took " ~ to!string(
      duration.total!"msecs") ~ "/ms or " ~ to!string(duration.total!"usecs") ~ "/µs");

  if (!RUN_PROGRAM) {
    return;
  }

  StopWatch rt_timer;
  rt_timer.start();

  // TODO run the program here!

  auto rt_dur = rt_timer.peek();
  logger.Info("Program execution took " ~ to!string(
      rt_dur.total!"msecs") ~ "/ms or " ~ to!string(rt_dur.total!"usecs") ~ "/µs");
}
